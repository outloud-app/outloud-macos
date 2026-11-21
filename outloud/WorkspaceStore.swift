import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class WorkspaceStore {
    var page: WorkspacePage = .discover
    var area: GlobalArea = .workspace
    var showGlobalSearch = false
    var searchText = ""
    var researchTopic = ""
    var discoveryLane = "For You"
    var focusedTargetID: UUID?
    var projects: [Project] = []
    var selectedProjectID: UUID?
    var references: [ReferenceItem] = []
    var savedIDs: Set<String> = []
    var drafts: [StudioDraft] = []
    var watchTargets: [WatchTarget] = []
    var selectedReference: ReferenceItem?
    var editingDraftID: UUID?
    var showProjectForm = false
    var showProjectBrief = false
    var aboutSection = "Overview"
    var keywordFocusID = UUID()
    var showImportForm = false
    var showDraftForm = false
    var showSettings = false
    var showFollowingForm = false
    var persistenceError: String?
    var isResearching: Bool { researchingProjectID != nil && researchingProjectID == selectedProjectID }
    var researchingProjectID: UUID?
    var researchErrors: [UUID: String] = [:]
    var researchNeedsDetails: Set<UUID> = []
    private var researchGeneration = 0
    private var openingResearchTask: Task<Void, Never>?
    private var researchTask: Task<Void, Never>?
    private var fileURL: URL?

    init(inMemory: Bool = false, storageURL: URL? = nil) {
        if let storageURL {
            fileURL = storageURL
        } else if !inMemory {
            do {
                let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                             appropriateFor: nil, create: true)
                    .appendingPathComponent("Outloud", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                fileURL = directory.appendingPathComponent("workspace-v1.json")
            } catch { persistenceError = "Your workspace couldn't be opened: \(error.localizedDescription)" }
        }
        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let snapshot = try JSONDecoder().decode(WorkspaceSnapshot.self, from: Data(contentsOf: fileURL))
                guard snapshot.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
                restore(snapshot)
            } catch {
                // Preserve unreadable workspaces instead of replacing them with fixtures.
                self.fileURL = nil
                persistenceError = "Your saved workspace couldn't be read. It has been preserved. Changes in this session won't be saved."
                area = .projects
            }
        } else if inMemory { restore(ExampleWorkspace.make()) }
        else { area = .projects }
        area = .projects
    }

    var project: Project? { projects.first { $0.id == selectedProjectID } }
    var projectReferences: [ReferenceItem] { references.filter { $0.projectID == selectedProjectID } }
    var projectDrafts: [StudioDraft] {
        drafts.filter { $0.projectID == selectedProjectID }.sorted { $0.updatedAt > $1.updatedAt }
    }
    var savedReferences: [ReferenceItem] { projectReferences.filter { savedIDs.contains($0.id) } }
    var projectTargets: [WatchTarget] { watchTargets.filter { $0.projectID == selectedProjectID } }

    private func restore(_ snapshot: WorkspaceSnapshot) {
        projects = snapshot.projects
        selectedProjectID = projects.contains(where: { $0.id == snapshot.selectedProjectID })
            ? snapshot.selectedProjectID : projects.first?.id
        references = snapshot.references
        savedIDs = snapshot.savedIDs
        drafts = snapshot.drafts
        watchTargets = snapshot.watchTargets
    }

    func persist() {
        guard let fileURL else { return }
        let snapshot = WorkspaceSnapshot(projects: projects, selectedProjectID: selectedProjectID,
                                         references: references, savedIDs: savedIDs, drafts: drafts, watchTargets: watchTargets)
        do {
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch { persistenceError = "Changes couldn't be saved: \(error.localizedDescription)" }
    }

    func selectProject(_ id: UUID) {
        showSettings = false
        area = .home
        showProjectBrief = false
        researchTopic = ""
        discoveryLane = "For You"
        selectedProjectID = id
        selectedReference = nil
        editingDraftID = nil
        searchText = ""
        openingResearchTask?.cancel()
        if !ProjectWindowMorph.isTransitioning {
            persist()
            refreshResearch()
            return
        }
        researchTask?.cancel()
        openingResearchTask = Task { [weak self] in
            while ProjectWindowMorph.isTransitioning && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
            }
            guard !Task.isCancelled, let self, selectedProjectID == id, area == .home else { return }
            persist()
            refreshResearch()
        }
    }

    @discardableResult
    func deleteProject(_ id: UUID, confirmedName: String) -> Bool {
        guard let project = projects.first(where: { $0.id == id }), confirmedName == project.name else { return false }
        if selectedProjectID == id {
            if area != .projects { closeProject() }
            else { researchTask?.cancel(); researchGeneration += 1; researchingProjectID = nil }
            selectedProjectID = nil
        }
        let referenceIDs = Set(references.filter { $0.projectID == id }.map(\.id))
        projects.removeAll { $0.id == id }
        references.removeAll { $0.projectID == id }
        savedIDs.subtract(referenceIDs)
        drafts.removeAll { $0.projectID == id }
        watchTargets.removeAll { $0.projectID == id }
        researchErrors[id] = nil
        researchNeedsDetails.remove(id)
        persist()
        return true
    }

    func editResearchKeywords() {
        aboutSection = "Research"
        keywordFocusID = UUID()
        selectedReference = nil; editingDraftID = nil
        area = .workspace; showProjectBrief = true
    }

    func updateBrief(id: UUID, name: String, description: String, audience: String, website: String, color: BrandColor, platform: String, status: String, keywords: [String], competitors: [String], iconURL: String? = nil, iconData: Data? = nil, replaceIcon: Bool = false, iconCustomized: Bool? = nil) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        let previous = projects[index]
        let researchChanged = previous.name != name || previous.description != description || previous.audience != audience
            || previous.website != website || previous.productPlatform != platform || previous.launchStatus != status
            || (previous.researchKeywords ?? []) != keywords || (previous.competitors ?? []) != competitors
        projects[index].iconCustomized = iconCustomized ?? (previous.website == website ? previous.iconCustomized : false)
        projects[index].name = name
        projects[index].description = description
        projects[index].audience = audience
        let sameWebsite = projects[index].website == website
        projects[index].iconURL = replaceIcon ? iconURL : iconURL ?? (sameWebsite ? projects[index].iconURL : nil)
        projects[index].iconData = replaceIcon ? iconData : iconData ?? (sameWebsite ? projects[index].iconData : nil)
        projects[index].website = website
        projects[index].brandColor = color
        projects[index].productPlatform = platform
        projects[index].launchStatus = status
        projects[index].researchKeywords = keywords
        projects[index].competitors = competitors
        if researchChanged { projects[index].remoteResearchID = nil }
        persist()
        if researchChanged { refreshResearch() }
    }

    func beginProjectCreation() {
        guard !showProjectForm, !ProjectWindowMorph.isTransitioning else { return }
        ProjectWindowMorph.begin(fromStarter: area == .projects)
        showProjectForm = true
    }

    func closeProject() {
        guard !ProjectWindowMorph.isTransitioning, area != .projects || showProjectForm else { return }
        ProjectWindowMorph.prepareReturn()
        showProjectForm = false
        researchTask?.cancel()
        researchGeneration += 1
        researchingProjectID = nil
        selectedReference = nil
        editingDraftID = nil
        searchText = ""
        showProjectBrief = false
        showSettings = false
        area = .projects
    }

    var focusedConversationID: String?

    func navigate(_ page: WorkspacePage) {
        showSettings = false
        area = .workspace
        showProjectBrief = false
        selectedReference = nil
        editingDraftID = nil
        focusedConversationID = nil
        self.page = page
    }

    func addProject(name: String, description: String, audience: String, website: String, color: BrandColor, platform: String = "Mac", status: String = "unlaunched", keywords: [String] = [], competitors: [String] = [], iconURL: String? = nil, iconData: Data? = nil) {
        var project = Project(name: name.trimmingCharacters(in: .whitespacesAndNewlines), description: description,
                              audience: audience, website: website, brandColor: color)
        project.productPlatform = platform
        project.launchStatus = status
        project.researchCategory = "other"
        project.researchKeywords = keywords
        project.competitors = competitors
        project.iconURL = iconURL
        project.iconData = iconData
        projects.append(project)
        page = .discover
        selectProject(project.id)
    }

    func cacheProjectIcons() async {
        for candidate in projects where candidate.iconCustomized != true && candidate.iconData == nil && (candidate.iconURL != nil || !candidate.website.isEmpty) {
            guard !Task.isCancelled else { return }
            var url = candidate.iconURL
            if url == nil, let client = try? ResearchClient(), let metadata = try? await client.metadata(candidate.website) { url = metadata.icon }
            guard let url, let data = try? await ProjectIconAsset.download(url), !Task.isCancelled,
                  let index = projects.firstIndex(where: { $0.id == candidate.id }), projects[index].iconData == nil,
                  projects[index].iconCustomized != true, projects[index].website == candidate.website, projects[index].iconURL == candidate.iconURL else { continue }
            projects[index].iconURL = url
            projects[index].iconData = data
            persist()
        }
    }

    func refreshResearch() {
        guard !ProjectWindowMorph.isTransitioning, var project, !project.isExample else { return }
        researchTask?.cancel()
        researchGeneration += 1
        let generation = researchGeneration
        let projectID = project.id
        researchingProjectID = projectID
        researchErrors[projectID] = nil
        researchNeedsDetails.remove(projectID)
        researchTask = Task {
            defer { if researchGeneration == generation { researchingProjectID = nil } }
            do {
                let client = try ResearchClient()
                // Enrich older linked projects before attempting research. Never replace a custom brief.
                if !project.website.isEmpty && (project.iconURL == nil || project.description.trimmingCharacters(in: .whitespacesAndNewlines).count < 30) {
                    if let metadata = try? await client.metadata(project.website) {
                        guard !Task.isCancelled else { return }
                        if project.iconCustomized != true { project.iconURL = metadata.icon ?? project.iconURL }
                        if project.description.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 {
                            project.description = metadata.researchDescription
                            project.remoteResearchID = nil
                        }
                        if let index = projects.firstIndex(where: { $0.id == projectID }) {
                            if projects[index].iconCustomized != true { projects[index].iconURL = project.iconURL }
                            projects[index].description = project.description
                            projects[index].remoteResearchID = project.remoteResearchID
                            persist()
                        }
                    }
                }
                if let iconURL = project.iconURL, project.iconData == nil,
                   let data = try? await ProjectIconAsset.download(iconURL), !Task.isCancelled,
                   let index = projects.firstIndex(where: { $0.id == projectID }), projects[index].iconURL == iconURL, projects[index].iconCustomized != true, projects[index].iconData == nil {
                    projects[index].iconData = data
                    persist()
                }
                let remoteID: String
                if let existing = project.remoteResearchID { remoteID = existing }
                else {
                    remoteID = try await client.prepare(project, targets: watchTargets.filter { $0.projectID == projectID })
                    guard !Task.isCancelled else { return }
                    if let index = projects.firstIndex(where: { $0.id == projectID }) {
                        projects[index].remoteResearchID = remoteID
                        persist()
                    }
                }
                let workspace = try await client.load(remoteID) { [weak self] partial in
                    guard let self, !Task.isCancelled, self.researchGeneration == generation,
                          self.selectedProjectID == projectID else { return }
                    self.applyResearch(partial, to: projectID, preservingExisting: true)
                }
                guard !Task.isCancelled else { return }
                applyResearch(workspace, to: projectID)
            } catch {
                if !Task.isCancelled {
                    researchErrors[projectID] = error.localizedDescription
                    if case ResearchError.invalidBrief = error { researchNeedsDetails.insert(projectID) }
                }
            }
        }
    }

    func applyResearch(_ workspace: ResearchWorkspaceReply, to projectID: UUID, preservingExisting: Bool = false) {
        guard projects.contains(where: { $0.id == projectID }) else { return }
        let statuses = Dictionary(uniqueKeysWithValues: references.filter { $0.projectID == projectID && $0.conversationStatus != nil }.map { ($0.id, $0.conversationStatus!) })
        let matched = workspace.references(projectID: projectID)
        var updated = references
        // Preserve manual imports, saved references and every draft when research changes.
        if !preservingExisting {
            updated.removeAll { $0.projectID == projectID && $0.retrievedFromResearch == true && !savedIDs.contains($0.id) && $0.conversationStatus == nil }
        }
        var positions = Dictionary(updated.enumerated().map { ($0.element.id, $0.offset) },
                                   uniquingKeysWith: { first, _ in first })
        for var item in matched {
            item.conversationStatus = statuses[item.id]
            if let index = positions[item.id] { updated[index] = item }
            else {
                positions[item.id] = updated.count
                updated.append(item)
            }
        }
        if updated != references {
            references = updated
            persist()
        }
    }

    func setConversationStatus(_ reference: ReferenceItem, status: String) {
        guard let index = references.firstIndex(where: { $0.id == reference.id && $0.projectID == selectedProjectID }) else { return }
        references[index].conversationStatus = status
        persist()
    }

    func toggleSaved(_ reference: ReferenceItem) {
        if savedIDs.contains(reference.id) { savedIDs.remove(reference.id) }
        else { savedIDs.insert(reference.id) }
        persist()
    }

    func importReference(title: String, url: String, note: String, platform: Platform) {
        guard let projectID = selectedProjectID else { return }
        references.insert(ReferenceItem(id: UUID().uuidString, projectID: projectID, platform: platform,
            author: "Imported by you", title: title.trimmingCharacters(in: .whitespacesAndNewlines), excerpt: note,
            category: platform == .reddit ? "Conversation" : "Reference", isCompetitor: false, artwork: 6,
            sourceURL: url.isEmpty ? nil : url, isExample: false,
            hook: "Add your observations about the opening here.",
            approach: "This is a manually imported reference. Automatic analysis isn't connected yet.",
            adaptation: "What is useful about this approach, and how could you express it originally for your audience?"), at: 0)
        persist()
    }

    @discardableResult
    func createDraft(title: String, format: DraftFormat, reference: ReferenceItem? = nil) -> UUID? {
        guard let projectID = selectedProjectID else { return nil }
        let draft = StudioDraft(projectID: projectID, referenceID: reference?.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), format: format,
            body: reference == nil ? "" : "Opening\n[Describe a real problem your audience recognizes.]\n\nYour perspective\n[Explain what you've learned or demonstrate your approach.]\n\nNext step\n[Offer something useful the reader can try.]")
        drafts.insert(draft, at: 0)
        persist()
        return draft.id
    }

    func updateDraft(_ id: UUID, title: String, body: String) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].title = title
        drafts[index].body = body
        drafts[index].updatedAt = Date()
        persist()
    }

    func deleteDraft(_ id: UUID) { drafts.removeAll { $0.id == id }; persist() }

    func updateBrand(_ color: BrandColor) {
        guard let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        projects[index].brandColor = color
        persist()
    }

    func addTarget(name: String, platform: Platform) {
        guard let projectID = selectedProjectID else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 160,
              watchTargets.filter({ $0.projectID == projectID }).count < 100 else { return }
        let profile = SocialProfile.resolve(name, platform: platform)
        guard !watchTargets.contains(where: { $0.projectID == projectID && $0.platform == (profile?.platform ?? platform) && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        let target = WatchTarget(projectID: projectID, name: name, platform: profile?.platform ?? platform, profileURL: profile?.url.absoluteString)
        watchTargets.append(target)
        invalidateFollowedResearch(projectID)
        persist()
        refreshResearch()
        Task { await cacheSourceAvatar(target.id) }
    }

    func cacheSourceAvatars() async {
        for target in watchTargets where target.avatarData == nil { await cacheSourceAvatar(target.id) }
    }
    private func cacheSourceAvatar(_ id: UUID) async {
        guard let target = watchTargets.first(where: { $0.id == id }), target.avatarData == nil,
              let profile = SocialProfile.resolve(target.profileURL ?? target.name, platform: target.platform),
              let client = try? ResearchClient(), let metadata = try? await client.metadata(profile.url.absoluteString),
              let image = metadata.profile_image, !image.isEmpty,
              let data = try? await ProjectIconAsset.download(image), !Task.isCancelled,
              let index = watchTargets.firstIndex(where: { $0.id == id }) else { return }
        watchTargets[index].platform = profile.platform
        watchTargets[index].profileURL = profile.url.absoluteString
        watchTargets[index].avatarData = data
        persist()
    }

    func removeTarget(_ id: UUID) {
        guard let target = watchTargets.first(where: { $0.id == id }) else { return }
        watchTargets.removeAll { $0.id == id }
        if focusedTargetID == id { focusedTargetID = nil }
        invalidateFollowedResearch(target.projectID)
        persist()
        if selectedProjectID == target.projectID { refreshResearch() }
    }

    private func invalidateFollowedResearch(_ projectID: UUID) {
        if let index = projects.firstIndex(where: { $0.id == projectID }) {
            projects[index].remoteResearchID = nil
        }
    }

    func references(for target: WatchTarget) -> [ReferenceItem] {
        projectReferences.filter { item in
            guard item.platform == target.platform else { return false }
            if target.profileURL != nil {
                let expected = target.displayName.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).lowercased()
                let author = item.author.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).lowercased()
                let url = URL(string: item.sourceURL ?? "")
                let components = url?.path.split(separator: "/").map(String.init) ?? []
                let host = url?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
                let accountInURL = (target.platform == .x && ["x.com", "twitter.com"].contains(host))
                    || (target.platform == .tiktok && host == "tiktok.com")
                let pathHandle = components.first?.trimmingCharacters(in: CharacterSet(charactersIn: "@")).lowercased()
                return author == expected || (accountInURL && pathHandle == expected)
            }
            let text = ([item.title, item.excerpt] + (item.matchedTopics ?? [])).joined(separator: " ").lowercased()
            let words = target.name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            let tokens = Set(text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }))
            return !words.isEmpty && words.allSatisfy { tokens.contains($0) }
        }
    }

    func exportDraft(_ draft: StudioDraft) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = (draft.title.isEmpty ? "Untitled draft" : draft.title)
            .replacingOccurrences(of: "/", with: "-") + ".txt"
        if panel.runModal() == .OK, let url = panel.url {
            do { try draft.body.write(to: url, atomically: true, encoding: .utf8) }
            catch { persistenceError = "Export failed: \(error.localizedDescription)" }
        }
    }
}
