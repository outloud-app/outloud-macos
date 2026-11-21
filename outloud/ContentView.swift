import SwiftUI
import AppKit

struct ContentView: View {
    @Namespace private var projectExpansion
    @State private var sidebarCollapsed = false
    @State private var workspaceFullScreen = false
    @State private var projectMenuOpen = false
    @State private var showAppInformation = false
    @FocusState private var projectMenuFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store: WorkspaceStore

    init() {
        #if DEBUG
        let previewing = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_PATH"] != nil
            && ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_REAL_DATA"] != "1"
        let workspace = WorkspaceStore(inMemory: previewing)
        let page = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_PAGE"]
        if previewing, !workspace.projects.isEmpty { workspace.projects[0].name = "Habit Tracker"; workspace.area = .workspace }
        if previewing, page == "studio" || page == "editor" {
            workspace.page = .studio
            let id = workspace.createDraft(title: "Progress, not perfection", format: .image,
                                           reference: workspace.projectReferences.first)!
            workspace.updateDraft(id, title: "Progress, not perfection",
                                  body: "Missed a day?\nYou haven't lost\nyour progress.")
            workspace.createDraft(title: "A different measure", format: .xPost, reference: workspace.projectReferences[3])
            workspace.createDraft(title: "The streak trap", format: .video, reference: workspace.projectReferences[1])
            workspace.createDraft(title: "Starting again", format: .reddit, reference: workspace.projectReferences[2])
            if page == "editor" { workspace.editingDraftID = id }
        }
        if previewing, page == "loading" { workspace.researchingProjectID = workspace.selectedProjectID }
        if previewing, page == "new-project" { workspace.showProjectForm = true }
        if previewing, page == "following" {
            workspace.page = .following
            if let projectID = workspace.selectedProjectID {
                workspace.watchTargets = [WatchTarget(projectID: projectID, name: "habit", platform: .instagram),
                    WatchTarget(projectID: projectID, name: "@maker", platform: .x, profileURL: "https://x.com/maker")]
            }
        }
        if previewing, page == "conversations" { workspace.page = .conversations }
        if previewing, page == "reference" { workspace.selectedReference = workspace.projectReferences.first }
        if previewing, page == "about" { workspace.showProjectBrief = true }
        if previewing, page == "home" { workspace.area = .home }
        if previewing, let encoded = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_RESEARCH_BASE64"],
           let data = Data(base64Encoded: encoded),
           let reply = try? JSONDecoder().decode(ResearchWorkspaceReply.self, from: data),
           let projectID = workspace.selectedProjectID {
            if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let profile = payload["project"] as? [String: Any] {
                workspace.projects[0].name = profile["name"] as? String ?? workspace.projects[0].name
                workspace.projects[0].researchKeywords = profile["keywords"] as? [String]
            }
            workspace.references.removeAll()
            workspace.applyResearch(reply, to: projectID)
            if page == "reference" { workspace.selectedReference = workspace.projectReferences.first }
        }
        if previewing, page == "projects" { workspace.area = .projects }
        if previewing, page == "settings" { workspace.showSettings = true }
        if previewing, let page, page.hasPrefix("loading-") || page.hasPrefix("refreshing-") {
            workspace.researchingProjectID = workspace.selectedProjectID
            if page.hasPrefix("loading-") { workspace.references.removeAll() }
            if page.hasSuffix("home") { workspace.area = .home }
            else if page.hasSuffix("conversations") { workspace.page = .conversations }
            else { workspace.page = .discover }
        }
        _store = State(initialValue: workspace)
        #else
        _store = State(initialValue: WorkspaceStore())
        #endif
    }

    var body: some View {
        ZStack {
            if store.showProjectForm {
                ProjectForm(store: store, expansion: projectExpansion, onClose: { store.showProjectForm = false })
            } else if store.area == .projects { ProjectWelcomeView(store: store, expansion: projectExpansion) }
            else { workspace }
        }

        #if DEBUG
        .task { await checkWindowTransitionsIfRequested() }
        #endif
        .task { await store.cacheProjectIcons(); await store.cacheSourceAvatars() }
        // AppKit owns the outer frame. Changing SwiftUI's size constraints here
        // causes a separate, unanimated resize before the native transition starts.
        .frame(width: ProjectWindowMorph.sizing.presentationSize?.width,
               height: ProjectWindowMorph.sizing.presentationSize?.height)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        // Children extend into the hidden title bar. The native window masks its
        // own edges; clipping this container cuts off the X and toolbar controls.
        .allowsHitTesting(!ProjectWindowMorph.sizing.isTransitioning)
        .frame(minWidth: ProjectWindowMorph.sizing.fixedSize?.width ?? 0,
               maxWidth: ProjectWindowMorph.sizing.fixedSize?.width ?? .infinity,
               minHeight: ProjectWindowMorph.sizing.fixedSize?.height ?? 0,
               maxHeight: ProjectWindowMorph.sizing.fixedSize?.height ?? .infinity)
        .background { if store.showProjectForm { Palette.background.ignoresSafeArea() } }
        .modifier(WorkspaceWindowBackground(showingStarter: store.area == .projects && !store.showProjectForm))
        .foregroundStyle(Palette.text)
        .preferredColorScheme(store.area == .projects && !store.showProjectForm ? nil : .light)
        .background(WorkspaceWindowMode(choosing: store.area == .projects || store.showProjectForm, creating: store.showProjectForm))
        .focusedSceneValue(\.outloudHasProject, store.area != .projects && !store.showProjectForm)
        .onReceive(NotificationCenter.default.publisher(for: .outloudCloseProject)) { _ in store.closeProject() }
        .onReceive(NotificationCenter.default.publisher(for: .outloudShowSettings)) { _ in
            guard store.area != .projects, !store.showProjectForm else { return }
            withAnimation(.easeInOut(duration: 0.2)) { store.showSettings = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .outloudWorkspaceAction)) { note in
            guard store.area != .projects, !store.showProjectForm, let action = note.object as? String else { return }
            switch action {
            case "home": store.showProjectBrief = false; store.selectedReference = nil; store.area = .home
            case "search": store.showGlobalSearch = true
            case "refresh": store.refreshResearch()
            case "reference": store.showImportForm = true
            case "source": store.showFollowingForm = true
            default: if let page = WorkspacePage(rawValue: action) { store.navigate(page) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .outloudNewProject)) { _ in store.beginProjectCreation() }

    }

    private var workspace: some View {
        VStack(spacing: 0) {
            workspaceToolbar
                .animation(reduceMotion ? nil : .timingCurve(0.22, 0.68, 0.2, 1, duration: 0.48), value: workspaceFullScreen)
                .zIndex(5)
            if store.showSettings {
                WorkspaceSettings(onClose: { withAnimation(.easeInOut(duration: 0.2)) { store.showSettings = false } })
            } else {
            HStack(spacing: 0) {
            WorkspaceSidebar(store: store, collapsed: $sidebarCollapsed, menuOpen: $projectMenuOpen)
                .frame(width: sidebarCollapsed ? 76 : 254)
            VStack(spacing: 0) {
                ZStack {
                Group {
                    if store.showProjectBrief, let project = store.project {
                        ProjectAboutView(store: store, project: project).id(project.id)
                    } else if let reference = store.selectedReference {
                        ReferenceDetail(store: store, reference: reference)
                    } else if store.area == .home && ProjectWindowMorph.isTransitioning {
                        Palette.background
                    } else if store.area == .home || showingDiscover {
                        ResearchDiscoverView(store: store)
                    } else if store.area == .projects {
                        ProjectsView(store: store)
                    } else if store.page == .studio || store.editingDraftID != nil {
                        StudioComingSoonView()
                    } else {
                        switch store.page {
                        case .discover: Color.clear
                        case .conversations: ConversationsView(store: store)
                        case .saved: DiscoveryView(store: store, savedOnly: true)
                        case .studio: StudioComingSoonView()
                        case .following: FollowingView(store: store)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(workspaceContentID)
                    .transition(workspaceContentTransition)
                }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: workspaceContentID)
                if let error = store.persistenceError {
                    Text(error).font(AppFont.ui(11)).foregroundStyle(.orange)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.background)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(hex: 0xD8D5CB).opacity(0.55)))
                .shadow(color: .black.opacity(0.035), radius: 5, x: 0, y: 2)
                .padding([.trailing, .bottom], 8)
            }
            }
        }
        .overlay(alignment: .topLeading) {
            if projectMenuOpen {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001).contentShape(Rectangle()).onTapGesture { closeProjectMenu() }
                    WorkspaceProjectMenu(store: store,
                        onSelect: { id in closeProjectMenu { store.selectProject(id) } },
                        onDetails: { closeProjectMenu { store.showProjectBrief = true } },
                        onCreate: { closeProjectMenu { store.beginProjectCreation() } })
                        .focusable().focusEffectDisabled().focused($projectMenuFocused)
                        .onAppear { projectMenuFocused = true }
                        .onExitCommand { closeProjectMenu() }
                        .padding(.leading, 12).padding(.top, 108)
                        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : -5)))
                }
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0 : 0.2), value: projectMenuOpen)
        .onExitCommand {
            if projectMenuOpen { closeProjectMenu() }
            else if store.showGlobalSearch { store.showGlobalSearch = false }
            else if store.showSettings { withAnimation(.easeInOut(duration: 0.2)) { store.showSettings = false } }
            else if workspaceFullScreen { NotificationCenter.default.post(name: .outloudExitFullScreen, object: nil) }
        }
        .background(WorkspaceTitlebarLayout(isFullScreen: $workspaceFullScreen).frame(width: 0, height: 0))
        .background(WorkspaceShellBackground()).foregroundStyle(Palette.text)
        .font(AppFont.ui(12)).tint(Palette.mint).preferredColorScheme(.light)
        .frame(minWidth: 1180, minHeight: 740)
        .ignoresSafeArea(.container, edges: .top)
        .task { if store.project != nil { store.refreshResearch() } }
        .sheet(isPresented: $store.showImportForm) { ImportReferenceForm(store: store) }
        .sheet(isPresented: $store.showDraftForm) { NewDraftForm(store: store) }
        .sheet(isPresented: $store.showFollowingForm) { FollowingForm(store: store) }
        .overlay {
            if store.showGlobalSearch {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea().contentShape(Rectangle())
                        .onTapGesture { store.showGlobalSearch = false }
                    GlobalSearchView(store: store, onDismiss: { store.showGlobalSearch = false })
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.border))
                        .shadow(color: .black.opacity(0.16), radius: 30, y: 12)
                }.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.showGlobalSearch)
    }

    private var showingDiscover: Bool {
        store.area == .workspace && store.page == .discover && !store.showProjectBrief
            && store.selectedReference == nil && store.editingDraftID == nil
    }

    private var workspaceContentTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .opacity.combined(with: store.selectedReference == nil ? .offset(y: 5) : .offset(x: 12))
    }

    private var workspaceContentID: String {
        if store.area == .home && ProjectWindowMorph.isTransitioning { return "opening-workspace" }
        if !store.showProjectBrief && store.selectedReference == nil && (store.area == .home || showingDiscover) {
            return "research-feed"
        }
        return store.showProjectBrief ? "about" : store.selectedReference?.id ?? (store.area == .home ? "home" : store.editingDraftID != nil ? "studio" : store.page.rawValue)
    }
    private func closeProjectMenu(after action: (() -> Void)? = nil) {
        withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.2)) { projectMenuOpen = false } completion: { action?() }
    }

    private var workspaceToolbar: some View {
        let alignsWithCollapsedSidebar = workspaceFullScreen && sidebarCollapsed
        let toggleLeading: CGFloat = workspaceFullScreen ? (alignsWithCollapsedSidebar ? 22 : 16) : 92
        // Only the collapsed full-screen layout follows the sidebar/content columns.
        // Every other layout keeps the original 14-point gap beside the toggle.
        let headerColumnWidth: CGFloat = alignsWithCollapsedSidebar ? 76 : toggleLeading + 32 + 14
        return HStack(spacing: 0) {
            HStack(spacing: 0) {
            WorkspaceToolbarButton(symbol: "sidebar.left", label: "Toggle sidebar", shortcut: "⇧⌘S") {
                withAnimation(.easeInOut(duration: 0.28)) { sidebarCollapsed.toggle() }
            }.keyboardShortcut("s", modifiers: [.command, .shift])
                .accessibilityLabel(sidebarCollapsed ? "Expand sidebar" : "Collapse sidebar")
                .padding(.leading, toggleLeading)
                Spacer(minLength: 0)
            }.frame(width: headerColumnWidth, alignment: .leading)
            Button { store.showGlobalSearch = true } label: {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
                    Text("Search this project").font(AppFont.ui(12))
                    Spacer()
                    Text("⌘K").font(AppFont.ui(10)).foregroundStyle(Palette.muted)
                }.foregroundStyle(Palette.secondary).padding(.horizontal, 12).frame(width: 235, height: 32)
                    .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.65)))
            }.buttonStyle(.plain).keyboardShortcut("k", modifiers: .command).help("Search this project")
            Spacer()
            WorkspaceToolbarButton(symbol: "questionmark.circle", label: "About & support", trailingTip: true) { showAppInformation.toggle() }
                .popover(isPresented: $showAppInformation, arrowEdge: .top) { AppInformationView().padding(24).frame(width: 300) }
        }.padding(.trailing, 20).frame(height: 52)
    }

}

private struct WorkspaceToolbarButton: View {
    let symbol: String
    let label: String
    var shortcut = ""
    var trailingTip = false
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: 0x625F67)).frame(width: 32, height: 30)
                .background(hovering ? Color.black.opacity(0.065) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).accessibilityLabel(label)
            .onHover { value in withAnimation(.easeOut(duration: 0.12)) { hovering = value } }
            .overlay(alignment: trailingTip ? .topTrailing : .topLeading) {
                if hovering {
                    HStack(spacing: 8) {
                        Text(label).font(.system(size: 11, weight: .medium))
                        if !shortcut.isEmpty {
                            Text(shortcut).font(.system(size: 10, weight: .medium)).padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }.foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color(hex: 0x25262A), in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                        .fixedSize().offset(y: 37).allowsHitTesting(false).transition(.opacity)
                }
            }
    }
}

struct WorkspaceSidebar: View {
    @State private var quickSettingsOpen = false
    @AppStorage("setupSound") private var quickSound = true
    @AppStorage("setupHaptics") private var quickHaptics = true
    @Bindable var store: WorkspaceStore
    @Binding var collapsed: Bool
    @Binding var menuOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { menuOpen.toggle() } } label: {
                HStack(spacing: 10) {
                    ProjectIdentityIcon(project: store.project, size: 28)
                    if !collapsed {
                        Text(store.project?.name ?? "Select project").font(AppFont.ui(15, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                            .rotationEffect(.degrees(menuOpen ? 180 : 0)).animation(.easeInOut(duration: 0.2), value: menuOpen)
                    }
                }.foregroundStyle(Palette.text).padding(.horizontal, collapsed ? 9 : 7.5).frame(height: 42)
                    .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).accessibilityLabel("Switch project")
                .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 25)

            ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("Workspace")
                row("Home", symbol: "house", selected: store.area == .home && !store.showProjectBrief) {
                    store.showProjectBrief = false; store.area = .home; store.selectedReference = nil; store.editingDraftID = nil
                }
                navigationRow(.discover)
                navigationRow(.conversations)
                row("About", symbol: "info.circle", selected: store.showProjectBrief) {
                    store.selectedReference = nil; store.editingDraftID = nil; store.area = .workspace; store.showProjectBrief = true
                }
                sectionLabel("Library").padding(.top, 25)
                navigationRow(.saved)
                navigationRow(.studio)
                sectionLabel("Sources").padding(.top, 25)
                row("Following", symbol: "dot.radiowaves.left.and.right", selected: !store.showProjectBrief && store.area == .workspace && store.page == .following) { store.navigate(.following) }
                ForEach(store.projectTargets) { target in
                    Button { store.navigate(.following); store.focusedTargetID = target.id } label: {
                        HStack(spacing: 9) {
                            SourceAvatar(target: target, size: 22)
                            if !collapsed { Text(target.displayName).font(AppFont.ui(13, weight: .medium)).lineLimit(1); Spacer(minLength: 0) }
                        }.foregroundStyle(Color(hex: 0x514D58)).padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading).frame(height: 37)
                    }.buttonStyle(.plain).help(target.displayName)
                        .contextMenu { Button("Remove source", role: .destructive) { store.removeTarget(target.id) } }
                }
                row("Add account or topic", symbol: "plus", selected: false) { store.showFollowingForm = true }
            }.padding(.horizontal, 12)
            }
            Spacer(minLength: 25)
            VStack(spacing: 4) {
                Link(destination: URL(string: "mailto:support@tryoutloud.xyz?subject=Outloud%20feedback")!) {
                    rowLabel("Give feedback", symbol: "bubble.left", selected: false)
                }.buttonStyle(.plain).help("Give feedback")
                Button { quickSettingsOpen.toggle() } label: {
                    rowLabel("Settings", symbol: "gearshape", selected: false)
                }.buttonStyle(.plain).help("Settings")
                    .popover(isPresented: $quickSettingsOpen, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                quickSettingsOpen = false
                                withAnimation(.easeInOut(duration: 0.2)) { store.showSettings = true }
                            } label: {
                                HStack { Label("Settings", systemImage: "gearshape"); Spacer(); Text("⌘,").foregroundStyle(.secondary) }
                                    .padding(10).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider().padding(.horizontal, 10)
                            Toggle("Project opening sound", isOn: $quickSound).padding(10)
                            Toggle("Trackpad feedback", isOn: $quickHaptics).padding(10)
                            Divider().padding(.horizontal, 10)
                            Link(destination: URL(string: "mailto:support@tryoutloud.xyz")!) {
                                Label("Contact support", systemImage: "questionmark.circle").padding(10)
                            }.buttonStyle(.plain)
                            Button { NSApp.orderFrontStandardAboutPanel(nil) } label: {
                                Label("About Outloud", systemImage: "info.circle").padding(10)
                            }.buttonStyle(.plain)
                        }.font(AppFont.ui(13)).foregroundStyle(Palette.text)
                            .toggleStyle(.switch).tint(Color(hex: 0x645675))
                            .padding(8).frame(width: 265).background(Palette.background).preferredColorScheme(.light)
                    }
                    .onAppear {
                        #if DEBUG
                        if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_PAGE"] == "quick-settings" { quickSettingsOpen = true }
                        #endif
                    }

            }.padding(.horizontal, 12).padding(.bottom, 19)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func sectionLabel(_ text: String) -> some View {
        if !collapsed {
            Text(text).font(AppFont.ui(13, weight: .medium)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 12).padding(.bottom, 7)
        }
    }
    private func navigationRow(_ page: WorkspacePage) -> some View {
        row(page.rawValue, symbol: page.symbol, selected: !store.showProjectBrief && store.area == .workspace && store.page == page && store.selectedReference == nil && store.editingDraftID == nil) { store.navigate(page) }
    }
    private func row(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(title, symbol: symbol, selected: selected) }
            .buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
    private func rowLabel(_ title: String, symbol: String, selected: Bool) -> some View {
        HStack(spacing: 11) {
            Group {
                if symbol == "house" { HomeSidebarIcon() }
                else { Image(systemName: symbol).font(.system(size: 15, weight: .medium)) }
            }.frame(width: 19, height: 19)
            if !collapsed {
                Text(title).font(AppFont.ui(14, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                if title == "Saved", !store.savedReferences.isEmpty { Text("\(store.savedReferences.count)").font(AppFont.ui(11)).foregroundStyle(Palette.muted) }
            }
        }.foregroundStyle(Color(hex: 0x514D58))
            .padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading).frame(height: 37)
            .background(selected ? Color.white.opacity(0.73) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Color.white.opacity(0.85) : .clear))
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .animation(.easeInOut(duration: 0.18), value: selected)
    }
}

struct ProjectIdentityIcon: View {
    let project: Project?
    var size: CGFloat
    var launcher = false
    var body: some View {
        Group {
            if let data = project?.iconData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit()
            } else if let value = project?.iconURL, let url = URL(string: value), url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() }
                    else { fallback }
                }
            } else { fallback }
        }.frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
    }
    @ViewBuilder private var fallback: some View {
        if launcher {
            Image(systemName: "folder.fill").font(.system(size: size * 0.72, weight: .regular))
                .foregroundStyle(project?.brandColor.color ?? Color(hex: 0xB5A9D2))
                .frame(width: size, height: size)
        } else {
            Text(String((project?.name ?? "Project").prefix(1)).uppercased())
                .font(AppFont.ui(size * 0.46, weight: .semibold))
                .foregroundStyle(Color(hex: 0x53465E)).frame(width: size, height: size)
                .background((project?.brandColor.color ?? Color(hex: 0xDFD8EB)).opacity(0.55))
        }
    }
}

struct WorkspaceProjectMenu: View {
    @Bindable var store: WorkspaceStore
    let onSelect: (UUID) -> Void
    let onDetails: () -> Void
    let onCreate: () -> Void
    private var otherProjects: [Project] { store.projects.filter { $0.id != store.selectedProjectID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                ProjectIdentityIcon(project: store.project, size: 32)
                Text(store.project?.name ?? "Project").font(AppFont.ui(14, weight: .medium)).lineLimit(1)
            }.padding(10)
            Button(action: onDetails) { Label("Product details", systemImage: "slider.horizontal.3").font(AppFont.ui(13)).padding(10).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain)
            if !otherProjects.isEmpty {
                Divider().padding(.vertical, 5)
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(otherProjects) { project in
                            Button { onSelect(project.id) } label: {
                                HStack(spacing: 10) {
                                    ProjectIdentityIcon(project: project, size: 25)
                                    Text(project.name).font(AppFont.ui(13)).lineLimit(1)
                                    Spacer(minLength: 0)
                                }.padding(9).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(height: min(CGFloat(otherProjects.count) * 46, 276))
            }
            Divider().padding(.vertical, 5)
            Button(action: onCreate) { Label("Create project", systemImage: "plus").font(AppFont.ui(13)).padding(10).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain)
        }.padding(7).frame(width: 254)
            .background { WorkspaceShellBackground().overlay(.white.opacity(0.3)) }
            .foregroundStyle(Palette.secondary).clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.85)))
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
    }
}

struct HomeSidebarIcon: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 2.5, y: 9))
            p.addQuadCurve(to: CGPoint(x: 3.7, y: 6.4), control: CGPoint(x: 2.5, y: 7.5))
            p.addLine(to: CGPoint(x: 8, y: 2.8))
            p.addQuadCurve(to: CGPoint(x: 11, y: 2.8), control: CGPoint(x: 9.5, y: 1.5))
            p.addLine(to: CGPoint(x: 15.3, y: 6.4))
            p.addQuadCurve(to: CGPoint(x: 16.5, y: 9), control: CGPoint(x: 16.5, y: 7.5))
            p.addLine(to: CGPoint(x: 16.5, y: 15))
            p.addQuadCurve(to: CGPoint(x: 14.5, y: 17), control: CGPoint(x: 16.5, y: 17))
            p.addLine(to: CGPoint(x: 11.7, y: 17)); p.addLine(to: CGPoint(x: 11.7, y: 11))
            p.addQuadCurve(to: CGPoint(x: 7.3, y: 11), control: CGPoint(x: 9.5, y: 9.2))
            p.addLine(to: CGPoint(x: 7.3, y: 17)); p.addLine(to: CGPoint(x: 4.5, y: 17))
            p.addQuadCurve(to: CGPoint(x: 2.5, y: 15), control: CGPoint(x: 2.5, y: 17)); p.closeSubpath()
        }.stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
    }
}

struct WorkspaceShellBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: 0xF0EEE7)
                RadialGradient(colors: [Color(hex: 0xD9D6EE).opacity(0.7), .clear], center: .topLeading, startRadius: 0, endRadius: proxy.size.height * 0.7)
                RadialGradient(colors: [Color(hex: 0xDFE7DA).opacity(0.7), .clear], center: .leading, startRadius: 0, endRadius: proxy.size.height * 0.5)
                RadialGradient(colors: [Color(hex: 0xF5E3CF).opacity(0.8), .clear], center: .bottomLeading, startRadius: 0, endRadius: proxy.size.height * 0.55)
            }
        }.ignoresSafeArea()
    }
}

#Preview { ContentView() }

#if DEBUG
extension ContentView {
    @MainActor private func checkWindowTransitionsIfRequested() async {
        let env = ProcessInfo.processInfo.environment
        if env["OUTLOUD_PREVIEW_UI_CHECK"] == "1", env["OUTLOUD_PREVIEW_PATH"] != nil {
            try? await Task.sleep(for: .milliseconds(600))
            if let window = ProjectWindowMorph.sourceWindow {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                fputs("UI check window: \(window.windowNumber) \(window.frame) visible=\(window.isVisible)\n", stderr)
            }
            return
        }
        guard env["OUTLOUD_PREVIEW_MOTION_CHECK"] == "1", env["OUTLOUD_PREVIEW_PATH"] != nil,
              env["OUTLOUD_PREVIEW_REAL_DATA"] != "1" else { return }
        func pause() async { try? await Task.sleep(for: .milliseconds(1200)) }
        func record(_ label: String) {
            guard let window = ProjectWindowMorph.sourceWindow ?? NSApp.windows.first(where: { $0.title == "Outloud" }), let view = window.contentView else { return }
            precondition(!ProjectWindowMorph.hasCover, "Transition cover must be removed after \(label)")
            precondition(!ProjectWindowMorph.sizing.isTransitioning && ProjectWindowMorph.sizing.presentationSize == nil, "Live layout must be released after \(label)")
            precondition(view.alphaValue == 1, "Content must be visible after \(label)")
            fputs("Motion constraints \(label): min=\(window.contentMinSize) max=\(window.contentMaxSize)\n", stderr)
            if label.hasPrefix("setup") || label.hasPrefix("cancel") || label.hasPrefix("return") {
                precondition(window.contentMinSize == window.contentMaxSize, "Chooser/setup must remain fixed in size")
                precondition(view.superview?.layer?.masksToBounds == true && view.superview?.layer?.cornerRadius == 16,
                             "Chooser/setup must share a rounded native frame mask, including bottom corners")
            }
            fputs("Motion check \(label): frame=\(window.frame) alpha=\(view.alphaValue) cover=none resizable=\(window.styleMask.contains(.resizable))\n", stderr)

        }
        if let project = store.projects.first, let sample = store.projectReferences.first {
            let count = max(0, min(5_000, Int(env["OUTLOUD_PREVIEW_MOTION_REFERENCES"] ?? "") ?? 0))
            if count > 0 {
                store.references = (0..<count).map { index in
                    var reference = sample
                    reference.id = "motion-check-\(index)"
                    reference.projectID = project.id
                    return reference
                }
                fputs("Motion check fixture: \(count) references\n", stderr)
            }
        }
        await pause()
        // A controlled backdrop makes true behind-window translucency observable.
        let backdrop = NSWindow(contentRect: NSRect(x: 300, y: 100, width: 1100, height: 950), styleMask: .borderless, backing: .buffered, defer: false)
        let backdropView = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 950))
        backdropView.wantsLayer = true; backdropView.layer?.backgroundColor = NSColor.systemBlue.cgColor
        let stripe = CALayer(); stripe.frame = CGRect(x: 550, y: 0, width: 550, height: 950); stripe.backgroundColor = NSColor.systemOrange.cgColor
        backdropView.layer?.addSublayer(stripe); backdrop.contentView = backdropView
        backdrop.isReleasedWhenClosed = false
        if let window = NSApp.windows.first(where: { $0 !== backdrop && $0.contentView != nil }) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            backdrop.order(.below, relativeTo: window.windowNumber)
        }
        defer { backdrop.close() }
        NSApp.appearance = NSAppearance(named: .aqua)
        await pause(); record("starter-light")
        NSApp.appearance = NSAppearance(named: .darkAqua)
        await pause(); record("starter-dark")
        for cycle in 1...max(1, min(10, Int(env["OUTLOUD_PREVIEW_MOTION_CYCLES"] ?? "10") ?? 10)) {
            NSApp.appearance = NSAppearance(named: cycle % 2 == 1 ? .aqua : .darkAqua)
            store.beginProjectCreation()
            await pause(); record("setup-\(cycle)")
            ProjectWindowMorph.collapse { store.showProjectForm = false }
            await pause(); record("cancel-\(cycle)")
            if let project = store.projects.first {
                ProjectWindowMorph.prepareWorkspace(); store.selectProject(project.id)
                await pause(); record("recent-\(cycle)")
                let workspaceFrame = ProjectWindowMorph.sourceWindow!.frame
                // The File menu and project switcher share this exact entry point.
                NotificationCenter.default.post(name: .outloudNewProject, object: nil)
                await pause(); record("setup-menu-\(cycle)")
                ProjectWindowMorph.collapse { store.showProjectForm = false }
                await pause(); record("workspace-cancel-\(cycle)")
                precondition(ProjectWindowMorph.sourceWindow!.frame.equalTo(workspaceFrame), "Cancel must restore its workspace origin")
                store.beginProjectCreation()
                await pause(); record("setup-switcher-\(cycle)")
                // Complete setup without making a research/provider request.
                ProjectWindowMorph.prepareWorkspace()
                store.showProjectForm = false
                await pause(); record("workspace-created-\(cycle)")
                store.closeProject()
                await pause(); record("return-\(cycle)")
                precondition(ProjectWindowMorph.sourceWindow!.frame.equalTo(ProjectWindowMorph.launcherFrame!), "Starter position must survive workspace setup")
                store.closeProject() // Closing an already-closed project must not hide the launcher.
                await pause(); record("return-repeat-\(cycle)")
                store.beginProjectCreation()
                await pause(); record("setup-close-command-\(cycle)")
                NotificationCenter.default.post(name: .outloudCloseProject, object: nil)
                await pause(); record("return-close-command-\(cycle)")
            }
        }
        NSApp.appearance = nil
    }
}
#endif

private struct WorkspaceWindowBackground: ViewModifier {
    var showingStarter: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(showingStarter ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear), for: .window)
        }
        else { content }
    }
}
