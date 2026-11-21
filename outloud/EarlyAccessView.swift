import SwiftUI

private enum EarlyPalette {
    static let background = Color(red: 0.045, green: 0.045, blue: 0.045)
    static let surface = Color(red: 0.075, green: 0.075, blue: 0.075)
    static let border = Color(white: 0.20)
    static let mint = Color(red: 0.67, green: 0.94, blue: 0.82)
    static let secondary = Color(white: 0.62)
}

struct EarlyAccessRootView: View {
    @State private var license = LicenseController.shared
    @State private var key = ""
    @State private var keyFocused = false
    @State private var inputError = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bellPulse = false
    private let website = URL(string: "https://tryoutloud.pages.dev/checkout/")!
    var body: some View {
        Group {
            if license.unlocked { ContentView() }
            else { reservationView }
        }
    }
    private var reservationView: some View {
        ZStack {
            EarlyPalette.background.ignoresSafeArea()
            VStack(spacing: 45) {
                HStack(spacing: 10) {
                    OutloudMark(color: EarlyPalette.mint).frame(width: 31, height: 31)
                    Text("outloud").font(AppFont.ui(23, weight: .semibold)).tracking(-0.8)
                    Spacer()

                }
                if !license.hasCompletedInitialCheck { restoring }
                else if license.hasReservation { countdown } else { activation }
                HStack {
                    Link("Support", destination: URL(string: "mailto:support@tryoutloud.xyz")!)
                    Button("Check for Updates…") { AppUpdater.shared.check() }.buttonStyle(.plain).padding(.leading, 16)
                    Spacer()
                    Label("License verified", systemImage: "checkmark.shield").opacity(license.hasReservation ? 1 : 0)
                }.font(AppFont.ui(11)).foregroundStyle(EarlyPalette.secondary)
            }.frame(maxWidth: 590).padding(48)
        }.foregroundStyle(Color.white)
        .frame(minWidth: 700, minHeight: 650)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: license.hasReservation)
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["OUTLOUD_STORAGE_SELFTEST"] == "1" {
                do { try LicenseController.storageSelfTest(); print("PASS: Data Protection Keychain round trip without a password prompt.") }
                catch { print("FAIL: Keychain self-test: \(error.localizedDescription)") }
                NSApp.terminate(nil)
                return
            }
            if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_RESET"] == "1" { license.forget() }
            if let previewKey = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_LICENSE_KEY"] {
                await license.activate(previewKey)
            }
            #endif
            await license.restore()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
                await license.restore()
            }
        }.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await license.restore() }
        }
    }
    private var restoring: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small).tint(EarlyPalette.mint)
            Text("Opening Outloud…").font(AppFont.ui(14)).foregroundStyle(EarlyPalette.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 390)
        .accessibilityIdentifier("outloud-restoring")
    }
    private var activation: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Activate Outloud")
                    .font(AppFont.ui(33, weight: .medium)).tracking(-1.2)
                Text("Enter your license key to save your place on this Mac.")
                    .font(AppFont.ui(14)).foregroundStyle(EarlyPalette.secondary).lineSpacing(5)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("License key").font(AppFont.ui(12, weight: .medium))
                LicenseKeyField(text: $key, focused: $keyFocused, enabled: !license.busy, submit: save)
                    .frame(height: 21)
                    .padding(14).background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(keyFocused ? EarlyPalette.mint : EarlyPalette.border, lineWidth: 1))
                    
            }
            HStack(spacing: 12) {
                Button(action: save) {
                    HStack(spacing: 9) {
                        if license.busy { ProgressView().controlSize(.small).tint(Color.black) }
                        else { Image(systemName: "key.fill") }
                        Text(license.busy ? "Activating…" : "Activate")
                    }
                }.buttonStyle(ActivateButtonStyle())
                    .disabled(license.busy || key.isEmpty)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("outloud-activate")
                Link("Get a license", destination: website)
                    .font(AppFont.ui(13, weight: .medium)).padding(.horizontal, 17).padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(EarlyPalette.border))
            }
            if !inputError.isEmpty {
                Label(inputError, systemImage: "exclamationmark.circle").font(AppFont.ui(12)).foregroundStyle(Color(red: 0.96, green: 0.67, blue: 0.53))
            }
            if license.message != "Enter the key from your license file." {
                Text(license.message).font(AppFont.ui(12)).foregroundStyle(EarlyPalette.secondary).lineSpacing(4)
            }
            Divider().overlay(EarlyPalette.border)
            Text("Add your key to see the launch countdown. The full workspace arrives through an app update. Your first year starts then.")
                .font(AppFont.ui(12)).foregroundStyle(EarlyPalette.secondary).lineSpacing(5)
            Link("Lost your key? Email us with your receipt.", destination: URL(string: "mailto:wirebuilds@icloud.com")!)
                .font(AppFont.ui(11)).foregroundStyle(EarlyPalette.mint)
        }.padding(.vertical, 4)
    }
    private var countdown: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(alignment: .center, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You’re in.").font(AppFont.ui(41, weight: .semibold)).tracking(-1.6)
                    Text("Welcome to the start of Outloud.")
                        .font(AppFont.ui(14)).foregroundStyle(EarlyPalette.secondary)
                }
                Spacer(minLength: 0)
                if let number = license.foundingNumber { FoundingPass(number: number) }
            }
            VStack(alignment: .leading, spacing: 16) {
                Text("TARGET LAUNCH · 20 DECEMBER 2026")
                    .font(AppFont.ui(9, weight: .medium)).tracking(1.4).foregroundStyle(EarlyPalette.secondary)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(license.launchDate.timeIntervalSince(context.date)))
                    if remaining > 0 {
                        HStack(spacing: 12) {
                            unit(remaining / 86400, "DAYS")
                            unit(remaining / 3600 % 24, "HOURS")
                            unit(remaining / 60 % 60, "MINUTES")
                            unit(remaining % 60, "SECONDS")
                        }
                    } else {
                        Text("We’re preparing your full workspace. Check for an update here.")
                            .font(AppFont.ui(17)).foregroundStyle(EarlyPalette.mint).lineSpacing(5)
                    }
                }
            }
            LaunchUpdateNotification()
                .padding(.bottom, 9)
        }.padding(.vertical, 4)
    }
    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 10) {
            Text(String(format: "%02d", value))
                .font(.system(size: 40, weight: .regular, design: .monospaced))
                .contentTransition(.numericText(countsDown: true))
                .frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(EarlyPalette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.045)))
            Text(label).font(AppFont.ui(8, weight: .medium)).tracking(1).foregroundStyle(EarlyPalette.secondary)
        }
    }
    private func save() {
        guard !license.busy, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let formatted = LicenseKeyFormat.formatted(key)
        key = formatted
        guard LicenseKeyFormat.isComplete(formatted) else {
            inputError = "Enter the complete key from your checkout confirmation."
            return
        }
        inputError = ""
        Task { await license.activate(formatted); if license.hasReservation { key = "" } }
    }
}
