import Foundation
import Observation
import Security
import LocalAuthentication
import SwiftUI

private enum LicenseKeychain {
    static var service: String {
        #if DEBUG
        if ProcessInfo.processInfo.environment["OUTLOUD_QA_MODE"] == "1" { return "com.wirebuilds.outloud.license.qa." + LicenseEnvironment.mode }
        #endif
        return "com.wirebuilds.outloud.license." + LicenseEnvironment.mode
    }
    private static func query(account: String = "device-session") -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        return [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account,
         kSecUseDataProtectionKeychain as String: true,
         kSecUseAuthenticationContext as String: context]
    }
    static func clear() { SecItemDelete(query() as CFDictionary) }
    static func read() -> String? {
        var request = query()
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        if SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data { return String(data: data, encoding: .utf8) }
        // Old development builds used the file-based login keychain. Never open
        // its password dialog during startup; migrate only an already-readable item.
        request.removeValue(forKey: kSecUseDataProtectionKeychain as String)
        item = nil
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let token = String(data: data, encoding: .utf8) else { return nil }
        try? save(token)
        return token
    }
    static func save(_ value: String, account: String = "device-session") throws {
        let request = query(account: account)
        let data = Data(value.utf8)
        let status = SecItemUpdate(request as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = request
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw LicenseError.storage }
        } else if status != errSecSuccess { throw LicenseError.storage }
    }
    #if DEBUG
    static func selfTest() throws {
        let account = "storage-self-test"
        defer { SecItemDelete(query(account: account) as CFDictionary) }
        let token = UUID().uuidString
        try save(token, account: account)
        var request = query(account: account)
        request[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, String(data: data, encoding: .utf8) == token else { throw LicenseError.storage }
    }
    #endif
}
private enum LicenseError: LocalizedError {
    case configuration, storage, response
    case rejected(String)
    var errorDescription: String? {
        switch self {
        case .configuration: "License activation will be available when app access is ready."
        case .storage: "Could not save your license session in Keychain. Please try again."
        case .response: "Could not verify your license. Check your connection and try again."
        case .rejected(let message): message
        }
    }
}
private struct LicenseReply: Decodable {
    var status: String
    var unlocked: Bool
    var device_token: String?
    var message: String?
    var environment: String?
    var preorder_verified: Bool?
    var launch_at: String?
    var founding_number: Int?
}

enum LicenseEnvironment {
    static var mode: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "OutloudLicenseEnvironment") as? String { return configured }
        #if DEBUG
        return "test"
        #else
        return "live"
        #endif
    }
}

@MainActor @Observable final class LicenseController {
    static let shared = LicenseController()
    private(set) var unlocked = false
    private(set) var hasReservation = false
    private(set) var hasCompletedInitialCheck = false
    private(set) var launchDate = ISO8601DateFormatter().date(from: "2026-12-20T00:00:00+03:00")!
    private(set) var busy = false
    private(set) var foundingNumber: Int?
    private(set) var message = "Enter the key from your license file."
    private var endpoint: URL? {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["OUTLOUD_LICENSE_API_URL"],
           let url = URL(string: value), ["https", "http"].contains(url.scheme ?? "") { return url }
        if Bundle.main.object(forInfoDictionaryKey: "OutloudLicenseServerURL") == nil {
            return URL(string: "https://outloud-license-sandbox.wirebuilds-outloud.workers.dev")
        }
        #endif
        guard let value = Bundle.main.object(forInfoDictionaryKey: "OutloudLicenseServerURL") as? String,
              let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
    private var deviceID: String {
        var storageKey = "OutloudLicenseDeviceID"
        #if DEBUG
        if ProcessInfo.processInfo.environment["OUTLOUD_QA_MODE"] == "1" { storageKey += ".qa" }
        #endif
        if let value = UserDefaults.standard.string(forKey: storageKey) { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: storageKey)
        return value
    }
    private func send(_ path: String, body: [String: String]) async throws -> LicenseReply {
        guard let endpoint else { throw LicenseError.configuration }
        var request = URLRequest(url: endpoint.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LicenseError.response }
        if http.statusCode != 200 {
            let detail = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if let message = detail?["detail"] as? String { throw LicenseError.rejected(message) }
            throw LicenseError.response
        }
        let reply = try JSONDecoder().decode(LicenseReply.self, from: data)
        guard reply.environment == LicenseEnvironment.mode else { throw LicenseError.response }
        return reply
    }
    func authorizeResearch(_ request: inout URLRequest) throws {
        guard unlocked, let token = LicenseKeychain.read() else { throw ResearchError.activation }
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
    }

    func activate(_ key: String) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let reply = try await send("v1/licenses/activate", body: ["license_key": key.trimmingCharacters(in: .whitespacesAndNewlines), "device_id": deviceID])
            if (reply.preorder_verified == true || reply.unlocked), let token = reply.device_token {
                try LicenseKeychain.save(token)
                hasReservation = true
                unlocked = reply.unlocked
                foundingNumber = reply.founding_number.flatMap { (1...200).contains($0) ? $0 : nil }
                if let date = reply.launch_at.flatMap({ ISO8601DateFormatter().date(from:$0) }) { launchDate = date }
                message = "Your pre-order is saved on this Mac."
            } else {
                hasReservation = false
                unlocked = false
                message = reply.message ?? "This license needs attention. Contact support with your receipt."
            }
        } catch { unlocked = false; message = error.localizedDescription }
    }
    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false; hasCompletedInitialCheck = true }
        guard let token = LicenseKeychain.read() else { return }
        do {
            let reply = try await send("v1/licenses/check", body: ["device_token": token])
            unlocked = reply.unlocked
            hasReservation = reply.preorder_verified == true || reply.unlocked
            foundingNumber = reply.founding_number.flatMap { (1...200).contains($0) ? $0 : nil }
            if let date = reply.launch_at.flatMap({ ISO8601DateFormatter().date(from:$0) }) { launchDate = date }
            message = hasReservation ? "Your pre-order is saved on this Mac." : "Your license needs attention. Enter your key or contact support."
        } catch { unlocked = false; message = error.localizedDescription }
    }
    #if DEBUG
    static func storageSelfTest() throws { try LicenseKeychain.selfTest() }
    #endif
    func forget() {
        LicenseKeychain.clear()
        foundingNumber = nil
        hasReservation = false
        unlocked = false
        message = "Enter the key from your license file."
    }
}
