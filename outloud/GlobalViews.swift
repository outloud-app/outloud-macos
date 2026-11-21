import SwiftUI
import AppKit
import QuartzCore
import Lottie

struct GlobalSidebar: View {
    @Bindable var store: WorkspaceStore
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("outloud").font(AppFont.ui(20, weight: .bold)).tracking(-0.6).padding(.top, 48).padding(.bottom, 15)
            Eyebrow(text: "Workspace")
            Button { store.area = .home } label: {
                Label("Home", systemImage: "house").font(AppFont.ui(12))
                    .foregroundStyle(store.area == .home ? Palette.text : Palette.secondary)
            }.buttonStyle(.plain)
            Button { store.area = .projects } label: {
                Label("All projects", systemImage: "square.stack").font(AppFont.ui(12))
                    .foregroundStyle(store.area == .projects ? Palette.text : Palette.secondary)
            }.buttonStyle(.plain)
            Divider().overlay(Palette.border).padding(.vertical, 5)
            Eyebrow(text: "Your projects")
            ForEach(store.projects) { project in
                Button {
                    store.selectProject(project.id)
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(project.brandColor.color).frame(width: 15, height: 15)
                        Text(project.name).font(AppFont.ui(11)).foregroundStyle(Palette.secondary).lineLimit(1)
                    }
                }.buttonStyle(.plain)
            }
            Button { store.beginProjectCreation(); SetupFeedback.selection() } label: {
                Label("New project", systemImage: "plus").font(AppFont.ui(11)).foregroundStyle(Palette.muted)
            }.buttonStyle(.plain)
            Spacer()
            Label("Saved on this Mac", systemImage: "externaldrive").font(AppFont.ui(10)).foregroundStyle(Palette.muted)
                .padding(.bottom, 20)
        }.padding(.horizontal, 18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.sidebar)
    }
}

struct LegacyHomeView: View {
    @Bindable var store: WorkspaceStore
    private var references: [ReferenceItem] { store.projectReferences.filter { $0.category != "Conversation" } }
    private var conversations: [ReferenceItem] { store.projectReferences.filter { $0.category == "Conversation" } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let project = store.project {
                    PageHeading(title: project.name, subtitle: "Your project overview.") {
                        Button { store.navigate(.discover) } label: { Label("Explore references", systemImage: "safari") }.buttonStyle(AppButtonStyle())
                    }.padding(.horizontal, -22)
                    NativeResearchStatus(store: store).padding(.horizontal, -22)
                    HStack(spacing: 14) {
                        summary("References", value: references.count, symbol: "safari", page: .discover)
                        summary("Conversations", value: conversations.count, symbol: "bubble.left.and.bubble.right", page: .conversations)
                        summary("Saved", value: store.savedReferences.count, symbol: "bookmark", page: .saved)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("About \(project.name)").font(AppFont.ui(16, weight: .medium))
                            Spacer()
                            Button("Product details") { store.showProjectBrief = true }.buttonStyle(.plain).font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                        }
                        Text(project.description.isEmpty ? "Add a description in Product details." : project.description).font(AppFont.ui(13)).foregroundStyle(Palette.secondary).lineSpacing(5)
                        Divider().overlay(Palette.border.opacity(0.6))
                        HStack(alignment: .top, spacing: 45) {
                            detail("Platform", value: project.productPlatform == "Mac" ? "macOS" : project.productPlatform ?? "—")
                            detail("Status", value: project.launchStatus == nil ? "Not specified" : project.launchStatus == "launched" ? "Launched" : "Not launched")
                            detail("Audience", value: project.audience.isEmpty ? "Not specified" : project.audience)
                        }
                        if let url = ResearchSource.publicURL(project.website) {
                            Link(destination: url) { Label(url.host ?? "Product website", systemImage: "arrow.up.right").font(AppFont.ui(12)) }.foregroundStyle(Palette.secondary)
                        }
                    }.padding(22).background(Palette.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border.opacity(0.6)))
                    Text("Recent references").font(AppFont.ui(16, weight: .medium)).padding(.top, 5)
                    if references.isEmpty {
                        HStack {
                            Text("References for \(project.name) will appear here.").font(AppFont.ui(13)).foregroundStyle(Palette.secondary)
                            Spacer()
                            Button("Add reference") { store.showImportForm = true }.buttonStyle(AppButtonStyle())
                        }.padding(20).background(Palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        ForEach(Array(references.sorted { $0.createdAt > $1.createdAt }.prefix(5))) { reference in
                            Button { store.navigate(.discover); store.selectedReference = reference } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: reference.platform.symbol).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(reference.title).font(AppFont.ui(13)).lineLimit(1)
                                        Text(reference.platform.rawValue + " · " + reference.author).font(AppFont.ui(11)).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.system(size: 11))
                                }.foregroundStyle(Palette.secondary).padding(17).background(Palette.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(.horizontal, 26).padding(.bottom, 30)
        }
    }
    private func summary(_ title: String, value: Int, symbol: String, page: WorkspacePage) -> some View {
        Button { store.navigate(page) } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text(title).font(AppFont.ui(12)); Spacer(); Image(systemName: symbol).font(.system(size: 15)) }.foregroundStyle(Palette.secondary)
                Text("\(value)").font(AppFont.ui(28, weight: .medium)).foregroundStyle(Palette.text)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.border.opacity(0.6)))
        }.buttonStyle(.plain)
    }
    private func detail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(AppFont.ui(11)).foregroundStyle(Palette.muted)
            Text(value).font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
        }
    }
}

struct StudioComingSoonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            let width = min(620.0, geometry.size.width - 100)
            VStack(spacing: 0) {
                Text("STUDIO").font(AppFont.ui(11, weight: .semibold)).tracking(2.5).foregroundStyle(Palette.mint)
                Group {
                    if reduceMotion {
                        LottieView(animation: .named("StudioComingSoon")).paused(at: .progress(0.8))
                    } else {
                        LottieView(animation: .named("StudioComingSoon")).playing(loopMode: .playOnce)
                    }
                }.frame(width: width, height: width * 0.56)
                    .accessibilityElement(children: .ignore).accessibilityLabel("Coming soon")
                Text("From inspiration to your next idea.").font(AppFont.ui(25, weight: .medium)).multilineTextAlignment(.center)
                    .padding(.top, 8)
                Text("Studio is taking shape: a place to bring your saved references,\nresearch and ideas together as you create.")
                    .font(AppFont.ui(14)).foregroundStyle(Palette.secondary).lineSpacing(6).multilineTextAlignment(.center).padding(.top, 14)
                HStack(spacing: 27) {
                    Label("Your references", systemImage: "bookmark")
                    Label("Your research", systemImage: "sparkle.magnifyingglass")
                    Label("Your ideas", systemImage: "lightbulb")
                }.font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary).padding(.top, 30)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).offset(y: -26)
        }
    }
}

struct ProjectsView: View {
    @Bindable var store: WorkspaceStore
    var body: some View {
        VStack(spacing: 0) {
            PageHeading(title: "Projects", subtitle: "A separate workspace for each product you build.") {
                Button { store.beginProjectCreation(); SetupFeedback.selection() } label: { Label("New project", systemImage: "plus") }
                    .buttonStyle(AppButtonStyle(primary: true))
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 16)], spacing: 16) {
                    ForEach(store.projects) { project in ProjectTile(store: store, project: project) }
                }.padding(22)
            }
        }
    }
}

struct ProjectTile: View {
    @Bindable var store: WorkspaceStore
    let project: Project
    var body: some View {
        Button {
            store.selectProject(project.id)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ProjectIdentityIcon(project: project, size: 42)
                    Spacer()
                    if project.isExample {
                        Text("Example project").font(AppFont.ui(9)).foregroundStyle(Palette.muted)
                    }
                    Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Text(project.name).font(AppFont.ui(19, weight: .semibold)).foregroundStyle(Palette.text)
                Text(project.description.isEmpty ? "Research and create in your product workspace." : project.description)
                    .font(AppFont.ui(11)).foregroundStyle(Palette.secondary).lineSpacing(4)
                    .lineLimit(3).frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                Divider().overlay(Palette.border)
                HStack(spacing: 14) {
                    Text("\(store.references.filter { $0.projectID == project.id }.count) references")
                    Text("\(store.drafts.filter { $0.projectID == project.id }.count) drafts")
                }.font(AppFont.ui(10)).foregroundStyle(Palette.muted)
            }.padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.border))
        }.buttonStyle(.plain)
    }
}

struct GlobalSearchView: View {
    @Bindable var store: WorkspaceStore
    var onDismiss: () -> Void
    @State private var query = ""
    @State private var recentSearches: [String] = []
    @FocusState private var focused: Bool
    private var historyKey: String { "outloud.searchHistory." + (store.selectedProjectID?.uuidString ?? "none") }
    private var references: [ReferenceItem] {
        store.projectReferences.filter { query.isEmpty || "\($0.title) \($0.author) \($0.excerpt)".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                TextField("Search this project’s references…", text: $query)
                    .textFieldStyle(.plain).font(AppFont.ui(14)).focused($focused)
                    .onSubmit { rememberSearch() }
                Button("Esc", action: onDismiss).buttonStyle(.plain).font(AppFont.ui(10)).foregroundStyle(Palette.muted)
                    .keyboardShortcut(.cancelAction)
            }.padding(22)
            Divider().overlay(Palette.border)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if query.isEmpty && !recentSearches.isEmpty {
                        HStack {
                            Eyebrow(text: "Recent searches")
                            Spacer()
                            Button("Clear") { recentSearches = []; UserDefaults.standard.removeObject(forKey: historyKey) }
                                .buttonStyle(.plain).font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
                        }.padding(.vertical, 10)
                        ForEach(recentSearches, id: \.self) { term in
                            Button { query = term; rememberSearch() } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath").frame(width: 24)
                                    Text(term).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.left").font(.system(size: 10))
                                }.font(AppFont.ui(12)).foregroundStyle(Palette.secondary).padding(11).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                    if !references.isEmpty {
                        Eyebrow(text: "References").padding(.vertical, 10)
                        ForEach(Array(references.prefix(20))) { reference in
                            result(reference.title, subtitle: reference.platform.rawValue, symbol: "doc.text") {
                                rememberSearch()
                                store.showProjectBrief = false
                                store.selectedReference = reference
                                onDismiss()
                            }
                        }
                    } else {
                        Text(query.isEmpty ? "Searches you make here will appear above." : "No results for “\(query)”.")
                            .font(AppFont.ui(12)).foregroundStyle(Palette.secondary).padding(.vertical, 25)
                    }
                }.padding(18)
            }
        }.frame(width: 650, height: 450).background(Palette.background).foregroundStyle(Palette.text).preferredColorScheme(.light)
            .onAppear { recentSearches = UserDefaults.standard.stringArray(forKey: historyKey) ?? []; focused = true }
            .onExitCommand(perform: onDismiss)
            .onDisappear { rememberSearch() }
    }
    private func rememberSearch() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        recentSearches.removeAll { $0.localizedCaseInsensitiveCompare(term) == .orderedSame }
        recentSearches.insert(String(term.prefix(200)), at: 0)
        recentSearches = Array(recentSearches.prefix(5))
        UserDefaults.standard.set(recentSearches, forKey: historyKey)
    }
    private func result(_ title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(Palette.mint).frame(width: 24)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(AppFont.ui(12)).lineLimit(1)
                    Text(subtitle).font(AppFont.ui(10)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "return").foregroundStyle(Palette.muted).font(.system(size: 10))
            }.padding(11).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}


/// A compact native welcome window; project content stays in the full black workspace.
struct ProjectWelcomeView: View {
    @Bindable var store: WorkspaceStore
    @State private var deletingProject: Project?
    @State private var confirmingDeletion = false
    @State private var deletionName = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var expansion: Namespace.ID? = nil
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.colorScheme) private var systemScheme
    var body: some View {
        VStack(spacing: 0) {
            Image("OutloudMascot")
                .resizable().interpolation(.high).scaledToFill()
                .frame(width: 86, height: 86).scaleEffect(1.16)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous)).padding(.top, 44)
            Text("Outloud").font(.system(size: 23, weight: .semibold)).padding(.top, 10)
            newProject.background(ProjectCapsuleAnchor()).padding(.top, 28).padding(.bottom, 28)
            HStack {
                Text("Recent projects").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text("\(store.projects.count)").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 4).padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.projects) { project in
                        RecentProjectRow(project: project, open: {
                            ProjectWindowMorph.prepareWorkspace(); store.selectProject(project.id); SetupFeedback.complete()
                        }, delete: {
                            deletionName = ""; deletingProject = project
                            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72)) { confirmingDeletion = true }
                        }).transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))

                    }
                    if store.projects.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder").font(.system(size: 24, weight: .light))
                            Text("No recent projects").font(.system(size: 13))
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 54)
                    }
                }.padding(6).animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.84), value: store.projects.map(\.id))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background((systemScheme == .dark ? Color.black.opacity(0.12) : Color.white.opacity(0.22)), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(systemScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)))
            HStack {
                Link("Support", destination: URL(string: "mailto:support@tryoutloud.xyz")!).foregroundStyle(.secondary)
                Spacer()
                Text("⌘⇧N  New project").foregroundStyle(.tertiary)
            }.font(.system(size: 11)).padding(.top, 18)
        }
        .padding(.horizontal, 40).padding(.bottom, 28)
        .frame(minWidth: 480, idealWidth: 520, maxWidth: .infinity, minHeight: 600, idealHeight: 650, maxHeight: .infinity)
        .background((systemScheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.06)).ignoresSafeArea())
        .background {
            if #available(macOS 15.0, *) { Color.clear }
            else { WelcomeWindowSurface().ignoresSafeArea() }
        }
        .overlay(alignment: .topLeading) {
            Button { dismissWindow(id: "workspace") } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 30, height: 30)
                    .background(.white.opacity(0.08), in: Circle())
            }.buttonStyle(.plain).help("Close Window").accessibilityLabel("Close Window").padding(16)
        }
        .ignoresSafeArea(.container, edges: .top)
        .overlay {
            if confirmingDeletion, let project = deletingProject {
                ProjectDeletionConfirmation(project: project, cancel: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { confirmingDeletion = false }
                }) { typedName in
                    guard typedName == project.name else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { confirmingDeletion = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.84)) { _ = store.deleteProject(project.id, confirmedName: typedName) }
                        deletingProject = nil
                    }
                }.transition(.opacity)
            }
        }

    }

    @ViewBuilder private var newProject: some View {
        if #available(macOS 26.0, *) {
            Button { store.beginProjectCreation(); SetupFeedback.selection() } label: {
                Label("New Project", systemImage: "plus").font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    .padding(.horizontal, 26).padding(.vertical, 5)
            }.buttonStyle(.glass).controlSize(.large)
        } else {
            Button { store.beginProjectCreation(); SetupFeedback.selection() } label: {
                Label("New Project", systemImage: "plus").font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    .padding(.horizontal, 26).padding(.vertical, 5)
            }.buttonStyle(.bordered).controlSize(.large)
        }
    }
}

private struct RecentProjectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RecentProjectHighlight(pressed: configuration.isPressed) { configuration.label }
    }
}
private struct RecentProjectHighlight<Content: View>: View {
    var pressed: Bool
    @ViewBuilder var content: Content
    @State private var hovered = false
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        content.background((scheme == .dark ? Color.white : Color.black).opacity(pressed ? 0.13 : hovered ? 0.07 : 0), in: RoundedRectangle(cornerRadius: 10))
            .onHover { hovered = $0 }.animation(.easeOut(duration: 0.16), value: hovered)
    }
}

/// Uses Window Server vibrancy, so the desktop behind the window actually shows through.
struct WelcomeWindowSurface: NSViewRepresentable {
    @Environment(\.colorScheme) private var scheme
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.alphaValue = scheme == .dark ? 1 : 0.72
    }
}

/// Keep destination content stable during motion and lock chooser sizing at rest.
@MainActor @Observable final class WorkspaceWindowSizing {
    var fixedSize: NSSize?
    var presentationSize: NSSize?
    var isTransitioning = false
}

/// Resize only when entering/leaving the chooser, preserving user resizing within either view.
struct WorkspaceWindowMode: NSViewRepresentable {
    var choosing: Bool
    var creating = false
    final class Coordinator {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            let mode = creating ? 2 : choosing ? 1 : 0
            guard let window = view.window else { return }
            guard ProjectWindowMorph.enter(mode: mode, window: window) else { return }
            let initial = ProjectWindowMorph.isInitialMode
            window.styleMask.insert([.titled, .fullSizeContentView])
            window.hasShadow = true
            window.isMovableByWindowBackground = choosing
            window.titlebarAppearsTransparent = true
            // One shared native mask covers both the resize backing and live host.
            // Transparent chooser windows otherwise retain square bottom corners.
            if let frameView = window.contentView?.superview {
                frameView.wantsLayer = true
                frameView.layer?.cornerRadius = choosing ? 16 : 0
                frameView.layer?.masksToBounds = choosing
            }
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                if choosing { window.standardWindowButton(button)?.isHidden = true }
            }
            if choosing {
                window.styleMask.remove(.resizable)
                window.collectionBehavior.remove(.fullScreenPrimary)
                window.collectionBehavior.insert(.fullScreenNone)
            } else {
                window.styleMask.insert(.resizable)
                window.collectionBehavior.remove(.fullScreenNone)
                window.collectionBehavior.insert(.fullScreenPrimary)
            }
            let old = ProjectWindowMorph.transitionOrigin ?? window.frame
            window.contentMinSize = .zero
            window.contentMaxSize = NSSize(width: 10000, height: 10000)
            let size = creating ? NSSize(width: 850, height: 720) : choosing ? NSSize(width: 520, height: 650) : NSSize(width: 1280, height: 820)
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
            // SwiftUI reserves the hidden title-bar safe area around fixed content.
            // Include it in the animated destination, not in a second resize at rest.
            if choosing { frame.size.height += max(0, window.frame.height - window.contentLayoutRect.height) }
            let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? old
            let center = initial ? NSPoint(x: visible.midX, y: visible.midY) : NSPoint(x: old.midX, y: old.midY)
            let target = NSRect(x: center.x - frame.width / 2, y: center.y - frame.height / 2, width: frame.width, height: frame.height)
            let destination = mode == 1
                ? ProjectWindowMorph.starterDestination(in: window, size: frame.size)
                : !choosing ? (window.screen ?? NSScreen.main)?.visibleFrame ?? target : target
            let surface = NSColor(red: 250.0 / 255, green: 248.0 / 255, blue: 240.0 / 255, alpha: 1)
            let workspaceSurface = surface
            // Keep a visible window surface while its content is exchanged. Otherwise
            // the clear setup window becomes an invisible expanding frame on cancel.
            if !initial {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
            ProjectWindowMorph.sizing.presentationSize = initial ? nil : (choosing ? size : destination.size)
            let lockSize = {
                // SwiftUI updates scene resizability while mounting the new host.
                // Apply the final native policy after that layout has settled.
                for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                    window.standardWindowButton(button)?.isHidden = choosing
                }
                window.isOpaque = !choosing
                window.backgroundColor = choosing ? .clear : workspaceSurface
                // Match the actual destination content rect, including the hidden
                // titlebar allowance, so locking cannot clamp the final frame.
                let lockedContent = window.contentRect(forFrameRect: destination).size
                window.contentMinSize = choosing ? lockedContent : NSSize(width: 1180, height: 740)
                window.contentMaxSize = choosing ? lockedContent : NSSize(width: 10000, height: 10000)
                ProjectWindowMorph.sizing.fixedSize = choosing ? size : nil
            }
            if let restored = ProjectWindowMorph.returnFrame, !creating {
                ProjectWindowMorph.returnFrame = nil
                ProjectWindowMorph.openWorkspace(window: window, destination: restored, completion: lockSize)
            } else if creating && ProjectWindowMorph.pending {
                ProjectWindowMorph.expand(window: window, destination: destination, completion: lockSize)
            } else if !initial {
                ProjectWindowMorph.openWorkspace(window: window, destination: destination, completion: lockSize)
            } else {
                window.setFrame(destination, display: true)
                ProjectWindowMorph.clearCover(in: window)
                lockSize()
            }
        }
    }
}

/// One native window resizes consistently between the starter, setup and workspace.
@MainActor enum ProjectWindowMorph {
    static let sizing = WorkspaceWindowSizing()
    static var isTransitioning: Bool { sizing.isTransitioning || workspacePending }
    static var capsule: NSRect?
    static weak var anchor: NSView?
    static weak var sourceWindow: NSWindow?
    static var launcherFrame: NSRect?
    static var returnFrame: NSRect?
    private static var setupReturnFrame: NSRect?
    static var transitionOrigin: NSRect?
    static var pending = false
    static var workspacePending = false
    private static weak var modeWindow: NSWindow?
    private static var currentMode: Int?
    private(set) static var isInitialMode = true

    static func enter(mode: Int, window: NSWindow) -> Bool {
        if modeWindow !== window { currentMode = nil; modeWindow = window }
        guard currentMode != mode else { return false }
        isInitialMode = currentMode == nil
        currentMode = mode
        sourceWindow = window
        return true
    }

    private static var transitionID = UUID()
    private static var backingSurface: NSVisualEffectView?
    private static var surfaceTint: NSView?
    #if DEBUG
    private static var debugSamples = 0
    #endif

    /// The live SwiftUI content is laid out at its destination size, then clipped
    /// by the native window during its resize. Never turn vibrancy into a bitmap.
    private static func capture() {
        transitionID = UUID()
        sizing.fixedSize = nil
        sizing.isTransitioning = true
        if let window = sourceWindow ?? NSApp.keyWindow {
            // Establish the continuous surface before hiding content, including
            // transitions that start from the translucent launcher.
            window.isOpaque = false
            window.backgroundColor = .clear
            if let content = window.contentView, let parent = content.superview {
                backingSurface?.removeFromSuperview()
                let surface = NSVisualEffectView(frame: content.frame)
                surface.material = .hudWindow
                surface.blendingMode = .behindWindow
                surface.state = .active
                let tint = NSView(frame: surface.bounds)
                tint.wantsLayer = true
                tint.layer?.backgroundColor = NSColor(red: 250.0/255, green: 248.0/255, blue: 240.0/255, alpha: 1).cgColor
                tint.autoresizingMask = [.width, .height]
                tint.alphaValue = currentMode == 1 ? 0 : 1
                surface.addSubview(tint)
                surfaceTint = tint
                surface.autoresizingMask = [.width, .height]
                parent.addSubview(surface, positioned: .below, relativeTo: content)
                backingSurface = surface
                content.alphaValue = 0
            }
        }
    }
    static func clearCover(in window: NSWindow) {
        transitionID = UUID()
        window.contentView?.alphaValue = 1
        backingSurface?.removeFromSuperview(); backingSurface = nil; surfaceTint = nil
        sizing.presentationSize = nil
        sizing.isTransitioning = false
    }
    static var hasCover: Bool { false }
    private static func mainWindow() -> NSWindow? {
        // A project-switcher popover can be key; it must never supply our frame.
        if let sourceWindow, sourceWindow.isVisible { return sourceWindow }
        return NSApp.windows.first { $0.title == "Outloud" && $0.contentView != nil }
            ?? NSApp.mainWindow
    }
    static func begin(fromStarter: Bool = true) {
        sourceWindow = mainWindow()
        transitionOrigin = sourceWindow?.frame
        setupReturnFrame = transitionOrigin
        returnFrame = nil
        if fromStarter { launcherFrame = transitionOrigin }
        capture()
        pending = true
    }
    static func prepareWorkspace() {
        sourceWindow = mainWindow()
        transitionOrigin = sourceWindow?.frame
        if let frame = transitionOrigin, frame.width < 600 { launcherFrame = frame }
        setupReturnFrame = nil
        returnFrame = nil
        capture()
        workspacePending = true
    }
    static func prepareReturn() {
        sourceWindow = mainWindow()
        transitionOrigin = sourceWindow?.frame
        capture()
    }
    static func starterDestination(in window: NSWindow, size: NSSize) -> NSRect {
        let screen = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        var frame = launcherFrame ?? NSRect(x: screen.midX - size.width / 2,
                                            y: screen.midY - size.height / 2,
                                            width: size.width, height: size.height)
        frame.origin.x = min(max(frame.minX, screen.minX), screen.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, screen.minY), screen.maxY - frame.height)
        return frame
    }
    static func expand(window: NSWindow, destination: NSRect, completion: @escaping () -> Void) {
        pending = false
        grow(window: window, from: transitionOrigin ?? window.frame, to: destination, completion: completion)
    }
    static func resize(window: NSWindow, destination: NSRect, completion: @escaping () -> Void) {
        grow(window: window, from: transitionOrigin ?? window.frame, to: destination, completion: completion)
    }
    static func openWorkspace(window: NSWindow, destination: NSRect, completion: @escaping () -> Void) {
        workspacePending = false
        grow(window: window, from: transitionOrigin ?? window.frame, to: destination, completion: completion)
    }
    private static func grow(window: NSWindow, from: NSRect, to: NSRect, completion: @escaping () -> Void) {
        sourceWindow = window; transitionOrigin = nil
        let id = UUID(); transitionID = id
        sizing.isTransitioning = true
        let content = window.contentView
        if let content, let parent = content.superview, let surface = backingSurface {
            if surface.superview !== parent { surface.removeFromSuperview(); parent.addSubview(surface, positioned: .below, relativeTo: content) }
            surface.frame = content.frame
        }
        content?.alphaValue = 0
        content?.layoutSubtreeIfNeeded()
        let finish = {
            guard transitionID == id else { return }
            completion()
            // Both native limits and material are already at their destination.
            // Crossfade the live content with the same material, without a late
            // opaque-to-vibrant background switch.
            sizing.presentationSize = nil
            window.contentView?.layoutSubtreeIfNeeded()
            #if DEBUG
            if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_MOTION_CHECK"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard transitionID == id else { return }
                    precondition(backingSurface?.alphaValue == 1, "Backing must fully cover the reveal; complementary alpha fades expose the desktop")
                    if currentMode != 1 { precondition(surfaceTint?.alphaValue == 1, "Setup/workspace reveal must retain an opaque backdrop") }
                    fputs("Reveal coverage verified: backing=1 destination=\(currentMode ?? -1)\n", stderr)
                }
            }
            #endif
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.contentView?.animator().alphaValue = 1
                // Keep full backing coverage until the incoming host is opaque.
                // Simultaneous alpha fades expose the desktop at their midpoint.
            } completionHandler: {
                Task { @MainActor in
                    guard transitionID == id else { return }
                    window.contentView?.alphaValue = 1
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_MOTION_CHECK"] == "1" {
                        precondition(abs(window.frame.width - to.width) < 1 && abs(window.frame.height - to.height) < 1,
                                     "Final sizing constraints must not snap the animated destination")
                    }
                    #endif
                    backingSurface?.removeFromSuperview(); backingSurface = nil; surfaceTint = nil
                    sizing.isTransitioning = false
                }
            }
        }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.setFrame(to, display: true); finish(); return
        }
        window.setFrame(from, display: true)
        // Blend the destination material during motion, never as a final colour swap.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.48
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            surfaceTint?.animator().alphaValue = currentMode == 1 ? 0 : 1
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_MOTION_CHECK"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                guard transitionID == id, let live = window.contentView else { return }
                precondition(sizing.presentationSize != nil, "Incoming content must keep a stable layout during resize")
                precondition(live.alphaValue == 0, "Text must stay hidden until its destination frame is ready")
                precondition(backingSurface?.superview != nil && backingSurface?.alphaValue == 1, "Resize must keep its native backing surface when SwiftUI changes window material")
                precondition((backingSurface?.bounds.width ?? 0) >= live.bounds.width - 1, "Backing surface must fill the resizing window")
                fputs("Live motion sample: frame=\(window.frame) layout=\(sizing.presentationSize!) alpha=\(live.alphaValue) bitmap=none\n", stderr)
                if let bitmap = live.bitmapImageRepForCachingDisplay(in: live.bounds) {
                    live.cacheDisplay(in: live.bounds, to: bitmap)
                    debugSamples += 1
                    if let sample = Int(ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_MID_FRAME"] ?? ""), sample == debugSamples,
                       let data = bitmap.representation(using: .png, properties: [:]) {
                        // Export the visible app surface, respecting the host's
                        // opacity; cacheDisplay alone ignores NSView.alphaValue.
                        let image = NSImage(data: data)!
                        let visible = NSImage(size: live.bounds.size)
                        visible.lockFocus()
                        window.backgroundColor.setFill(); live.bounds.fill()
                        image.draw(in: live.bounds, from: .zero, operation: .sourceOver, fraction: live.alphaValue)
                        visible.unlockFocus()
                        if let tiff = visible.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) { FileHandle.standardOutput.write(png) }
                        NSApp.terminate(nil)
                    }
                }
            }
        }
        #endif
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.68
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0, 0.2, 1)
            window.animator().setFrame(to, display: true)
        } completionHandler: { Task { @MainActor in finish() } }
    }
    static func collapse(completion: @escaping () -> Void) {
        prepareReturn()
        returnFrame = setupReturnFrame
        setupReturnFrame = nil
        // Change the view once; WorkspaceWindowMode owns the single resize animation.
        completion()
    }
}
private struct ProjectCapsuleAnchor: NSViewRepresentable {
    final class Anchor: NSView {
        override func layout() {
            super.layout()
            guard let window, bounds.width > 0 else { return }
            ProjectWindowMorph.anchor = self
            ProjectWindowMorph.sourceWindow = window
            ProjectWindowMorph.capsule = window.convertToScreen(convert(bounds, to: nil))
        }
    }
    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) { view.needsLayout = true }
}

private struct RecentProjectRow: View {
    let project: Project
    let open: () -> Void
    let delete: () -> Void
    @State private var hovering = false
    @State private var reveal: CGFloat = 0
    @State private var travel: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: delete) {
                Image(systemName: "trash").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    .frame(width: max(64, reveal - 12), height: 46)
                    .background(LinearGradient(colors: [Color(red: 0.91, green: 0.24, blue: 0.3), Color(red: 0.63, green: 0.06, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                    .shadow(color: .red.opacity(0.22), radius: 7, y: 2)
            }.buttonStyle(FluidPressStyle()).padding(.trailing, 5).opacity(min(1, Double(reveal / 76))).allowsHitTesting(reveal > 30)
                .accessibilityLabel("Delete \(project.name)").accessibilityHidden(reveal < 30)
            Button(action: { if reveal > 0 { withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)) { reveal = 0; travel = 0 } } else { open() } }) {
                HStack(spacing: 12) {
                    ProjectIdentityIcon(project: project, size: 34, launcher: true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.name).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary).lineLimit(1)
                        Text(project.productPlatform ?? "App").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
                }.padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
                    .background(reveal > 0 ? Color(nsColor: .windowBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).offset(x: -reveal)
        }.background(hovering ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay { ProjectRowSwipeSurface { delta, finished in
                if finished {
                    let forceReveal = travel > 160
                    withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.64)) { reveal = travel > 30 ? (forceReveal ? 180 : 76) : 0 }
                    travel = reveal
                    if forceReveal { SetupFeedback.selection(); delete(); travel = 0; withAnimation(.easeOut(duration: 0.25)) { reveal = 0 } }
                } else {
                    travel = min(420, max(0, travel + delta))
                    reveal = travel <= 76 ? travel : 76 + sqrt(travel - 76) * 7
                }
            } }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onHover { hovering = $0 }
            .contextMenu {
                Button("Open project", action: open)
                Divider()
                Button("Delete project…", role: .destructive, action: delete)
            }
    }
}
