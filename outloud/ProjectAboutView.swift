import SwiftUI
import UniformTypeIdentifiers

struct ProjectAboutView: View {
    @Bindable var store: WorkspaceStore
    @State private var draft: Project
    @State private var original: Project
    @State private var imageWarning: String?
    @State private var keywordHighlight = false
    @FocusState private var keywordFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var importingIcon = false
    @State private var readingLink = false
    @State private var message: String?
    @State private var keywords: String
    @State private var competitors: String
    @State private var saved = false
    @State private var confirmingIconRemoval = false
    @State private var resizeHover = false
    @State private var section = "Overview"
    @State private var choosingPlatform = false
    @State private var descriptionHeight: CGFloat = 180
    @State private var resizeStart: CGFloat?
    private let fieldFill = Color(hex: 0xF1EEE5)
    private var platformName: String { draft.productPlatform == "Mac" ? "macOS" : draft.productPlatform ?? "Choose platform" }
    init(store: WorkspaceStore, project: Project) {
        self.store = store
        _draft = State(initialValue: project)
        _original = State(initialValue: project)
        _section = State(initialValue: store.aboutSection)
        _keywords = State(initialValue: (project.researchKeywords ?? []).joined(separator: ","))
        _competitors = State(initialValue: (project.competitors ?? []).joined(separator: "\n"))
    }
    private var edited: Project {
        var result = draft
        result.researchKeywords = ResearchKeywords.parse(keywords)
        result.competitors = CompetitorNames.parse(competitors)
        return result
    }
    private var hasChanges: Bool { !ProjectEditRules.same(edited, original) }
    private var validationIssue: String? { ProjectEditRules.issue(edited, original: original, keywords: keywords) }
    private var valid: Bool { validationIssue == nil }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About").font(AppFont.ui(28, weight: .semibold)).tracking(-0.7)
                        Text("The details behind your project.").font(AppFont.ui(13)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Button(saved ? "Saved" : "Save changes", action: save).buttonStyle(AppButtonStyle(primary: true)).disabled(!hasChanges || !valid || readingLink)
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: hasChanges)
                }
                HStack(spacing: 16) {
                    ProjectIdentityIcon(project: draft, size: 60)
                        .overlay(alignment: .bottomTrailing) {
                            Button { importingIcon = true } label: {
                                Image(systemName: "pencil").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.background)
                                    .frame(width: 25, height: 25).background(Palette.text, in: Circle())
                                    .overlay(Circle().strokeBorder(Palette.background, lineWidth: 2))
                            }.buttonStyle(.plain).help("Change project icon").accessibilityLabel("Change project icon").offset(x: 5, y: 5)
                        }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.name.isEmpty ? "Your app" : draft.name).font(AppFont.ui(19, weight: .medium)).lineLimit(1)
                        Text(platformName + " · " + (draft.launchStatus == "unlaunched" ? "Not launched" : "Launched"))
                            .font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    if draft.iconData != nil || draft.iconURL != nil {
                        Button { confirmingIconRemoval = true } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain).foregroundStyle(Palette.secondary).help("Remove project icon")
                    }
                }.padding(.vertical, 4)
                HStack(spacing: 3) {
                    ForEach(["Overview", "Research", "Appearance"], id: \.self) { tab in
                        Button { section = tab } label: {
                            Text(tab).font(AppFont.ui(13, weight: .medium)).padding(.horizontal, 20).frame(height: 34)
                                .foregroundStyle(section == tab ? Palette.background : Palette.secondary)
                                .background(section == tab ? Palette.text : .clear, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }.padding(4).background(fieldFill.opacity(0.75), in: Capsule()).padding(.bottom, 2)
                Group {
                    if section == "Overview" { overview }
                    else if section == "Research" { research }
                    else { appearance }
                }
                if let message { Label(message, systemImage: saved ? "checkmark.circle" : "info.circle").font(AppFont.ui(12)).foregroundStyle(Palette.secondary) }
                if let validationIssue {
                    Text(validationIssue)
                        .font(AppFont.ui(11)).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
            }.padding(30).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.fileImporter(isPresented: $importingIcon, allowedContentTypes: [.item]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let type = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
                guard type == .png || type == .jpeg || type == .heic || type == .heif else { throw IconImportError.unsupportedFormat }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 10_000_000 else { throw IconImportError.tooLarge }
                draft.iconData = try ProjectIconAsset.pngData(Data(contentsOf: url), requireSquare: true)
                draft.iconURL = nil; draft.iconCustomized = true
                saved = false; message = nil
            } catch CocoaError.userCancelled { }
            catch let error as IconImportError {
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72)) { imageWarning = error.localizedDescription }
            } catch {
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72)) { imageWarning = "This image couldn’t be read. Choose a square PNG, JPEG or HEIC image under 10 MB." }
            }
        }
        .alert("Remove project icon?", isPresented: $confirmingIconRemoval) {
            Button("Cancel", role: .cancel) { }
            Button("Remove icon", role: .destructive) { draft.iconData = nil; draft.iconURL = nil; draft.iconCustomized = true; saved = false }
        } message: { Text("Your project will use its placeholder until you add another icon.") }
        .overlay {
            if let imageWarning {
                ImageImportWarning(message: imageWarning) { withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) { self.imageWarning = nil } }
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .onAppear { if section == "Research" { focusKeywords() } }
        .onChange(of: store.keywordFocusID) { _, _ in section = "Research"; focusKeywords() }
        .onChange(of: section) { _, value in store.aboutSection = value }
        .onChange(of: draft) { _, _ in saved = false }
        .onChange(of: keywords) { _, _ in saved = false }
        .onChange(of: competitors) { _, _ in saved = false }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 22) {
                field("App name", text: $draft.name, placeholder: "App name")
                VStack(alignment: .leading, spacing: 9) {
                    Text("Platform").font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary)
                    Button { choosingPlatform.toggle() } label: {
                        HStack(spacing: 9) {
                            SetupPlatformBadge(platform: draft.productPlatform ?? "Other", size: 26)
                            Text(platformName).font(AppFont.ui(13))
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 10))
                        }.foregroundStyle(Palette.text).padding(.horizontal, 12).frame(height: 44)
                            .background(fieldFill.opacity(0.65), in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain).accessibilityLabel("Change platform")
                        .popover(isPresented: $choosingPlatform, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Choose your platform").font(AppFont.ui(15, weight: .medium))
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                                    ForEach(["iOS", "Android", "Web", "Mac", "Windows", "Linux", "HarmonyOS", "Other"], id: \.self) { platform in
                                        Button {
                                            draft.productPlatform = platform; choosingPlatform = false
                                        } label: {
                                            VStack(spacing: 8) {
                                                SetupPlatformBadge(platform: platform, size: 42)
                                                Text(platform == "Mac" ? "macOS" : platform).font(AppFont.ui(11, weight: .medium))
                                            }.frame(maxWidth: .infinity).padding(.vertical, 12)
                                                .background(draft.productPlatform == platform ? Palette.mint.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }.padding(20).frame(width: 390).background(Palette.background).preferredColorScheme(.light)
                        }
                }.frame(width: 210)
            }
            HStack(spacing: 14) {
                Text("Launch status").font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary)
                HStack(spacing: 3) {
                    ForEach(["launched", "unlaunched"], id: \.self) { status in
                        Button { draft.launchStatus = status } label: {
                            Text(status == "launched" ? "Launched" : "Not launched").font(AppFont.ui(12, weight: .medium))
                                .padding(.horizontal, 17).frame(height: 31)
                                .foregroundStyle((draft.launchStatus ?? "launched") == status ? Palette.background : Palette.secondary)
                                .background((draft.launchStatus ?? "launched") == status ? Palette.text : .clear, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }.padding(3).background(fieldFill, in: Capsule())
                Spacer()
            }
            HStack(alignment: .bottom, spacing: 12) {
                field("Public link", text: $draft.website, placeholder: "Website, App Store or Google Play link")
                Button(action: readLink) {
                    HStack(spacing: 7) { if readingLink { ProgressView().controlSize(.small) }; Text(readingLink ? "Reading…" : "Read link") }
                }.buttonStyle(AppButtonStyle()).disabled(draft.website.isEmpty || readingLink).padding(.bottom, 6)
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("What it does").font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary)
                    Spacer()
                    Text("\(draft.description.count)/1,200").font(AppFont.ui(11)).foregroundStyle(draft.description.count > 1200 ? .red : Palette.muted)
                }
                VStack(alignment: .leading, spacing: 0) {
                    TextEditor(text: $draft.description).font(AppFont.ui(14)).lineSpacing(5)
                        .scrollContentBackground(.hidden).padding(12).frame(height: descriptionHeight)
                        .accessibilityLabel("What your app does")
                    HStack {
                        Image(systemName: "line.3.horizontal").font(.system(size: 10, weight: .medium)).rotationEffect(.degrees(-45))
                            .foregroundStyle(Palette.secondary.opacity(resizeHover ? 0.9 : 0.35)).frame(width: 30, height: 20)
                        Spacer()
                    }.padding(.horizontal, 5).contentShape(Rectangle())
                        .onHover { inside in resizeHover = inside; if inside { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() } }
                        .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                            if resizeStart == nil { resizeStart = descriptionHeight }
                            descriptionHeight = min(600, max(100, (resizeStart ?? 180) + value.translation.height))
                        }.onEnded { _ in resizeStart = nil })
                        .accessibilityLabel("Resize description editor").help("Drag the bottom edge to resize")
                }.background(fieldFill.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            }
            field("Audience", text: $draft.audience, placeholder: "Everyone, or a particular group")
        }
    }
    private var research: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Research keywords").font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary)
                    Spacer()
                    Text("\(keywords.count)/100").font(AppFont.ui(11)).foregroundStyle(keywords.count > 100 ? .red : Palette.muted)
                }
                TextField("Words or phrases, separated by commas", text: $keywords).textFieldStyle(.plain).font(AppFont.ui(14)).padding(13)
                    .background(fieldFill.opacity(0.65), in: RoundedRectangle(cornerRadius: 11)).accessibilityLabel("Research keywords, required")
                    .focused($keywordFocused)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.mint.opacity(keywordHighlight ? 0.55 : 0), lineWidth: 2))
                    .shadow(color: Palette.mint.opacity(keywordHighlight ? 0.12 : 0), radius: 12)
                    .scaleEffect(keywordHighlight && !reduceMotion ? 1.01 : 1)
            }
            field("Competitors · optional", text: $competitors, placeholder: "Names or public links, one per line", multiline: true)
        }
    }
    private var appearance: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Project colour").font(AppFont.ui(14, weight: .medium))
            Text("A small touch to make this workspace yours.").font(AppFont.ui(13)).foregroundStyle(Palette.secondary)
            HStack(spacing: 18) {
                ForEach(BrandColor.allCases) { colour in
                    Button { draft.brandColor = colour; saved = false } label: {
                        VStack(spacing: 9) {
                            Circle().fill(colour.color).frame(width: 38, height: 38).padding(5)
                                .overlay(Circle().strokeBorder(draft.brandColor == colour ? Palette.mint : .clear, lineWidth: 1.5))
                            Text(colour.rawValue).font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                        }
                    }.buttonStyle(.plain).accessibilityLabel(colour.rawValue)
                }
            }
        }
    }
    private func field(_ label: String, text: Binding<String>, placeholder: String, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary)
            TextField(placeholder, text: text, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 3...6 : 1...1).textFieldStyle(.plain).font(AppFont.ui(14)).padding(13)
                .background(fieldFill.opacity(0.65), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityLabel(label)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func focusKeywords() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            keywordFocused = true
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) { keywordHighlight = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.7)) { keywordHighlight = false }
            }
        }
    }
    private func readLink() {
        readingLink = true; message = nil
        let value = draft.website.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = value.contains("://") ? value : "https://" + value
        Task {
            defer { readingLink = false }
            do {
                let metadata = try await ResearchClient().metadata(url)
                let icon = metadata.icon == nil ? nil : try? await ProjectIconAsset.download(metadata.icon!)
                guard draft.website.trimmingCharacters(in: .whitespacesAndNewlines) == value else { return }
                draft.website = url
                draft.name = String(metadata.title.prefix(70))
                draft.description = metadata.researchDescription
                draft.iconURL = metadata.icon; draft.iconData = icon; draft.iconCustomized = false
                message = "Product details updated from your link. Review them, then save your changes."
            } catch { message = error.localizedDescription }
        }
    }
    private func save() {
        guard hasChanges, valid else { return }
        func entries(_ value: String, separator: String, limit: Int) -> [String] {
            Array(value.components(separatedBy: separator).map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240)) }.filter { !$0.isEmpty }.prefix(limit))
        }
        let value = draft.website.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = value.isEmpty || value.contains("://") ? value : "https://" + value
        store.updateBrief(id: draft.id, name: draft.name, description: draft.description, audience: draft.audience, website: url,
            color: draft.brandColor, platform: draft.productPlatform ?? "Other", status: draft.launchStatus ?? "launched",
            keywords: ResearchKeywords.parse(keywords), competitors: CompetitorNames.parse(competitors),
            iconURL: draft.iconURL, iconData: draft.iconData, replaceIcon: true, iconCustomized: draft.iconCustomized)
        saved = store.persistenceError == nil
        if saved, let stored = store.projects.first(where: { $0.id == draft.id }) {
            original = stored; draft = stored
            keywords = (stored.researchKeywords ?? []).joined(separator: ",")
            competitors = (stored.competitors ?? []).joined(separator: "\n")
        }
        message = store.persistenceError ?? "Changes saved on this Mac."
    }
}
