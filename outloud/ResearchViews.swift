import SwiftUI
import AppKit
import AVKit

struct PageHeading<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(AppFont.ui(28, weight: .semibold)).tracking(-0.8)
                Text(subtitle).font(AppFont.ui(13)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            actions
        }.padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 12)
    }
}

struct FilterMenu: View {
    let title: String
    let options: [String]
    let select: (String) -> Void
    @State private var isPresented = false
    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 10) {
                Text(title).font(AppFont.ui(11))
                Image(systemName: "chevron.down").font(.system(size: 8))
            }.foregroundStyle(Palette.secondary).padding(.horizontal, 10).frame(height: 29)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.border))
        }.buttonStyle(.plain).fixedSize()
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(options, id: \.self) { option in
                        Button { select(option); isPresented = false } label: {
                            HStack {
                                Text(option).font(AppFont.ui(11))
                                Spacer()
                                if title == option || title == "Sort: " + option {
                                    Image(systemName: "checkmark").font(.system(size: 10)).foregroundStyle(Palette.mint)
                                }
                            }.padding(9).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }.padding(7).frame(width: 180).background(Palette.surface).preferredColorScheme(.light)
            }
    }
}

struct UnderlineTabs: View {
    let tabs: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 24) {
            ForEach(tabs, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 12) {
                        Text(tab).font(AppFont.ui(12, weight: selection == tab ? .semibold : .regular))
                            .foregroundStyle(selection == tab ? Palette.text : Palette.secondary)
                        Rectangle().fill(selection == tab ? Palette.mint : .clear).frame(height: 2)
                    }.fixedSize(horizontal: true, vertical: false)
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 22)
    }
}

/// Packs cards by measured height, keeping mixed formats at their natural aspect ratios.
struct MasonryLayout: Layout {
    var spacing: CGFloat = 10
    private func arrangement(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (CGSize, [CGPoint], CGFloat) {
        // Native window sizing probes layouts with an unbounded proposal.
        // Use our ideal width for that probe; never convert infinity to an Int.
        let proposedWidth = proposal.width ?? 980
        let width = proposedWidth.isFinite ? max(1, proposedWidth) : 980
        let count = Int(max(1, min(4, (width + spacing) / 224)))
        let columnWidth = (width - CGFloat(count - 1) * spacing) / CGFloat(count)
        var heights = Array(repeating: CGFloat.zero, count: count)
        var origins: [CGPoint] = []
        for view in subviews {
            let column = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
            let size = view.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            origins.append(CGPoint(x: CGFloat(column) * (columnWidth + spacing), y: heights[column]))
            heights[column] += size.height + spacing
        }
        return (CGSize(width: width, height: max(0, (heights.max() ?? 0) - spacing)), origins, columnWidth)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(proposal, subviews).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, origins, width) = arrangement(ProposedViewSize(width: bounds.width, height: nil), subviews)
        for (index, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + origins[index].x, y: bounds.minY + origins[index].y),
                       anchor: .topLeading, proposal: ProposedViewSize(width: width, height: nil))
        }
    }
}

struct DiscoveryView: View {
    @Bindable var store: WorkspaceStore
    var savedOnly = false
    @State private var platform = "All platforms"
    @State private var format = "All formats"
    @State private var range = "Any time"
    @State private var category = "For you"
    @State private var sort = "Original order"
    private var items: [ReferenceItem] {
        let source = savedOnly ? store.savedReferences : store.projectReferences
        let result = source.filter {
            (savedOnly || $0.category != "Conversation")
                && (platform == "All platforms" || $0.platform.rawValue == platform)
                && (format == "All formats" || $0.category == format)
                && (category != "Competitors" || $0.isCompetitor)
                && (savedOnly || category != "For you" || !$0.isCompetitor)
                && (range == "Any time" || $0.createdAt > Date().addingTimeInterval(range == "Last 7 days" ? -604800 : -2592000))
                && (store.searchText.isEmpty || "\($0.title) \($0.author) \($0.excerpt)".localizedCaseInsensitiveContains(store.searchText))
        }
        return sort == "Recently added" ? result.sorted { $0.createdAt > $1.createdAt } : result
    }
    var body: some View {
        VStack(spacing: 0) {
            PageHeading(title: savedOnly ? "Saved" : "Discover",
                        subtitle: savedOnly ? "Your references, collected in one place." : "Ideas worth adapting for \(store.project?.name ?? "your product").") {
                Button { store.showImportForm = true } label: { Label("Add reference", systemImage: "plus") }
                    .buttonStyle(AppButtonStyle(primary: true))
            }
            UnderlineTabs(tabs: ["For you", "Competitors"], selection: $category)
            Rectangle().fill(Palette.border).frame(height: 1)
            HStack(spacing: 9) {
                FilterMenu(title: platform, options: ["All platforms"] + Platform.allCases.map(\.rawValue)) { platform = $0 }
                FilterMenu(title: format, options: ["All formats", "Video", "Image", "Conversation", "Text", "Reference"]) { format = $0 }
                FilterMenu(title: range, options: ["Any time", "Last 7 days", "Last 30 days"]) { range = $0 }
                FilterMenu(title: "Sort: " + sort, options: ["Original order", "Recently added"]) { sort = $0 }
                Spacer()
                Text("\(items.count) references").font(AppFont.ui(10)).foregroundStyle(Palette.muted)
            }.padding(.horizontal, 22).padding(.vertical, 13)
            NativeResearchStatus(store: store)
            if store.isResearching && items.isEmpty && !savedOnly {
                NativeResearchSkeleton()
            } else if items.isEmpty {
                EmptyWorkspaceView(symbol: savedOnly ? "bookmark" : "safari",
                    title: savedOnly ? "Your saved references" : "No references yet",
                    message: "Add a reference or adjust your filters to begin.",
                    actionTitle: "Add reference") { store.showImportForm = true }
            } else {
                ScrollView {
                    MasonryLayout {
                        ForEach(items) { item in ResearchFeedTile(store: store, item: item) }
                    }.padding(.horizontal, 18).padding(.bottom, 20)
                }
            }
            HStack {
                Spacer()
                Text(items.contains(where: { $0.isExample }) ? "Example references" : "Research and your saved references")
                    .font(AppFont.ui(9)).foregroundStyle(Palette.muted)
            }.padding(.horizontal, 20).padding(.vertical, 8)
        }
    }
}

struct ReferenceCard: View {
    @Bindable var store: WorkspaceStore
    let reference: ReferenceItem
    private var textOnly: Bool { reference.platform == .reddit || reference.platform == .x }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                PlatformBadge(platform: reference.platform, size: 18)
                Text(reference.platform.rawValue + " · " + reference.author)
                    .font(AppFont.ui(9)).foregroundStyle(Palette.secondary).lineLimit(1)
                Spacer(minLength: 3)
                Button { store.toggleSaved(reference) } label: {
                    Image(systemName: store.savedIDs.contains(reference.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(store.savedIDs.contains(reference.id) ? Palette.mint : Palette.secondary)
                        .frame(width: 22, height: 26)
                }.buttonStyle(.plain).help("Save or unsave reference")
            }.padding(.horizontal, 9).frame(height: 34)
            Button { store.selectedReference = reference } label: {
                VStack(alignment: .leading, spacing: 0) {
                    if !textOnly {
                        ReferenceArtwork(reference: reference).frame(height: reference.category == "Video" ? 318 : 220)
                            .clipped().clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(alignment: .bottomLeading) {
                                if reference.category == "Video" {
                                    Label(reference.isExample ? "Video example" : "Video", systemImage: "play.fill").font(AppFont.ui(9))
                                        .padding(6).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(.white).padding(8)
                                }
                            }.padding(.horizontal, 4)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(reference.title).font(AppFont.ui(textOnly ? 16 : 11, weight: textOnly ? .semibold : .medium))
                            .lineSpacing(3).foregroundStyle(Palette.text).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if textOnly {
                            Text(reference.excerpt).font(AppFont.ui(12)).lineSpacing(4).lineLimit(3)
                                .foregroundStyle(Palette.secondary).multilineTextAlignment(.leading)
                        }
                        ReferenceMetrics(reference: reference)
                        HStack {
                            Text(reference.isExample ? "Example reference" : reference.retrievedFromResearch == true ? "Research reference" : "Manual import")
                                .font(AppFont.ui(9)).foregroundStyle(Palette.muted)
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                        }
                        Text(reference.isCompetitor ? "Product positioning" : "Audience insight")
                            .font(AppFont.ui(9)).foregroundStyle(Palette.secondary)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Palette.elevated, in: Capsule())
                    }.padding(textOnly ? 14 : 10)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.border))
    }
}

struct PlatformBadge: View {
    let platform: Platform
    var size: CGFloat = 22
    private var assetName: String? {
        switch platform {
        case .reddit: "PlatformReddit"
        case .instagram: "PlatformInstagram"
        case .x: "PlatformX"
        case .tiktok: "PlatformTikTok"
        case .web: nil
        }
    }
    var body: some View {
        Group {
            if let assetName {
                Image(assetName).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "globe").font(.system(size: size * 0.65, weight: .regular))
                    .foregroundStyle(Palette.secondary)
            }
        }.frame(width: size, height: size).accessibilityLabel(platform.rawValue)
    }
}

struct LegacyConversationsView: View {
    @Bindable var store: WorkspaceStore
    @State private var platform = "Reddit"
    @State private var selectedID: String?
    @State private var reply = ""
    @State private var copied = false
    private var conversations: [ReferenceItem] {
        store.projectReferences.filter {
            $0.category == "Conversation" && !$0.isCompetitor && $0.platform.rawValue == platform && (store.searchText.isEmpty || "\($0.title) \($0.excerpt)".localizedCaseInsensitiveContains(store.searchText))
        }
    }
    private var selected: ReferenceItem? {
        conversations.first { $0.id == selectedID }
    }
    var body: some View {
        VStack(spacing: 0) {
            PageHeading(title: "Conversations", subtitle: "Find people discussing the problem your product solves.") {
                Button { store.showImportForm = true } label: { Label("Add conversation", systemImage: "plus") }
                    .buttonStyle(AppButtonStyle())
            }
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    ForEach(["Reddit", "X"], id: \.self) { value in
                        Button { platform = value; selectedID = nil; reply = ""; copied = false } label: {
                            HStack(spacing: 6) {
                                PlatformBadge(platform: value == "Reddit" ? .reddit : .x, size: 17)
                                Text(value).font(AppFont.ui(12, weight: .medium))
                            }.padding(.horizontal, 12).padding(.vertical, 6)
                                .background(platform == value ? Palette.selected : .clear, in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain)
                    }
                }.padding(3).background(Palette.surface, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.border))
                Text("Your project references").font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
                Spacer()
            }.padding(.horizontal, 22).padding(.bottom, 17)
            Rectangle().fill(Palette.border).frame(height: 1)
            NativeResearchStatus(store: store)
            if store.isResearching && conversations.isEmpty {
                NativeResearchSkeleton(conversations: true)
            } else if conversations.isEmpty {
                EmptyWorkspaceView(symbol: "bubble.left.and.bubble.right", title: "No conversations yet",
                    message: "Import a conversation from \(platform) to keep its context beside your draft.",
                    actionTitle: "Import conversation") { store.showImportForm = true }
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Relevant discussions · \(conversations.count)").font(AppFont.ui(10))
                                .foregroundStyle(Palette.muted).padding(15)
                            ForEach(conversations) { item in
                                Button {
                                    selectedID = item.id
                                    reply = ""
                                    copied = false
                                } label: {
                                    HStack(alignment: .top, spacing: 9) {
                                        PlatformBadge(platform: item.platform, size: 23)
                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(item.author).font(AppFont.ui(10)).foregroundStyle(Palette.secondary)
                                            Text(item.title).font(AppFont.ui(12, weight: .semibold)).foregroundStyle(Palette.text)
                                            Text(item.excerpt).font(AppFont.ui(11)).foregroundStyle(Palette.secondary).lineLimit(3)
                                            Text(item.isExample ? "Example discussion" : item.retrievedFromResearch == true ? "Research reference" : "Manual import").font(AppFont.ui(9)).foregroundStyle(Palette.muted)
                                        }.multilineTextAlignment(.leading)
                                    }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(selected?.id == item.id ? Palette.selected.opacity(0.6) : .clear)
                                        .overlay(alignment: .leading) {
                                            if selected?.id == item.id { RoundedRectangle(cornerRadius: 2).fill(Palette.mint).frame(width: 3) }
                                        }
                                }.buttonStyle(.plain)
                                Rectangle().fill(Palette.border).frame(height: 1)
                            }
                        }
                    }.frame(maxWidth: selected == nil ? .infinity : 330)
                    if let selected {
                        Rectangle().fill(Palette.border).frame(width: 1)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 21) {
                                HStack(spacing: 9) {
                                    PlatformBadge(platform: selected.platform)
                                    Text(selected.author).font(AppFont.ui(11, weight: .medium))
                                    Spacer()
                                    Button { selectedID = nil } label: { Image(systemName: "xmark").frame(width: 26, height: 26) }
                                        .buttonStyle(.plain).help("Close conversation")
                                }
                                Text(selected.title).font(AppFont.ui(21, weight: .semibold)).tracking(-0.4)
                                ReferenceMetrics(reference: selected)
                                if let source = ResearchSource.publicURL(selected.sourceURL) {
                                    Link(destination: source) { Label("Open original", systemImage: "arrow.up.right") }
                                        .buttonStyle(AppButtonStyle())
                                }
                                Text(selected.excerpt).font(AppFont.ui(13)).lineSpacing(6).foregroundStyle(Palette.secondary)
                                Divider().overlay(Palette.border)
                                Text("Why it fits").font(AppFont.ui(12, weight: .semibold))
                                Text(selected.approach)
                                    .font(AppFont.ui(11)).foregroundStyle(Palette.secondary).lineSpacing(4)
                                Divider().overlay(Palette.border)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("A useful contribution").font(AppFont.ui(13, weight: .semibold))
                                    Text("Write a thoughtful reply that adds value to the conversation.")
                                        .font(AppFont.ui(11)).foregroundStyle(Palette.muted)
                                }
                                TextEditor(text: $reply).font(AppFont.ui(12)).scrollContentBackground(.hidden)
                                    .padding(10).frame(height: 125).background(Palette.surface, in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.border))
                                HStack {
                                    Spacer()
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(reply, forType: .string)
                                        copied = true
                                    } label: { Label(copied ? "Copied" : "Copy draft", systemImage: "doc.on.doc") }
                                        .buttonStyle(AppButtonStyle()).disabled(reply.isEmpty)
                                    Button {
                                        let id = store.createDraft(title: selected.title,
                                            format: selected.platform == .x ? .xPost : .reddit, reference: selected)
                                        if let id, !reply.isEmpty { store.updateDraft(id, title: selected.title, body: reply) }
                                        store.selectedReference = nil
                                        store.page = .studio
                                        store.editingDraftID = id
                                    } label: { Label("Studio · Coming soon", systemImage: "arrow.right") }.buttonStyle(AppButtonStyle()).disabled(true)
                                }
                            }.padding(23)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
        }.onChange(of: reply) { _, _ in copied = false }
            .onChange(of: store.selectedProjectID) { _, _ in selectedID = nil; reply = ""; copied = false }

    }
}

struct ReferenceDetail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var store: WorkspaceStore
    let reference: ReferenceItem

    private var backTitle: String {
        store.area == .home ? "Back to Home" : "Back to \(store.page.rawValue)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.23)) { store.selectedReference = nil }
                } label: {
                    Label(backTitle, systemImage: "arrow.left")
                }.buttonStyle(AppButtonStyle())
                Spacer()
                if let url = ResearchSource.publicURL(reference.sourceURL) {
                    Link(destination: url) { Label("Open original", systemImage: "arrow.up.right") }
                        .buttonStyle(AppButtonStyle())
                }
                Button { store.toggleSaved(reference) } label: {
                    Label(store.savedIDs.contains(reference.id) ? "Saved" : "Save reference",
                          systemImage: store.savedIDs.contains(reference.id) ? "bookmark.fill" : "bookmark")
                }.buttonStyle(AppButtonStyle())
            }.padding(22)
            GeometryReader { geometry in
                let height = max(160, geometry.size.height - 22)
                let portrait = reference.category == "Video"
                let width = min(geometry.size.width * 0.38, height * (portrait ? 9.0 / 16.0 : 0.85))
                HStack(alignment: .top, spacing: 18) {
                    if portrait || reference.category == "Image" {
                        NativeReferenceMedia(reference: reference)
                            .frame(width: width, height: height)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            HStack(spacing: 8) {
                                PlatformBadge(platform: reference.platform)
                                Text(reference.author).font(AppFont.ui(14, weight: .medium))
                            }
                            Text(reference.title).font(AppFont.ui(24, weight: .semibold))
                                .tracking(-0.4).lineLimit(3)
                            ReferenceMetrics(reference: reference)
                            if portrait {
                                section("Opening hook", openingHook)
                            }
                            section("Why it fits", reference.approach)
                            if reference.excerpt != reference.title {
                                section(portrait || reference.category == "Image" ? "Original caption" : "Original post", reference.excerpt)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    }.frame(maxWidth: .infinity)
                        .background(Palette.elevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    studioPreview.frame(width: min(230, geometry.size.width * 0.23))
                }.padding(.horizontal, 20).padding(.bottom, 20)
            }
        }
    }

    private var studioPreview: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Make it yours").font(AppFont.ui(18, weight: .semibold))
            Text("Adapt this reference to your brand’s voice, visuals, and audience.")
                .font(AppFont.ui(13)).foregroundStyle(Palette.secondary).lineSpacing(4)
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    Label("Video", systemImage: "play.rectangle")
                    Image(systemName: "photo")
                    PlatformBadge(platform: .x, size: 16)
                    PlatformBadge(platform: .reddit, size: 16)
                }.font(AppFont.ui(12, weight: .medium))
                Text("Your angle").font(AppFont.ui(12, weight: .semibold))
                Text("How would your brand tell this story?")
                    .font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                Text("Draft preview").font(AppFont.ui(12, weight: .semibold))
            }.padding(12)
                .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 12))
                .blur(radius: 3).opacity(0.55).accessibilityHidden(true)
            Label("Studio coming soon", systemImage: "paintbrush.pointed")
                .font(AppFont.ui(12, weight: .semibold)).foregroundStyle(Palette.secondary)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.elevated.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
    }

    private var openingHook: String {
        if reference.isExample { return reference.hook }
        guard let transcript = reference.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
              !transcript.isEmpty else {
            return "Watch the opening to see how the creator introduces the idea. A spoken transcript is unavailable."
        }
        return transcript.split(whereSeparator: \.isWhitespace).prefix(24).joined(separator: " ")
            + (transcript.split(whereSeparator: \.isWhitespace).count > 24 ? "…" : "")
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(AppFont.ui(14, weight: .semibold))
            Text(text).font(AppFont.ui(14)).foregroundStyle(Palette.secondary).lineSpacing(5)
                .textSelection(.enabled)
        }
    }
}
