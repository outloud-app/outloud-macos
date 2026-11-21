import Foundation
import SwiftUI

enum GlobalArea {
    case home, projects, workspace
}

enum WorkspacePage: String, CaseIterable, Identifiable {
    case discover = "Discover", conversations = "Conversations", saved = "Saved", studio = "Studio", following = "Following"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .discover: "safari"
        case .conversations: "bubble.left.and.bubble.right"
        case .saved: "bookmark"
        case .studio: "paintbrush.pointed"
        case .following: "dot.radiowaves.left.and.right"
        }
    }
}

enum Platform: String, Codable, CaseIterable, Identifiable {
    case instagram = "Instagram", tiktok = "TikTok", reddit = "Reddit", x = "X", web = "Web"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .instagram: "camera"
        case .tiktok: "music.note"
        case .reddit: "bubble.left"
        case .x: "textformat"
        case .web: "globe"
        }
    }
}

enum DraftFormat: String, Codable, CaseIterable, Identifiable {
    case xPost = "X post", reddit = "Reddit post", image = "Image post", video = "Video brief"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .xPost: "text.alignleft"
        case .reddit: "bubble.left"
        case .image: "photo"
        case .video: "play.rectangle"
        }
    }
}

enum BrandColor: String, Codable, CaseIterable, Identifiable {
    case mint = "Mint", lilac = "Lilac", peach = "Peach", blue = "Sky"
    var id: String { rawValue }
    var hex: UInt32 {
        switch self {
        case .mint: 0xA7F3CE
        case .lilac: 0xC8B9F3
        case .peach: 0xF2BDA5
        case .blue: 0xA8D6F1
        }
    }
    var color: Color { Color(hex: hex) }
}

struct Project: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var description: String
    var audience: String
    var website: String
    var brandColor: BrandColor = .mint
    var isExample = false
    var productPlatform: String?
    var launchStatus: String?
    var researchCategory: String?
    var remoteResearchID: String?
    var researchKeywords: [String]?
    var competitors: [String]?
    var iconURL: String?
    var iconData: Data?
    var iconCustomized: Bool?
}

struct ReferenceItem: Identifiable, Codable, Equatable {
    var id: String
    var projectID: UUID
    var platform: Platform
    var author: String
    var title: String
    var excerpt: String
    var category: String
    var isCompetitor: Bool
    var artwork: Int
    var sourceURL: String?
    var isExample: Bool
    var createdAt = Date()
    var hook: String
    var approach: String
    var adaptation: String
    var conversationSignalType: String?
    var retrievedFromResearch: Bool?
    var thumbnailURL: String?
    var videoURL: String?
    var transcript: String?
    var measuredViews: Int?
    var measuredLikes: Int?
    var measuredComments: Int?
    var conversationStatus: String?
    var matchedTopics: [String]?
}

struct StudioDraft: Identifiable, Codable, Equatable {
    var id = UUID()
    var projectID: UUID
    var referenceID: String?
    var title: String
    var format: DraftFormat
    var body: String
    var updatedAt = Date()
}

struct WatchTarget: Identifiable, Codable {
    var id = UUID()
    var projectID: UUID
    var name: String
    var platform: Platform
    var profileURL: String?
    var avatarData: Data?
    var displayName: String {
        if let url = URL(string: profileURL ?? name), let host = url.host, !host.isEmpty {
            let handle = url.pathComponents.last ?? name
            return handle.hasPrefix("@") ? handle : "@" + handle
        }
        return name
    }
}

enum SocialProfile {
    static func resolve(_ name: String, platform: Platform) -> (url: URL, platform: Platform)? {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var raw = value
        if value.hasPrefix("@"), value.dropFirst().range(of: "^[A-Za-z0-9._-]{1,80}$", options: .regularExpression) != nil {
            let base: String
            switch platform {
            case .x: base = "https://x.com/"
            case .instagram: base = "https://www.instagram.com/"
            case .tiktok: base = "https://www.tiktok.com/@"
            default: return nil
            }
            raw = base + value.dropFirst()
        } else if !raw.contains("://") { raw = "https://" + raw }
        guard let url = URL(string: raw), url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil, let host = url.host?.lowercased().replacingOccurrences(of: "www.", with: "") else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        guard path.count == 1, let handle = path.first, !["home", "explore", "accounts", "login", "p", "reel", "search", "i"].contains(handle.lowercased()) else { return nil }
        let detected: Platform
        switch host {
        case "x.com", "twitter.com": detected = .x
        case "instagram.com": detected = .instagram
        case "tiktok.com" where handle.hasPrefix("@"): detected = .tiktok
        default: return nil
        }
        return (url, detected)
    }
}

struct WorkspaceSnapshot: Codable {
    var version = 1
    var projects: [Project]
    var selectedProjectID: UUID?
    var references: [ReferenceItem]
    var savedIDs: Set<String>
    var drafts: [StudioDraft]
    var watchTargets: [WatchTarget]
}

enum ExampleWorkspace {
    static func make() -> WorkspaceSnapshot {
        let project = Project(name: "Loop", description: "A kinder habit tracker that celebrates consistency without perfect streaks.",
                              audience: "People building sustainable habits without the pressure of being perfect.", website: "", isExample: true)
        let entries: [(Platform, String, String, String, String, Bool, Int)] = [
            (.instagram, "Everyday practice", "Missed a day? You haven't lost your progress.", "Reframe a missed habit as part of the process, rather than a reason to quit.", "Image", false, 0),
            (.tiktok, "A habit builder", "I stopped tracking streaks. Here's what changed.", "A personal story that introduces a different way to measure consistency.", "Video", true, 1),
            (.reddit, "Habit-building community", "Does anyone else give up after breaking a streak?", "A discussion about all-or-nothing thinking and the tools people wish existed.", "Conversation", false, 2),
            (.x, "An independent maker", "Your habit app shouldn't make you feel behind.", "A concise opinion that opens a conversation around product philosophy.", "Text", true, 3),
            (.instagram, "Small steps journal", "Small is a perfectly good place to start.", "A typography-led reminder with one actionable takeaway.", "Image", false, 4),
            (.tiktok, "Building in public", "One tiny change made my mornings easier.", "Start with a specific problem. Demonstrate the change before introducing the tool.", "Video", false, 5)
        ]
        let refs = entries.enumerated().map { index, item in
            ReferenceItem(id: "example-\(index)", projectID: project.id, platform: item.0, author: item.1,
                          title: item.2, excerpt: item.3, category: item.4, isCompetitor: item.5, artwork: item.6,
                          isExample: true,
                          hook: item.2,
                          approach: "Lead with a recognizable experience, then offer a useful alternative. Keep the message focused on one change the audience can make.",
                          adaptation: "Start with a real frustration your audience describes. Explain your product's approach in your own words, and support it with something specific you can demonstrate.")
        }
        return WorkspaceSnapshot(projects: [project], selectedProjectID: project.id, references: refs, savedIDs: [], drafts: [], watchTargets: [])
    }
}

/// User-selected research seeds, distinct from confirmed product capabilities.
enum ResearchKeywords {
    static func parse(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw.replacingOccurrences(of: "，", with: ",").components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
    static func valid(_ raw: String) -> Bool { !parse(raw).isEmpty && raw.count <= 100 && !raw.contains(where: { $0 == "<" || $0 == ">" || $0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }) }
}

/// Competitors have no count limit; normalise lines without silently truncating lists.
enum CompetitorNames {
    static func parse(_ value: String) -> [String] {
        var seen = Set<String>()
        return value.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}

/// Local edits must not be blocked by unchanged details from an older import.
enum ProjectEditRules {
    static func same(_ a: Project, _ b: Project) -> Bool {
        a.name == b.name && a.description == b.description && a.audience == b.audience && a.website == b.website
        && a.brandColor == b.brandColor && a.productPlatform == b.productPlatform && a.launchStatus == b.launchStatus
        && (a.researchKeywords ?? []) == (b.researchKeywords ?? []) && (a.competitors ?? []) == (b.competitors ?? [])
        && a.iconURL == b.iconURL && a.iconData == b.iconData && a.iconCustomized == b.iconCustomized
    }
    static func issue(_ draft: Project, original: Project, keywords: String) -> String? {
        if draft.name != original.name && !(2...70).contains(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).count) { return "App name needs 2–70 characters." }
        if draft.description != original.description && !(30...1200).contains(draft.description.trimmingCharacters(in: .whitespacesAndNewlines).count) { return "Description needs 30–1,200 characters." }
        if draft.audience != original.audience && (draft.audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.audience.count > 240) { return "Add an audience within 240 characters." }
        if draft.website != original.website && draft.website.count > 500 { return "Keep the link within 500 characters." }
        if (draft.researchKeywords ?? []) != (original.researchKeywords ?? []) && !ResearchKeywords.valid(keywords) { return "Add research keywords within 100 characters." }
        if (draft.competitors ?? []) != (original.competitors ?? []) && (draft.competitors ?? []).contains(where: { $0.count > 300 }) { return "Keep each competitor name or link within 300 characters." }
        return nil
    }
}
