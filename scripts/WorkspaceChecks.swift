import Foundation
import AppKit

@main
struct WorkspaceChecks {
    @MainActor static func main() throws {
        if let path = ProcessInfo.processInfo.environment["OUTLOUD_CHECK_RESPONSE_JSON"] {
            let reply = try JSONDecoder().decode(ResearchWorkspaceReply.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            print("Real response decoded: \(reply.results.discover.count) media/competitor posts, \(reply.results.conversations.count) conversations")
            return
        }
        precondition(PlatformMediaEmbed.tiktokURL("https://www.tiktok.com/@creator/video/1234567890123456789", controls: true)?.host == "www.tiktok.com")
        precondition(PlatformMediaEmbed.tiktokURL("https://evil.example/@creator/video/1234567890123456789", controls: true) == nil)
        precondition(PlatformMediaEmbed.instagramURL("https://www.instagram.com/reel/source123/")?.absoluteString == "https://www.instagram.com/reel/source123/embed/")
        precondition(PlatformMediaEmbed.instagramURL("https://www.instagram.com/accounts/login/") == nil)
        precondition(PlatformMediaEmbed.instagramURL("https://user:password@www.instagram.com/p/source123/") == nil)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("outloud-checks-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("workspace.json")
        let store = WorkspaceStore(storageURL: file)
        precondition(store.projects.isEmpty && store.references.isEmpty)
        let sample = ExampleWorkspace.make()
        store.projects = sample.projects
        store.selectedProjectID = sample.selectedProjectID
        store.references = sample.references
        let exampleID = store.project!.id
        let reference = store.projectReferences[0]
        store.toggleSaved(reference)
        let draftID = store.createDraft(title: "A real draft", format: .xPost, reference: reference)!
        store.updateDraft(draftID, title: "Edited", body: "Original content")
        store.addTarget(name: "Habit building", platform: .reddit)
        store.addProject(name: "Second project", description: "Another product", audience: "Developers", website: "", color: .peach, iconURL: "https://example.com/product.png")
        precondition(store.projectReferences.isEmpty && store.projectDrafts.isEmpty && store.savedReferences.isEmpty)
        precondition(store.projectTargets.isEmpty)
        store.importReference(title: "Reference", url: "https://example.com", note: "My notes", platform: .web)
        precondition(store.projectReferences.count == 1 && !store.projectReferences[0].isExample)
        let restored = WorkspaceStore(storageURL: file)
        precondition(restored.projects.count == 2 && restored.project?.brandColor == .peach)
        precondition(restored.project?.iconURL == "https://example.com/product.png")
        precondition(restored.projectReferences.count == 1)
        restored.selectProject(exampleID)
        precondition(restored.savedReferences.count == 1)
        precondition(restored.projectDrafts.first?.body == "Original content")
        precondition(restored.projectDrafts.first?.title == "Edited")
        precondition(restored.projectTargets.count == 1)
        let sourceBrief = ResearchBrief(project: restored.project!, targets: restored.watchTargets)
        precondition(sourceBrief.followed_sources.count == 1)
        precondition(sourceBrief.followed_sources[0].kind == "topic")
        let otherBrief = ResearchBrief(project: restored.projects.first { $0.id != exampleID }!, targets: restored.watchTargets)
        precondition(otherBrief.followed_sources.isEmpty)
        restored.addTarget(name: "Habit building", platform: .reddit)
        precondition(restored.projectTargets.count == 1) // no duplicate subscriptions
        let referencesBeforeFollowingCheck = restored.references
        var accountTarget = WatchTarget(projectID: exampleID, name: "@maker", platform: .x)
        accountTarget.profileURL = "https://x.com/maker"
        let accountBrief = ResearchBrief(project: restored.project!, targets: [accountTarget])
        precondition(accountBrief.followed_sources[0].kind == "account")
        var accountPost = restored.projectReferences[0]
        accountPost.platform = .x; accountPost.author = "someoneelse"
        accountPost.sourceURL = "https://x.com/maker/status/1234567890"
        restored.references.append(accountPost)
        precondition(restored.references(for: accountTarget).contains { $0.sourceURL == accountPost.sourceURL })
        accountPost.sourceURL = "https://x.com/notmaker/status/1234567891"
        restored.references = [accountPost]
        precondition(restored.references(for: accountTarget).isEmpty)
        restored.references = referencesBeforeFollowingCheck
        restored.deleteDraft(draftID)
        precondition(WorkspaceStore(storageURL: file).projectDrafts.isEmpty)
        let corrupt = directory.appendingPathComponent("corrupt.json")
        let original = Data("preserve these bytes".utf8)
        try original.write(to: corrupt)
        let recovery = WorkspaceStore(storageURL: corrupt)
        precondition(recovery.persistenceError != nil)
        recovery.addProject(name: "Unsaved", description: "", audience: "", website: "", color: .mint)
        let preserved = try Data(contentsOf: corrupt)
        precondition(preserved == original)
        // Legacy snapshots remain readable after adding remote research fields.
        let legacyData = try JSONEncoder().encode(sample)
        let legacy = try JSONDecoder().decode(WorkspaceSnapshot.self, from: legacyData)
        precondition(legacy.projects.first?.remoteResearchID == nil)
        precondition(legacy.references.first?.thumbnailURL == nil)
        let resultJSON = #"""
        {"id":"workspace123","results":{"discover":[
            {"id":"video1","platform":"TikTok","kind":"Video","title":"Real video","author":"Creator","url":"https://example.com/video","summary":"Source caption","competitor":false,"metrics":{"views":42000,"likes":820,"comments":40,"provider":"apify","checked_at":"2026-11-06T05:00:00Z"},"published_at":"2026-11-06T05:00:00.123Z","media":{"type":"video","url":"https://example.com/video.mp4","poster":"https://example.com/poster.jpg"}},
            {"id":"locked","platform":"X","kind":"Text","title":"Locked","author":"Creator","url":"https://example.com/locked","summary":"Do not expose","competitor":false,"locked":true},
            {"id":"unsafe","platform":"X","kind":"Text","title":"Unsafe","author":"Creator","url":"file:///private/data","summary":"Do not open","competitor":false}
        ],"conversations":[
            {"id":"need1","platform":"Reddit","kind":"Discussion","title":"Need a solution","author":"Person","url":"https://example.com/discussion","summary":"Unresolved problem","competitor":false},
            {"id":"pitch","platform":"Reddit","kind":"Discussion","title":"Buy my tool","author":"Vendor","url":"https://example.com/promotion","summary":"Promotion","competitor":true}
        ]}}
        """#
        let response = try JSONDecoder().decode(ResearchWorkspaceReply.self, from: Data(resultJSON.utf8))
        let projectID = restored.selectedProjectID!
        let mapped = response.references(projectID: projectID)
        precondition(mapped.count == 2)
        precondition(mapped[0].videoURL == "https://example.com/video.mp4")
        precondition(mapped[0].thumbnailURL == "https://example.com/poster.jpg")
        precondition(mapped[0].transcript == nil)
        precondition(mapped[0].measuredViews == 42000 && mapped[0].measuredLikes == 820)
        precondition(mapped[1].measuredViews == nil)
        precondition(mapped[1].category == "Conversation") // No section property in payload.
        precondition(mapped[0].createdAt.timeIntervalSince1970 > 1_790_000_000)
        precondition(ResearchSource.publicURL("https://user:password@example.com") == nil)
        precondition(ResearchSource.publicURL("https://example.com:8080") == nil)
        restored.applyResearch(response, to: projectID)
        restored.setConversationStatus(mapped[1], status: "lead")
        restored.applyResearch(response, to: projectID)
        precondition(restored.references.first(where: { $0.id == mapped[1].id })?.conversationStatus == "lead")
        precondition(WorkspaceStore(storageURL: file).references.first(where: { $0.id == mapped[1].id })?.conversationStatus == "lead")
        restored.setConversationStatus(mapped[1], status: "new")
        let empty = try JSONDecoder().decode(ResearchWorkspaceReply.self, from: Data(#"{"id":"workspace123","results":{"discover":[],"conversations":[]}}"#.utf8))
        let retainedBeforePartial = restored.projectReferences.count
        restored.applyResearch(empty, to: projectID, preservingExisting: true)
        precondition(restored.projectReferences.count == retainedBeforePartial, "Partial refresh must keep visible existing cards")
        restored.applyResearch(empty, to: projectID)
        precondition(restored.references.contains(where: { $0.id == mapped[0].id }), "An empty refresh must preserve unsaved research cards")
        restored.toggleSaved(mapped[0])
        precondition(restored.references.first(where: { $0.id == mapped[1].id })?.conversationStatus == "new")
        // Another project's manual reference survived both refreshes.
        precondition(restored.references.contains(where: { $0.title == "Reference" }))
        restored.updateBrief(id: projectID, name: "Edited product", description: "Product research for a real audience", audience: "Developers", website: "https://example.com", color: .blue, platform: "Web", status: "launched", keywords: ["time spent researching"], competitors: ["Example competitor"])
        let reopened = WorkspaceStore(storageURL: file)
        precondition(reopened.area == .projects)
        precondition(reopened.project?.researchKeywords == ["time spent researching"])
        precondition(reopened.project?.competitors == ["Example competitor"])
        let brief = ResearchBrief(project: reopened.project!)
        precondition(brief.features.isEmpty && brief.keywords == ["time spent researching"] && brief.competitors == ["Example competitor"])
        precondition(!ResearchKeywords.valid(" , ， "))
        precondition(ResearchKeywords.valid(String(repeating: "a", count: 100)))
        precondition(!ResearchKeywords.valid(String(repeating: "a", count: 101)))
        precondition(ResearchKeywords.parse("chart，price,Chart, forex") == ["chart", "price", "forex"])
        precondition(ResearchKeywords.parse("a,b,c,d,e,f,g,h,i,j").count == 10)
        reopened.selectProject(projectID)
        reopened.closeProject()
        precondition(reopened.area == .projects && reopened.researchingProjectID == nil && reopened.selectedReference == nil)
        precondition(reopened.project?.id == projectID)
        var briefProject = reopened.project!
        briefProject.description = "An analysis tool"
        do {
            try ResearchClient.validateBrief(briefProject)
            preconditionFailure("A short briefProject description must be identified before making a request")
        } catch ResearchError.invalidBrief(let message) {
            precondition(message.contains("30–1200") && message.contains("Product details"))
        }
        briefProject.description = String(repeating: "a", count: 30)
        try ResearchClient.validateBrief(briefProject)
        briefProject.description = String(repeating: "a", count: 1200)
        try ResearchClient.validateBrief(briefProject)
        briefProject.description += "a"
        do {
            try ResearchClient.validateBrief(briefProject)
            preconditionFailure("Descriptions above 1,200 characters must be rejected")
        } catch ResearchError.invalidBrief { }
        briefProject.description = String(repeating: "a", count: 30)
        let savedKeywords = briefProject.researchKeywords
        briefProject.researchKeywords = []
        do {
            try ResearchClient.validateBrief(briefProject)
            preconditionFailure("Keywords are mandatory even with a usable product description")
        } catch ResearchError.invalidBrief { }
        briefProject.researchKeywords = savedKeywords
        briefProject.productPlatform = "SteamOS"
        precondition(ResearchBrief(project: briefProject).platform == "Other")
        briefProject.productPlatform = "macOS"
        precondition(ResearchBrief(project: briefProject).platform == "Mac")
        let validationReply = Data(#"{"detail":[{"loc":["body","description"],"msg":"String should have at least 30 characters"}]}"#.utf8)
        precondition(ResearchClient.validationMessage(validationReply).contains("product description"))
        let metadata = try JSONDecoder().decode(ResearchClient.Metadata.self, from: Data(#"{"title":"Product","description":"A detailed product summary describing what it does.","icon":"https://example.com/icon.png","details":{"description":"A full publisher description of useful features.","categories":["Productivity"]}}"#.utf8))
        precondition(metadata.icon == "https://example.com/icon.png")
        precondition(metadata.researchDescription.contains("full publisher description") && metadata.researchDescription.contains("Productivity"))
        let legacyMetadata = try JSONDecoder().decode(ResearchClient.Metadata.self, from: Data(#"{"title":"Legacy","description":"A product without a published icon."}"#.utf8))
        precondition(legacyMetadata.icon == nil)
        precondition(ResearchClient.validationMessage(Data(#"{"detail":"This page could not be read."}"#.utf8)) == "This page could not be read.")
        let imageSource = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aPioAAAAASUVORK5CYII=")!
        let localIcon = try ProjectIconAsset.pngData(imageSource)
        precondition(localIcon.starts(with: [137, 80, 78, 71]))
        let iconStore = WorkspaceStore(storageURL: directory.appendingPathComponent("icons.json"))
        iconStore.addProject(name: "Icon check", description: "Help people organise their notes into useful project folders.", audience: "Everyone", website: "https://example.com", color: .mint, iconURL: "https://example.com/icon.png", iconData: localIcon)
        let iconID = iconStore.project!.id
        iconStore.projects[0].remoteResearchID = "existing-research"
        iconStore.updateBrief(id: iconID, name: "Icon check", description: "Help people organise their notes into useful project folders.", audience: "Everyone", website: "https://example.com", color: .lilac, platform: "Mac", status: "unlaunched", keywords: [], competitors: [], iconURL: nil, iconData: localIcon, replaceIcon: true, iconCustomized: true)
        precondition(iconStore.project?.remoteResearchID == "existing-research", "Icon-only edits must not restart research")
        precondition(WorkspaceStore(storageURL: directory.appendingPathComponent("icons.json")).project?.iconData == localIcon)
        iconStore.updateBrief(id: iconID, name: "Icon check", description: "Help people organise their notes into useful project folders.", audience: "Everyone", website: "https://example.com", color: .lilac, platform: "Mac", status: "unlaunched", keywords: [], competitors: [], replaceIcon: true, iconCustomized: true)
        let iconReload = WorkspaceStore(storageURL: directory.appendingPathComponent("icons.json"))
        precondition(iconReload.project?.iconData == nil && iconReload.project?.iconURL == nil && iconReload.project?.iconCustomized == true)
        precondition(CompetitorNames.parse("Alpha\nBeta\nGamma\nDelta\nEpsilon\nAlpha").count == 5)
        precondition(SocialProfile.resolve("@designer", platform: .instagram)?.url.absoluteString == "https://www.instagram.com/designer")
        precondition(SocialProfile.resolve("https://instagram.com/designer/", platform: .x)?.platform == .instagram)
        precondition(SocialProfile.resolve("design tools", platform: .x) == nil)
        precondition(SocialProfile.resolve("https://127.0.0.1/person", platform: .x) == nil)
        precondition(SocialProfile.resolve("https://x.com/person/status/123", platform: .x) == nil)
        let deletionFile = directory.appendingPathComponent("deletion.json")
        let deletionStore = WorkspaceStore(storageURL: deletionFile)
        deletionStore.projects = sample.projects
        deletionStore.references = sample.references
        deletionStore.selectProject(sample.projects[0].id)
        precondition(deletionStore.area == .home)
        deletionStore.toggleSaved(sample.references[0])
        _ = deletionStore.createDraft(title: "Delete with project", format: .xPost)
        deletionStore.addTarget(name: "Design topic", platform: .web)
        deletionStore.addProject(name: "Keep me", description: "A description for another project", audience: "Everyone", website: "", color: .mint)
        precondition(deletionStore.area == .home)
        let keptID = deletionStore.selectedProjectID!
        precondition(!deletionStore.deleteProject(sample.projects[0].id, confirmedName: "wrong name"))
        precondition(deletionStore.projects.count == 2)
        precondition(deletionStore.deleteProject(sample.projects[0].id, confirmedName: sample.projects[0].name))
        let deletionReload = WorkspaceStore(storageURL: deletionFile)
        precondition(deletionReload.projects.map(\.id) == [keptID])
        precondition(deletionReload.references.isEmpty && deletionReload.savedIDs.isEmpty && deletionReload.drafts.isEmpty && deletionReload.watchTargets.isEmpty)
        let closeRoutes = WorkspaceStore(storageURL: directory.appendingPathComponent("close-routes.json"))
        closeRoutes.closeProject()
        precondition(closeRoutes.area == .projects && !closeRoutes.showProjectForm)
        closeRoutes.beginProjectCreation()
        precondition(closeRoutes.showProjectForm)
        closeRoutes.closeProject()
        precondition(closeRoutes.area == .projects && !closeRoutes.showProjectForm)
        closeRoutes.closeProject()
        precondition(closeRoutes.area == .projects && !closeRoutes.showProjectForm)
        ProjectWindowMorph.isTransitioning = true
        closeRoutes.beginProjectCreation()
        precondition(!closeRoutes.showProjectForm, "Repeated menu commands must not restart an in-flight window transition")
        ProjectWindowMorph.isTransitioning = false
        print("Close-route checks passed: repeated launcher close is a no-op; Close Project dismisses setup.")
        print("Project deletion checks passed: exact name required, related records removed, other project preserved after restart. Home is the default on create/open.")
        var legacyProfile = Project(name: String(repeating: "Spotify", count: 12), description: "Legacy brief", audience: "", website: "", brandColor: .mint)
        let baseline = legacyProfile
        precondition(ProjectEditRules.same(legacyProfile, baseline))
        legacyProfile.brandColor = .blue
        precondition(!ProjectEditRules.same(legacyProfile, baseline))
        precondition(ProjectEditRules.issue(legacyProfile, original: baseline, keywords: "") == nil, "Unchanged legacy fields must not block appearance edits")
        legacyProfile.name = "x"
        precondition(ProjectEditRules.issue(legacyProfile, original: baseline, keywords: "") != nil)
        legacyProfile.name = baseline.name
        legacyProfile.researchKeywords = [String(repeating: "a", count: 101)]
        precondition(ProjectEditRules.issue(legacyProfile, original: baseline, keywords: String(repeating: "a", count: 101)) != nil)
        let squareIcon = try ProjectIconAsset.pngData(imageSource, requireSquare: true)
        precondition(!squareIcon.isEmpty)
        let rectangular = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let rectangularData = rectangular.representation(using: .png, properties: [:])!
        do { _ = try ProjectIconAsset.pngData(rectangularData, requireSquare: true); preconditionFailure("Non-square uploads must be rejected") } catch IconImportError.squareRequired { }
        do { _ = try ProjectIconAsset.pngData(Data(repeating: 0, count: 10_000_001)); preconditionFailure("Oversized images must be rejected") } catch IconImportError.tooLarge { }
        deletionReload.editResearchKeywords()
        precondition(deletionReload.showProjectBrief && deletionReload.aboutSection == "Research")
        print("Edit checks passed: dirty-state comparison, legacy Spotify-style profiles, changed-field validation, focused research navigation and icon size/aspect checks.")
        print("Project icon checks passed: image import, local persistence, removal, custom overrides and no research restart for icon edits.")
        print("Product metadata checks passed: publisher descriptions, optional icons, persisted project icons, actionable link errors.")
        print("Research validation checks passed: legacy short descriptions, minimum valid brief, custom platforms, structured rejection messages.")
        print("Project chooser and brief checks passed: restart chooser, persisted keywords/competitors, request mapping, close without data loss.")
        print("Research mapping checks passed: locked/unsafe sources rejected, lane routing, actual media, saved-reference retention, project isolation.")
        print("Workspace checks passed: project isolation, imports, saves, edits, watchlists, restart persistence, deletion, corrupt-file preservation.")
    }
}
