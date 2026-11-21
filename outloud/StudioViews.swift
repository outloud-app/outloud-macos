import SwiftUI

struct FollowingView: View {
    @Bindable var store: WorkspaceStore
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Research").font(AppFont.ui(11)).foregroundStyle(Palette.muted)
                Text("Following").font(AppFont.ui(29, weight: .bold)).tracking(-0.8)
                Text("Build a watchlist of competitors, creators, and topics.")
                    .font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
            }.padding(.top, 30)
            if store.projectTargets.isEmpty {
                EmptyWorkspaceView(symbol: "dot.radiowaves.left.and.right", title: "Who is worth paying attention to?",
                    message: "Follow accounts and topics to guide research for this project.",
                    actionTitle: "Add your first topic") { store.showFollowingForm = true }
            } else {
                Text("RESEARCH SOURCES")
                    .font(AppFont.ui(10, weight: .medium)).foregroundStyle(Palette.muted)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.projectTargets) { target in
                            VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 13) {
                                SourceAvatar(target: target, size: 30)
                                Text(target.displayName).font(AppFont.ui(13, weight: .medium))
                                Spacer()
                                Text(target.platform.rawValue).font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
                                IconButton(symbol: "minus.circle", label: "Remove from watchlist") { store.removeTarget(target.id) }
                            }
                            let matches = store.references(for: target)
                            if matches.isEmpty {
                                Text(store.isResearching ? "Looking for relevant posts…" : "No matching posts in this project's research yet.")
                                    .font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                            } else {
                                ForEach(matches) { item in
                                    Button { store.selectedReference = item } label: {
                                        HStack(spacing: 9) {
                                            Image(systemName: item.category == "Video" ? "play.rectangle" : "text.bubble")
                                            Text(item.title).lineLimit(2)
                                            Spacer()
                                            Image(systemName: "arrow.up.right").font(.system(size: 10))
                                        }.font(AppFont.ui(12)).foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                                    }.buttonStyle(.plain)
                                }
                            }
                            }.padding(15).background(store.focusedTargetID == target.id ? Palette.selected : Palette.elevated, in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }
            }
        }.padding(.horizontal, 30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
