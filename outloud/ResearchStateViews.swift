import SwiftUI
import AVKit

struct NativeResearchStatus: View {
    @Bindable var store: WorkspaceStore
    var body: some View {
        if let id = store.selectedProjectID, let error = store.researchErrors[id] {
            HStack(spacing: 12) {
                Image(systemName: store.researchNeedsDetails.contains(id) ? "text.badge.plus" : "wifi.exclamationmark").foregroundStyle(Palette.secondary)
                Text(error).font(AppFont.ui(12)).foregroundStyle(Palette.secondary).lineLimit(3)
                Spacer()
                if store.researchNeedsDetails.contains(id) {
                    Button("Update product details") { store.showProjectBrief = true }.buttonStyle(AppButtonStyle())
                } else {
                    Button("Try again") { store.refreshResearch() }.buttonStyle(AppButtonStyle())
                }
            }.padding(15).background(Palette.surface).padding(.horizontal,22).padding(.bottom,12)
        } else if let message = coverageMessage {
            Text(message)
                .font(AppFont.ui(12))
                .foregroundStyle(Palette.secondary)
                .lineLimit(1)
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
        }
    }

    private var coverageMessage: String? {
        guard let id = store.selectedProjectID,
              let results = store.researchCoverage[id],
              let report = results.quality_report,
              let counts = report.lane_counts else { return nil }
        let lanes: [(key: String, label: String)]
        if store.area == .home {
            lanes = [("discover", "For You"), ("competitors", "Competitors"), ("conversations", "Conversations")]
        } else if store.area == .workspace {
            switch store.page {
            case .discover:
                lanes = store.discoveryLane == "Competitors" ? [("competitors", "Competitors")] : [("discover", "For You")]
            case .conversations:
                lanes = [("conversations", "Conversations")]
            default:
                return nil
            }
        } else {
            return nil
        }
        let shortfalls = lanes.flatMap { lane -> [String] in
            if lane.key == "conversations", let platforms = report.conversation_platform_counts {
                let minimum = (report.release_minimum?["conversations"] ?? 30) / 2
                return ["X", "Reddit"].compactMap { platform in
                    guard let count = platforms[platform], count < minimum else { return nil }
                    return "\(platform) \(count) of \(minimum)"
                }
            }
            let minimum = report.release_minimum?[lane.key] ?? 15
            guard let count = counts[lane.key], count < minimum else { return [] }
            return ["\(lane.label) \(count) of \(minimum)"]
        }
        guard !shortfalls.isEmpty else { return nil }
        let issues = (results.research_issues ?? []) + (report.blockers ?? [])
        let paused = issues.contains { $0.localizedCaseInsensitiveContains("fresh collection is paused")
            || $0.localizedCaseInsensitiveContains("monthly account allowance") }
        return shortfalls.joined(separator: " · ") + (paused ? ". Fresh collection is paused." : ".")

    }
}

/// One gentle sweep over the placeholder shapes. No opacity pulsing or timers
/// survive once loading ends; Reduce Motion keeps the placeholders static.
struct ResearchShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionReduced: Bool {
        #if DEBUG
        return reduceMotion || ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_REDUCE_MOTION"] == "1"
        #else
        return reduceMotion
        #endif
    }
    func body(content: Content) -> some View {
        content.overlay {
            if !motionReduced {
                GeometryReader { geometry in
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                        let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.1) / 2.1
                        LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geometry.size.width * 0.65, height: geometry.size.height * 2)
                            .rotationEffect(.degrees(12))
                            .offset(x: geometry.size.width * (phase * 2.2 - 0.8), y: -geometry.size.height / 2)
                    }
                }.mask(content).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

struct ResearchSkeletonTile: View {
    var conversations = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if conversations {
                HStack(spacing: 9) {
                    Circle().fill(Palette.elevated).frame(width: 25, height: 25)
                    Capsule().fill(Palette.elevated).frame(width: 110, height: 10)
                }
            } else {
                RoundedRectangle(cornerRadius: 10).fill(Palette.elevated).aspectRatio(1.15, contentMode: .fit)
            }
            RoundedRectangle(cornerRadius: 4).fill(Palette.elevated).frame(height: 12)
            RoundedRectangle(cornerRadius: 4).fill(Palette.elevated).frame(maxWidth: conversations ? 360 : 140).frame(height: 12)
            if conversations { Capsule().fill(Palette.elevated).frame(width: 95, height: 9).padding(.top, 5) }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.border.opacity(0.4)))
            .accessibilityHidden(true)
    }
}

struct ResearchSkeletonGrid: View {
    var conversations = false
    var columns = 4
    var count = 6
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
            ForEach(0..<count, id: \.self) { _ in ResearchSkeletonTile(conversations: conversations) }
        }.modifier(ResearchShimmer())
            .accessibilityElement(children: .ignore).accessibilityLabel(conversations ? "Loading conversations" : "Loading project references")
    }
}

struct NativeResearchSkeleton: View {
    var conversations = false
    var body: some View {
        ScrollView {
            ResearchSkeletonGrid(conversations: conversations, columns: conversations ? 1 : 4, count: conversations ? 3 : 8)
                .padding(.horizontal, 28).padding(.vertical, 12)
        }
    }
}

private struct ReferencePlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player?.pause()
        view.player = nil
    }
}

struct NativeReferenceMedia: View {
    let reference: ReferenceItem
    @State private var player: AVPlayer?
    @State private var embedFailed = false
    @State private var checkingPlayback = false
    @State private var startedPlayback = false

    var body: some View {
        Group {
            if let player {
                if startedPlayback {
                    ReferencePlayerView(player: player)
                } else {
                    ReferenceArtwork(reference: reference)
                        .overlay {
                            Button {
                                startedPlayback = true
                                player.play()
                            } label: {
                                Image(systemName: "play.fill").font(.system(size: 23, weight: .semibold))
                                    .foregroundStyle(.white).frame(width: 62, height: 62)
                                    .background(.black.opacity(0.65), in: Circle())
                            }.buttonStyle(.plain).accessibilityLabel("Play video")
                        }
                }
            } else if checkingPlayback || reference.category != "Video" || reference.isExample {
                ReferenceArtwork(reference: reference)
            } else if !embedFailed, reference.platform == .tiktok,
                      let url = PlatformMediaEmbed.tiktokURL(reference.sourceURL, controls: true) {
                PlatformMediaEmbed(url: url) { embedFailed = true }
            } else {
                ReferenceArtwork(reference: reference)
                    .overlay(alignment: .bottom) {
                        if let original = ResearchSource.publicURL(reference.sourceURL) {
                            Link(destination: original) {
                                Label("Watch on \(reference.platform.rawValue)", systemImage: "arrow.up.right")
                            }.buttonStyle(AppButtonStyle()).padding(14)
                        }
                    }
            }
        }.task(id: reference.id) {
            player = nil
            embedFailed = false
            startedPlayback = false
            guard reference.category == "Video", !reference.isExample else { return }
            checkingPlayback = true
            defer { checkingPlayback = false }
            let initial = ResearchSource.publicURL(reference.videoURL)
            var candidate: AVPlayer?
            if let initial {
                candidate = await readyPlayer(initial)
            }
            if candidate == nil, !Task.isCancelled, reference.platform == .instagram,
               let original = reference.sourceURL, let client = try? ResearchClient(),
               let refreshed = try? await client.preview(original, includeVideo: true),
               let url = ResearchSource.publicURL(refreshed.video), url != initial {
                candidate = await readyPlayer(url)
            }
            guard let candidate, !Task.isCancelled else { return }
            player = candidate
            checkingPlayback = false
            for await _ in NotificationCenter.default.notifications(named: .AVPlayerItemFailedToPlayToEndTime, object: candidate.currentItem) {
                if !Task.isCancelled { player = nil }
                return
            }
        }.onDisappear { player?.pause(); player = nil }
    }
    private func readyPlayer(_ url: URL) async -> AVPlayer? {
        let candidate = AVPlayer(url: url)
        for _ in 0..<24 {
            if Task.isCancelled || candidate.currentItem?.status == .failed { return nil }
            if candidate.currentItem?.status == .readyToPlay { return candidate }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return nil
    }

}

struct ReferenceMetrics: View {
    let reference: ReferenceItem
    var body: some View {
        HStack(spacing: 12) {
            if let views = reference.measuredViews { Text("\(views.formatted()) views") }
            if let likes = reference.measuredLikes { Text("\(likes.formatted()) likes") }
            if let comments = reference.measuredComments { Text("\(comments.formatted()) comments") }
        }.font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
    }
}
