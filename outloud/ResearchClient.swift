import Foundation

struct ResearchBrief: Encodable {
    let name: String
    let platform: String
    let status: String
    let url: String
    let description: String
    let category: String
    let audience: String
    let problem: String
    let features: [String]
    let competitors: [String]
    let keywords: [String]

    struct FollowedSource: Encodable {
        let name: String
        let platform: String
        let kind: String
        let url: String
    }
    let followed_sources: [FollowedSource]

    init(project: Project, targets: [WatchTarget] = []) {
        followed_sources = targets.filter { $0.projectID == project.id }.map {
            FollowedSource(name: $0.name, platform: $0.platform.rawValue,
                kind: $0.profileURL == nil ? "topic" : "account", url: $0.profileURL ?? "")
        }
        name = project.name
        let supportedPlatforms = ["iOS", "Android", "Web", "Mac", "Windows", "Linux", "HarmonyOS", "Other"]
        let selectedPlatform = project.productPlatform == "macOS" ? "Mac" : project.productPlatform ?? "Mac"
        platform = supportedPlatforms.contains(selectedPlatform) ? selectedPlatform : "Other"
        status = project.launchStatus ?? "unlaunched"
        url = project.website
        description = project.description
        category = project.researchCategory ?? "other"
        audience = project.audience
        problem = String(project.description.prefix(400))
        features = []
        keywords = project.researchKeywords ?? []
        competitors = project.competitors ?? []
    }
}

struct ResearchWorkspaceReply: Decodable {
    let id: String
    let results: Results
    func references(projectID: UUID) -> [ReferenceItem] {
        let content = results.discover.compactMap { $0.reference(projectID: projectID, conversation: false) }
        let discussions = results.conversations.filter { !$0.competitor }.compactMap { $0.reference(projectID: projectID, conversation: true) }
        var seen = Set<String>()
        return (content + discussions).filter { seen.insert($0.id).inserted }
    }

    struct Results: Decodable {
        let discover: [ResearchSource]
        let conversations: [ResearchSource]
        let notice: String?
    }
}

struct ResearchSource: Decodable {
    let id: String
    let platform: String
    let kind: String
    let title: String
    let author: String
    let url: String
    let summary: String
    let competitor: Bool
    let locked: Bool?
    let section: String?
    let match_reason: String?
    let published_at: String?
    let matched_terms: [String]?
    let media: Media?
    let analysis: Analysis?
    let metrics: Metrics?
    let conversation_signal: ConversationSignal?
    struct ConversationSignal: Decodable { let type: String; let quote: String }
    struct Metrics: Decodable {
        let views: Int?; let plays: Int?; let likes: Int?; let comments: Int?
        let provider: String?; let checked_at: String?
    }
    struct Media: Decodable { let type: String; let url: String?; let poster: String? }
    struct Analysis: Decodable { let problem_quote: String?; let product_problem: String?; let transcript: String? }

    func reference(projectID: UUID, conversation: Bool? = nil) -> ReferenceItem? {
        guard locked != true, let network = Platform(rawValue: platform), Self.publicURL(url) != nil else { return nil }
        let isConversation = conversation ?? (section == "conversations")
        let quote = conversation_signal?.quote.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle: String
        if isConversation && title.count < 35, let quote, !quote.isEmpty {
            displayTitle = quote
        } else if network == .reddit && ["community", "reddit"].contains(title.lowercased()),
                  let opening = summary.split(whereSeparator: \.isNewline).first {
            let words = opening.split(whereSeparator: \.isWhitespace)
            displayTitle = words.prefix(18).joined(separator: " ") + (words.count > 18 ? "…" : "")
        } else {
            displayTitle = title
        }
        var item = ReferenceItem(id: "\(projectID.uuidString):\(id)", projectID: projectID, platform: network,
            author: author, title: displayTitle, excerpt: summary,
            category: (conversation ?? (section == "conversations")) ? "Conversation" : kind, isCompetitor: competitor,
            artwork: 6, sourceURL: url, isExample: false,
            hook: quote.flatMap { $0.isEmpty ? nil : $0 } ?? analysis?.problem_quote ?? "No verified opening has been retrieved.",
            approach: match_reason ?? "Open the original to inspect the source context.",
            adaptation: "Add your own perspective in Studio. This reference is research, not a generated draft.")
        item.retrievedFromResearch = true
        item.conversationSignalType = conversation_signal?.type
        item.matchedTopics = matched_terms
        item.thumbnailURL = Self.publicURL(media?.poster ?? (media?.type == "image" ? media?.url : nil))?.absoluteString
        item.videoURL = media?.type == "video" ? Self.publicURL(media?.url)?.absoluteString : nil
        item.transcript = analysis?.transcript
        if let metrics, !(metrics.provider ?? "").isEmpty, !(metrics.checked_at ?? "").isEmpty {
            item.measuredViews = (metrics.views ?? metrics.plays).flatMap { $0 >= 0 ? $0 : nil }
            item.measuredLikes = metrics.likes.flatMap { $0 >= 0 ? $0 : nil }
            item.measuredComments = metrics.comments.flatMap { $0 >= 0 ? $0 : nil }
        }
        if let published_at {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
            if let date = formatter.date(from: published_at) ?? ISO8601DateFormatter().date(from: published_at) { item.createdAt = date }
        }
        return item
    }

    static func publicURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return nil }
        return url
    }
}

enum ResearchError: LocalizedError {
    case configuration, activation, response, rejected(String), invalidBrief(String)
    var errorDescription: String? {
        switch self {
        case .configuration: "Research isn’t connected in this build yet. Your project is saved."
        case .activation: "Activate your license to use research."
        case .response: "Research couldn’t be loaded. Your existing references are safe. Please try again."
        case .rejected(let message): message
        case .invalidBrief(let message): message
        }
    }
}

// Prevent an unexpected redirect from forwarding a device-session credential.
private final class ResearchSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor
struct ResearchClient {
    private static let session = URLSession(configuration: .ephemeral, delegate: ResearchSessionDelegate(), delegateQueue: nil)
    private let endpoint: URL

    init() throws {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["OUTLOUD_RESEARCH_API_URL"],
           let url = URL(string: raw), url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") {
            endpoint = url; return
        }
        #endif
        #if DEBUG
        if let raw = Bundle.main.object(forInfoDictionaryKey: "OutloudResearchServerURL") as? String,
           let url = URL(string: raw), url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") { endpoint = url; return }
        #endif
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "OutloudResearchServerURL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { throw ResearchError.configuration }
        endpoint = url
    }

    private func request<T: Decodable>(_ path: String, body: Data? = nil) async throws -> T {
        var request = URLRequest(url: endpoint.appending(path: path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.timeoutInterval = 150
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        #if DEBUG
        if endpoint.scheme == "http", ["127.0.0.1", "localhost"].contains(endpoint.host ?? ""),
           ProcessInfo.processInfo.environment["OUTLOUD_TEST_LICENSING"] != "1" {
            // Accepted only by the explicitly enabled, loopback development service.
            request.setValue("Bearer outloud-local-development", forHTTPHeaderField: "Authorization")
        } else {
            try LicenseController.shared.authorizeResearch(&request)
        }
        #else
        try LicenseController.shared.authorizeResearch(&request)
        #endif
        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ResearchError.response }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 422 { throw ResearchError.invalidBrief(Self.validationMessage(data)) }
            if let error = try? JSONDecoder().decode(ServiceError.self, from: data) {
                throw ResearchError.rejected(String(error.detail.prefix(260)))
            }
            throw ResearchError.response
        }
        guard data.count < 2_000_000 else { throw ResearchError.response }
        return try JSONDecoder().decode(T.self, from: data)
    }

    struct Metadata: Decodable {
        let title: String
        let description: String
        let image: String?
        let profile_image: String?
        let icon: String?
        let details: Details?
        struct Details: Decodable { let description: String?; let subtitle: String?; let categories: [String]?; let headings: [String]? }
        var researchDescription: String {
            let full = details?.description.flatMap { $0.isEmpty ? nil : $0 } ?? description
            return String(([details?.subtitle, full, details?.categories?.joined(separator: ", "), details?.headings?.prefix(6).joined(separator: ". ")].compactMap { $0 }.filter { !$0.isEmpty }).joined(separator: "\n").prefix(1200))
        }
    }
    struct ThumbnailReply: Decodable {
        let thumbnail: String?
        let video: String?
        let unavailable: Bool?
    }
    private struct PreviewRequest: Encodable {
        let url: String
        let include_video: Bool
    }
    func preview(_ url: String, includeVideo: Bool = false) async throws -> ThumbnailReply {
        try await request("desktop/sources/thumbnail",
            body: JSONEncoder().encode(PreviewRequest(url: url, include_video: includeVideo)))
    }
    func metadata(_ url: String) async throws -> Metadata {
        try await request("desktop/metadata", body: JSONEncoder().encode(["url":url]))
    }

    func prepare(_ project: Project, targets: [WatchTarget] = []) async throws -> String {
        try Self.validateBrief(project)
        let reply: Created = try await request("desktop/research", body: JSONEncoder().encode(ResearchBrief(project: project, targets: targets)))
        guard reply.id.range(of: "^[a-zA-Z0-9_-]{8,100}$", options: .regularExpression) != nil else { throw ResearchError.response }
        return reply.id
    }

    func load(_ id: String, onProgress: ((ResearchWorkspaceReply) -> Void)? = nil) async throws -> ResearchWorkspaceReply {
        guard id.range(of: "^[a-zA-Z0-9_-]{8,100}$", options: .regularExpression) != nil else { throw ResearchError.response }
        let path = "desktop/projects/" + id + "/stream"
        var state: ProgressReply = try await request(path, body: Data("{}".utf8))
        let deadline = Date().addingTimeInterval(360)
        var deliveredRevision: Int?
        var deliveredUnversionedSnapshot = false
        while true {
            try Task.checkCancellation()
            if state.status == "complete", let workspace = state.workspace { return workspace }
            if let partial = state.workspace {
                if let revision = state.revision {
                    if revision != deliveredRevision { onProgress?(partial); deliveredRevision = revision }
                } else if !deliveredUnversionedSnapshot {
                    onProgress?(partial); deliveredUnversionedSnapshot = true
                }
            }
            if state.status == "failed" { throw ResearchError.rejected(state.error ?? "Research could not finish. Your existing results are safe.") }
            guard Date() < deadline else { throw ResearchError.rejected("Research is taking longer than usual. Your project and existing results are safe; try again shortly.") }
            try await Task.sleep(for: .milliseconds(1200))
            state = try await request(path)
        }
    }
    private struct ProgressReply: Decodable {
        let status: String
        let revision: Int?
        let workspace: ResearchWorkspaceReply?
        let error: String?
    }
    private struct Created: Decodable { let id: String }
    private struct ServiceError: Decodable { let detail: String }

    static func validateBrief(_ project: Project) throws {
        let name = project.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = project.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...70).contains(name.count) else {
            throw ResearchError.invalidBrief("Update your app name in Product details. Use 2–70 characters.")
        }
        guard (30...1200).contains(description.count) else {
            throw ResearchError.invalidBrief("Research needs a little more detail about what your app does. Add a description of 30–1200 characters in Product details.")
        }
        guard ResearchKeywords.valid((project.researchKeywords ?? []).joined(separator: ",")) else {
            throw ResearchError.invalidBrief("Add research keywords in Product details. Use comma-separated keywords, up to 100 characters.")
        }
    }

    static func validationMessage(_ data: Data) -> String {
        if let reply = try? JSONDecoder().decode(ServiceError.self, from: data) { return reply.detail }
        let fields: [String: String] = ["name": "app name", "description": "product description", "audience": "audience", "url": "website link", "platform": "platform", "status": "launch status", "features": "research topics", "competitors": "competitors", "category": "category"]
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let issues = object["detail"] as? [[String: Any]],
           let location = issues.first?["loc"] as? [Any],
           let key = location.dropFirst().first as? String, let field = fields[key] {
            return "Check the \(field) in Product details before starting research."
        }
        return "Check your Product details before starting research. Some information couldn’t be accepted."
    }
}
