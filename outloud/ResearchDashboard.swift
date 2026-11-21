import SwiftUI
import Lottie

private let feedInk = Color(hex: 0x2E2C26)
private let feedChip = Color(hex: 0xEFEDE5)
private let conversationPaper = Color(hex: 0xF1EEE4)

private func matchesResearchTopic(_ item: ReferenceItem, _ topic: String) -> Bool {
    topic.isEmpty || (item.matchedTopics ?? []).contains(where: { $0.localizedCaseInsensitiveCompare(topic) == .orderedSame })
        || "\(item.title) \(item.excerpt) \(item.approach)".localizedCaseInsensitiveContains(topic)
}

private struct ResearchChip: View {
    let title: String
    var selected = false
    var symbol: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .medium)) }
                Text(title).font(AppFont.ui(13, weight: .medium)).lineLimit(1)
            }.padding(.horizontal, 13).frame(height: 32)
                .foregroundStyle(selected ? Palette.background : feedInk)
                .background(selected ? feedInk : feedChip, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).fixedSize()
    }
}

private struct ResearchTopicBar: View {
    @Bindable var store: WorkspaceStore
    var platform: Binding<String>? = nil
    var status: Binding<String>? = nil
    var pastWeek: Binding<Bool>? = nil
    var body: some View {
        HStack(spacing: 12) {
            if let platform {
                HStack(spacing: 8) {
                    ForEach(["All platforms", "Reddit", "X"], id: \.self) { value in
                        Button { platform.wrappedValue = value } label: {
                            HStack(spacing: 6) {
                                if let service = Platform(rawValue: value) { PlatformBadge(platform: service, size: 18) }
                                Text(value).font(AppFont.ui(13, weight: .medium))
                            }.padding(.horizontal, 12).frame(height: 32)
                                .foregroundStyle(platform.wrappedValue == value ? Palette.background : feedInk)
                                .background(platform.wrappedValue == value ? feedInk : feedChip, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain).fixedSize()
                    }
                }
                Divider().frame(height: 22)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ResearchChip(title: "All", selected: store.researchTopic.isEmpty) { store.researchTopic = "" }
                    ForEach(store.project?.researchKeywords ?? [], id: \.self) { topic in
                        ResearchChip(title: topic, selected: store.researchTopic == topic) { store.researchTopic = topic }
                    }
                    ResearchChip(title: "Edit keywords", symbol: "plus") { store.editResearchKeywords() }
                }.padding(.vertical, 2)
            }
            if let pastWeek {
                ResearchChip(title: "Past week", selected: pastWeek.wrappedValue) { pastWeek.wrappedValue.toggle() }
            }
            if let status { FilterMenu(title: "Status: " + status.wrappedValue, options: ["New", "Leads", "All"]) { status.wrappedValue = $0 } }
            Button { store.refreshResearch() } label: { Image(systemName: "arrow.clockwise").frame(width: 32, height: 32) }
                .buttonStyle(.plain).help("Refresh research").disabled(store.researchingProjectID == store.selectedProjectID)
        }.padding(.horizontal, 28).padding(.vertical, 8)
    }
}

private struct ResearchBandHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(AppFont.ui(19, weight: .semibold)).tracking(-0.4)
            Text(subtitle).font(AppFont.ui(13)).foregroundStyle(Palette.secondary)
        }.foregroundStyle(feedInk)
    }
}

private func canShowInResearchFeed(_ item: ReferenceItem) -> Bool {
    guard item.retrievedFromResearch == true else { return true }
    let views = item.measuredViews
    if !item.isCompetitor { return item.category != "Video" || (views ?? 0) >= 1_000 }
    let likes = item.measuredLikes ?? 0
    let comments = item.measuredComments ?? 0
    if item.platform == .reddit { return (item.measuredScore ?? 0) >= 10 || comments >= 5 }
    if item.category == "Video" { return (views ?? 0) >= 3_000 && (likes >= 15 || comments >= 5) }
    if item.platform == .x {
        if let views { return views >= 500 && (likes >= 10 || comments >= 4) }
        return likes >= 20 || comments >= 8
    }
    return likes >= 15 || comments >= 5
}

private struct ResearchEmpty: View {
    let message: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            LottieView { try await DotLottieFile.named("ResearchEmptyTumbleweed") }
                .configuration(LottieConfiguration(renderingEngine: .mainThread))
                .playbackMode(reduceMotion ? .paused(at: .progress(0.5)) : .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce)))
                .aspectRatio(3835.0 / 1678, contentMode: .fit)
                .frame(maxWidth: 460)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)
            Text(message)
                .font(AppFont.ui(14, weight: .medium))
                .foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 275)
        .multilineTextAlignment(.center)
    }
}

private struct FeedMetrics: View {
    let item: ReferenceItem
    var body: some View {
        HStack(spacing: 10) {
            if let value = item.measuredViews { Text("\(value.formatted(.number.notation(.compactName))) views") }
            if let value = item.measuredLikes { Label(value.formatted(.number.notation(.compactName)), systemImage: "heart") }
            if let value = item.measuredComments { Label(value.formatted(.number.notation(.compactName)), systemImage: "bubble.right") }
        }.font(AppFont.ui(11)).lineLimit(1)
    }
}

struct ResearchFeedTile: View {
    @Bindable var store: WorkspaceStore
    let item: ReferenceItem
    var interactive = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    private var visual: Bool { item.category == "Video" || item.category == "Image" }
    var body: some View {
        ZStack(alignment: visual ? .bottomLeading : .topLeading) {
            if visual {
                ReferenceArtwork(reference: item, fillsFrame: true, loadsWhenVisible: true)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title).font(AppFont.ui(14, weight: .semibold)).lineLimit(2)
                    FeedMetrics(item: item)
                }.foregroundStyle(.white).padding(13)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Spacer().frame(height: 26)
                    Text(item.title).font(AppFont.ui(17, weight: .semibold)).tracking(-0.3).lineLimit(6)
                    Text(item.excerpt).font(AppFont.ui(13)).foregroundStyle(Palette.secondary).lineLimit(3)
                    Text(item.author).font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
                    FeedMetrics(item: item).foregroundStyle(Palette.secondary)
                }.padding(16)
            }
            VStack {
                HStack {
                    PlatformBadge(platform: item.platform, size: 25)
                    if visual {
                        Text(item.author).font(AppFont.ui(11, weight: .semibold)).lineLimit(1)
                            .foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 4)
                            .background(.black.opacity(0.66), in: Capsule())
                    }
                    Spacer(minLength: 0)
                    if store.savedIDs.contains(item.id) {
                        Image(systemName: "bookmark.fill").font(.system(size: 11)).padding(7).background(.white.opacity(0.94), in: Circle()).foregroundStyle(feedInk)
                    }
                }
                if visual { Spacer(minLength: 0) }
            }.padding(11).frame(maxHeight: visual ? .infinity : nil, alignment: .top)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .modifier(FeedCardAspect(visual: visual, video: item.category == "Video"))
            .background(conversationPaper).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.border.opacity(visual ? 0.2 : 0.75)))
            .overlay(alignment: .trailing) {
                if hovering && interactive {
                    VStack(spacing: 8) {
                        Button { store.toggleSaved(item) } label: { Image(systemName: store.savedIDs.contains(item.id) ? "bookmark.fill" : "bookmark").frame(width: 32, height: 32) }
                            .help(store.savedIDs.contains(item.id) ? "Unsave reference" : "Save reference")
                        Button(action: openReference) { Image(systemName: "square.stack.3d.up").frame(width: 32, height: 32) }.help("Break down reference")
                    }.buttonStyle(.plain).foregroundStyle(feedInk).background(.white.opacity(0.96), in: Capsule())
                        .padding(.trailing, 10).transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(hovering ? 0.12 : 0), radius: 12, y: 7)
            .offset(y: hovering && visual && !reduceMotion ? -3 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
            .onHover { hovering = interactive && $0 }.contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture(perform: openReference)
            .accessibilityElement(children: .contain).accessibilityLabel(item.title)
            .accessibilityAddTraits(.isButton).accessibilityAction { openReference() }
    }

    private func openReference() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.23)) { store.selectedReference = item }
    }
}

private struct FeedCardAspect: ViewModifier {
    let visual: Bool
    let video: Bool
    func body(content: Content) -> some View {
        if visual {
            Rectangle().fill(.clear).aspectRatio(video ? 9.0 / 16.0 : 4.0 / 5.0, contentMode: .fit)
                .overlay { content.frame(maxWidth: .infinity, maxHeight: .infinity).clipped() }
        } else {
            content
        }
    }
}

struct ConversationFeedCard: View {
    @Bindable var store: WorkspaceStore
    let item: ReferenceItem
    var compact = false
    var selected = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PlatformBadge(platform: item.platform, size: 21)
                Text(item.platform.rawValue).font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                if item.retrievedFromResearch == true {
                    Text(item.createdAt, format: .dateTime.month(.abbreviated).day())
                        .font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Button { store.toggleSaved(item) } label: { Image(systemName: store.savedIDs.contains(item.id) ? "bookmark.fill" : "bookmark") }
                    .buttonStyle(.plain).help("Save conversation")
            }
            Text(item.title).font(AppFont.ui(compact ? 14 : 15, weight: .semibold)).lineSpacing(3).lineLimit(compact ? 2 : 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !compact { Text(item.excerpt).font(AppFont.ui(13)).foregroundStyle(Palette.secondary).lineSpacing(4).lineLimit(4) }
            Text(item.conversationStatus == "lead" ? "Marked as lead" : item.conversationSignalType == "question" ? "Niche question" : item.conversationSignalType == "request" ? "Asking for help" : item.conversationSignalType == "problem" ? "Workflow problem" : "Relevant discussion")
                .font(AppFont.ui(11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 5).background(feedChip, in: Capsule())
            HStack {
                Text(item.author).font(AppFont.ui(11, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
                Spacer(minLength: 2)
                FeedMetrics(item: item).foregroundStyle(Palette.secondary)
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color(hex: 0xEAE5D8) : conversationPaper.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Color(hex: 0xB9B2A4) : Palette.border.opacity(0.7)))
    }
}

private struct HomeResearchSections: View {
    @Bindable var store: WorkspaceStore
    let sections: [(String, [ReferenceItem])]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func populatedSections(store: WorkspaceStore, references: [ReferenceItem]) -> [(String, [ReferenceItem])] {
        [
            ("Conversations", references.filter { $0.category == "Conversation" && $0.conversationStatus != "dismissed" }),
            ("Competitors", references.filter { $0.isCompetitor && $0.category != "Conversation" && canShowInResearchFeed($0) }),
            ("Recently saved", references.filter { store.savedIDs.contains($0.id) })
        ].filter { !$0.1.isEmpty }
    }

    var body: some View {
        ForEach(sections, id: \.0) { name, items in
            VStack(alignment: .leading, spacing: 12) {
                ResearchBandHeader(title: name, subtitle: subtitle(name))
                shelf(items, count: 5)
                if items.count > 5 {
                    Button { openLane(name) } label: { ResearchSeeAllLabel(section: name) }.buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func shelf(_ items: [ReferenceItem], count: Int) -> some View {
        let first = Array(items.prefix(count))
        let more = Array(items.dropFirst(count).prefix(count))
        let short = first.indices.filter { !isMedia(first[$0]) }
        let tall = first.indices.filter { isMedia(first[$0]) }
        let columns = short + tall
        return HStack(alignment: .top, spacing: 16) {
            ForEach(Array(first.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 10) {
                    card(item, interactive: true)
                    if let slot = columns.firstIndex(of: index), more.indices.contains(slot) {
                        card(more[slot], interactive: false)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(height: isMedia(more[slot]) ? 94 : 62, alignment: .top)
                            .blur(radius: 4)
                            .mask {
                                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                            }
                            .clipped().allowsHitTesting(false).accessibilityHidden(true)
                    }
                }.frame(maxWidth: .infinity)
            }
            ForEach(first.count..<count, id: \.self) { _ in
                Color.clear.frame(height: 0).frame(maxWidth: .infinity)
            }
        }
    }

    private func isMedia(_ item: ReferenceItem) -> Bool {
        item.category == "Video" || item.category == "Image"
    }

    @ViewBuilder private func card(_ item: ReferenceItem, interactive: Bool) -> some View {
        if item.category == "Conversation" {
            ConversationFeedCard(store: store, item: item).onTapGesture {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.23)) {
                    store.navigate(.conversations)
                    store.focusedConversationID = item.id
                }
            }
        } else {
            ResearchFeedTile(store: store, item: item, interactive: interactive)
        }
    }
    private func openLane(_ name: String) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.23)) {
            switch name {
            case "Conversations": store.navigate(.conversations)
            case "Recently saved": store.navigate(.saved)
            default:
                store.discoveryLane = name == "Competitors" ? "Competitors" : "For You"
                store.navigate(.discover)
            }
        }
    }
    private func subtitle(_ name: String) -> String {
        switch name {
        case "Conversations": "People talking about the problems you solve"
        case "Competitors": "References from products in your space"
        case "Recently saved": "Your reference shelf"
        default: "Ideas and creative references from your niche"
        }
    }
}

private struct ResearchSeeAllLabel: View {
    let section: String

    var body: some View {
        Label("See all", systemImage: "chevron.right")
            .font(AppFont.ui(13, weight: .semibold))
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(feedChip, in: Capsule())
            .accessibilityLabel("See all \(section)")
    }
}

struct ResearchDiscoverView: View {
    @Bindable var store: WorkspaceStore
    private var isHome: Bool { store.area == .home }
    private var lane: String { isHome ? "For You" : store.discoveryLane }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var platform = "All platforms"
    @State private var sort = "Research order"
    private var items: [ReferenceItem] {
        let values = store.projectReferences.filter {
            $0.category != "Conversation" && $0.isCompetitor == (self.lane == "Competitors")
                && (self.lane == "Competitors" || $0.platform == .instagram || $0.platform == .tiktok)
                && (isHome || platform == "All platforms" || $0.platform.rawValue == platform)
                && (!isHome || matchesResearchTopic($0, store.researchTopic))
                && canShowInResearchFeed($0)
        }
        if isHome { return values }
        switch sort {
        case "Measured views": return values.sorted { ($0.measuredViews ?? -1) > ($1.measuredViews ?? -1) }
        case "Measured engagement": return values.sorted { engagement($0) > engagement($1) }
        case "Newest posts": return values.sorted { $0.createdAt > $1.createdAt }
        default: return values
        }
    }
    private func engagement(_ item: ReferenceItem) -> Int {
        guard item.measuredLikes != nil || item.measuredComments != nil else { return -1 }
        return (item.measuredLikes ?? 0) + (item.measuredComments ?? 0)
    }

    private var headingTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity.animation(.easeIn(duration: 0.18).delay(0.13)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }

    var body: some View {
        let visibleItems = items
        let homeSections = isHome ? HomeResearchSections.populatedSections(
            store: store, references: store.projectReferences.filter { matchesResearchTopic($0, store.researchTopic) }
        ) : []
        GeometryReader { geometry in
            let columns = geometry.size.width > 1040 ? 5 : 4
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isHome {
                        VStack(alignment: .leading, spacing: 20) {
                            ResearchTopicBar(store: store).padding(.horizontal, -28)
                            if !visibleItems.isEmpty {
                                ResearchBandHeader(title: "For You", subtitle: "Ideas and creative references from your niche")
                            }
                        }.transition(headingTransition)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            PageHeading(title: "Discover", subtitle: "Short-form content getting attention in your niche") {
                                Button { store.showFollowingForm = true } label: { Label("Add source", systemImage: "plus") }.buttonStyle(AppButtonStyle(primary: true))
                            }.padding(.horizontal, -22).padding(.bottom, -20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    HStack(spacing: 3) {
                                        ForEach(["For You", "Competitors"], id: \.self) { lane in
                                            Button {
                                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
                                                    store.discoveryLane = lane
                                                    platform = "All platforms"
                                                }
                                            } label: {
                                                Text(lane).font(AppFont.ui(13, weight: .medium)).foregroundStyle(self.lane == lane ? feedInk : Palette.secondary)
                                                    .padding(.horizontal, 15).frame(height: 31)
                                                    .background(self.lane == lane ? Palette.surface : .clear, in: RoundedRectangle(cornerRadius: 8))
                                                    .shadow(color: .black.opacity(self.lane == lane ? 0.04 : 0), radius: 2, y: 1)
                                            }.buttonStyle(.plain)
                                        }
                                    }.padding(3).background(feedChip, in: RoundedRectangle(cornerRadius: 11))
                                    Divider().frame(height: 22).padding(.horizontal, 7)
                                    ForEach(["All platforms"] + (self.lane == "Competitors" ? [Platform.instagram, .tiktok, .x, .reddit] : [Platform.instagram, .tiktok]).map(\.rawValue), id: \.self) { value in
                                        Button { platform = value } label: {
                                            HStack(spacing: 7) {
                                                if let service = Platform(rawValue: value) { PlatformBadge(platform: service, size: 19) }
                                                Text(value).font(AppFont.ui(13, weight: .medium))
                                            }.padding(.horizontal, 12).frame(height: 35)
                                                .foregroundStyle(platform == value ? Palette.surface : feedInk)
                                                .background(platform == value ? feedInk : Palette.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
                                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(platform == value ? .clear : Palette.border.opacity(0.8)))
                                        }.buttonStyle(.plain).fixedSize()
                                    }
                                    FilterMenu(title: "Sort: " + sort, options: ["Research order", "Measured views", "Measured engagement", "Newest posts"]) { sort = $0 }
                                }
                            }
                        }.transition(headingTransition)
                    }
                    NativeResearchStatus(store: store).padding(.horizontal, -28)
                    Group {
                        if visibleItems.isEmpty && store.isResearching {
                            ResearchSkeletonGrid(columns: geometry.size.width > 1040 ? 5 : 4, count: 8)
                        } else if visibleItems.isEmpty {
                            if !isHome || homeSections.isEmpty {
                                let filtered = !isHome && platform != "All platforms"
                                ResearchEmpty(message: filtered ? "No references match these filters"
                                    : self.lane == "Competitors" ? "No competitor posts yet" : "No references yet")
                                    .frame(minHeight: max(0, geometry.size.height - 190))
                            }
                        } else {
                            if self.lane == "Competitors" && visibleItems.contains(where: { $0.platform == .reddit || $0.platform == .x }) {
                                let buckets = stride(from: 0, to: columns, by: 1).map { column in
                                    stride(from: column, to: visibleItems.count, by: columns).map { visibleItems[$0] }
                                }
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(buckets.indices, id: \.self) { index in
                                        VStack(spacing: 16) {
                                            ForEach(buckets[index]) { ResearchFeedTile(store: store, item: $0) }
                                        }.frame(maxWidth: .infinity)
                                    }
                                }
                            } else {
                                let shown = isHome ? Array(visibleItems.prefix(columns * 2)) : visibleItems
                                let width = max(1, (geometry.size.width - 56 - CGFloat(columns - 1) * 16) / CGFloat(columns))
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(0..<((shown.count + columns - 1) / columns), id: \.self) { row in
                                        HStack(alignment: .top, spacing: 16) {
                                            ForEach(shown.dropFirst(row * columns).prefix(columns)) { item in
                                                let teaser = isHome && row > 0
                                                ResearchFeedTile(store: store, item: item, interactive: !teaser)
                                                    .frame(width: width)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .frame(height: teaser ? 84 : nil, alignment: .top)
                                                    .blur(radius: teaser ? 4 : 0)
                                                    .overlay {
                                                        if teaser {
                                                            LinearGradient(colors: [.clear, conversationPaper],
                                                                           startPoint: .top, endPoint: .bottom)
                                                        }
                                                    }
                                                    .clipped()
                                                    .allowsHitTesting(!teaser)
                                                    .accessibilityHidden(teaser)
                                                    .transition(reduceMotion ? .identity : .opacity)
                                            }
                                        }
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .id(lane)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 6)))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: visibleItems.isEmpty)
                    if isHome && visibleItems.count > columns {
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                                sort = "Research order"
                                platform = "All platforms"
                                store.discoveryLane = "For You"
                                store.navigate(.discover)
                            }
                        } label: { ResearchSeeAllLabel(section: "For You") }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
                    if isHome {
                        HomeResearchSections(store: store, sections: homeSections).transition(.opacity)
                    }
                }.padding(.horizontal, 28).padding(.bottom, 30)
            }
        }
    }
}

struct ConversationsView: View {
    @Bindable var store: WorkspaceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var platform = "All platforms"
    @State private var status = "All"
    @State private var pastWeek = false
    private var items: [ReferenceItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return store.projectReferences.filter {
            (!pastWeek || $0.createdAt >= cutoff) && $0.category == "Conversation" && !$0.isCompetitor && matchesResearchTopic($0, store.researchTopic)
                && (platform == "All platforms" || $0.platform.rawValue == platform)
                && ((status == "All" && $0.conversationStatus != "dismissed") || (status == "New" && ($0.conversationStatus ?? "new") == "new") || (status == "Leads" && $0.conversationStatus == "lead"))
        }.sorted { $0.createdAt > $1.createdAt }
    }
    var body: some View {
        let visibleItems = items
        let selected = visibleItems.first(where: { $0.id == store.focusedConversationID }) ?? visibleItems.first
        VStack(spacing: 0) {
            PageHeading(title: "Conversations", subtitle: "People talking about the problems you solve") {
                EmptyView()
            }
            ResearchTopicBar(store: store, platform: $platform, status: $status, pastWeek: $pastWeek).padding(.bottom, 8)
            NativeResearchStatus(store: store)
            if visibleItems.isEmpty && store.isResearching {
                NativeResearchSkeleton(conversations: true)
            } else if visibleItems.isEmpty {
                let filtered = platform != "All platforms" || !store.researchTopic.isEmpty || status != "All"
                ResearchEmpty(message: pastWeek ? "No conversations from the past week"
                    : filtered ? "No conversations match these filters" : "No conversations yet")
                    .padding(.horizontal, 28)
                    .frame(maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(visibleItems) { item in
                                ConversationFeedCard(store: store, item: item, compact: true, selected: selected?.id == item.id)
                                    .contentShape(RoundedRectangle(cornerRadius: 14)).onTapGesture {
                                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                            store.focusedConversationID = item.id
                                        }
                                    }
                            }
                        }.padding(2)
                    }.frame(width: 340)
                    ZStack {
                    if let selected {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(spacing: 9) {
                                    PlatformBadge(platform: selected.platform, size: 27)
                                    Text(selected.author).font(AppFont.ui(13, weight: .medium))
                                    Spacer()
                                    Button { store.toggleSaved(selected) } label: { Label(store.savedIDs.contains(selected.id) ? "Saved" : "Save", systemImage: "bookmark") }.buttonStyle(AppButtonStyle())
                                    if let url = ResearchSource.publicURL(selected.sourceURL) { Link(destination: url) { Label("Open original", systemImage: "arrow.up.right") }.buttonStyle(AppButtonStyle()) }
                                }
                                Text(selected.title).font(AppFont.ui(23, weight: .semibold)).tracking(-0.4)
                                Text(selected.excerpt).font(AppFont.ui(14)).lineSpacing(6)
                                FeedMetrics(item: selected).foregroundStyle(Palette.secondary)
                                VStack(alignment: .leading, spacing: 7) {
                                    Label(selected.conversationSignalType == "question" ? "Why this is relevant" : "Fit with your product", systemImage: "checkmark.circle.fill").font(AppFont.ui(13, weight: .semibold))
                                    Text(selected.approach).font(AppFont.ui(13)).lineSpacing(5)
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(feedChip, in: RoundedRectangle(cornerRadius: 12))
                                Text("Read the full thread and replies on the original platform.").font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                                HStack(spacing: 12) {
                                    Button(selected.conversationStatus == "lead" ? "Remove lead" : "Mark as lead") {
                                        let marking = selected.conversationStatus != "lead"
                                        store.setConversationStatus(selected, status: marking ? "lead" : "new")
                                        store.focusedConversationID = selected.id
                                        if marking && status == "New" { status = "Leads" }
                                        if !marking && status == "Leads" { status = "All" }
                                    }.buttonStyle(AppButtonStyle(primary: true))
                                    Button("Not relevant") { store.setConversationStatus(selected, status: "dismissed") }.buttonStyle(AppButtonStyle())
                                    Button("Studio · Coming soon") { store.navigate(.studio) }.buttonStyle(.plain).font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                                }
                            }.padding(23).frame(maxWidth: .infinity, alignment: .leading)
                        }.background(LinearGradient(colors: [Color(hex: 0xF5F2E9), Color(hex: 0xEFEADD)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.border.opacity(0.65)))
                            .id(selected.id)
                            .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(x: 8)))
                    }
                    }
                }.padding(.horizontal, 28).padding(.bottom, 22)
            }
        }.onChange(of: store.selectedProjectID) { _, _ in store.focusedConversationID = nil }
    }
}
