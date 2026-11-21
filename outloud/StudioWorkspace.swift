import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct StudioView: View {
    @Bindable var store: WorkspaceStore
    @State private var filter = "All drafts"
    @State private var deleting: UUID?
    private var drafts: [StudioDraft] {
        store.projectDrafts.filter {
            filter == "All drafts" || (filter == "Images" && $0.format == .image)
                || (filter == "Videos" && $0.format == .video)
                || (filter == "X posts" && $0.format == .xPost)
                || (filter == "Reddit" && $0.format == .reddit)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            PageHeading(title: "Studio", subtitle: "Turn your research into something worth sharing.") {
                Button { store.showDraftForm = true } label: { Label("Create", systemImage: "plus") }
                    .buttonStyle(AppButtonStyle(primary: true))
            }
            UnderlineTabs(tabs: ["All drafts", "Videos", "Images", "X posts", "Reddit"], selection: $filter)
            Rectangle().fill(Palette.border).frame(height: 1)
            if drafts.isEmpty {
                EmptyWorkspaceView(symbol: "square.and.pencil", title: "Create your first draft",
                    message: "Start with a blank page or adapt a reference from Discover.", actionTitle: "Create draft") {
                    store.showDraftForm = true
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], alignment: .leading, spacing: 24) {
                        ForEach(drafts) { draft in
                            VStack(alignment: .leading, spacing: 9) {
                                Button { store.editingDraftID = draft.id } label: {
                                    DraftCover(draft: draft, project: store.project, reference: store.references.first { $0.id == draft.referenceID })
                                        .aspectRatio(1, contentMode: .fit).clipped().clipShape(RoundedRectangle(cornerRadius: 7))
                                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.border))
                                }.buttonStyle(.plain)
                                HStack(alignment: .top) {
                                    Button { store.editingDraftID = draft.id } label: {
                                        Text(draft.title.isEmpty ? "Untitled draft" : draft.title).font(AppFont.ui(11, weight: .semibold))
                                            .lineLimit(2).multilineTextAlignment(.leading)
                                    }.buttonStyle(.plain)
                                    Spacer(minLength: 4)
                                    Menu {
                                        Button("Export text…") { store.exportDraft(draft) }
                                        Button("Delete draft…", role: .destructive) { deleting = draft.id }
                                    } label: { Image(systemName: "ellipsis").font(.system(size: 10)).foregroundStyle(Palette.secondary) }
                                        .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 17)
                                }
                                HStack(spacing: 5) {
                                    Image(systemName: draft.format.symbol)
                                    Text(draft.format == .video ? "Video brief" : draft.format.rawValue)
                                    Text("·")
                                    Circle().fill(Palette.muted).frame(width: 4, height: 4)
                                    Text("Draft")
                                }.font(AppFont.ui(9)).foregroundStyle(Palette.secondary)
                            }
                        }
                    }.padding(20)
                }
            }
            HStack {
                Image(systemName: "square.stack").font(.system(size: 15, weight: .light)).foregroundStyle(Palette.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Built from your research").font(AppFont.ui(11, weight: .semibold))
                    Text("Your drafts stay connected to the references that inspired them.").font(AppFont.ui(10)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Button { store.navigate(.saved) } label: { Label("View references", systemImage: "arrow.right") }
                    .buttonStyle(.plain).font(AppFont.ui(11)).foregroundStyle(Palette.mint)
            }.padding(17).background(Palette.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.border))
                .padding(.horizontal, 20).padding(.bottom, 18)
        }.confirmationDialog("Delete this draft?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete draft", role: .destructive) { if let id = deleting { store.deleteDraft(id) }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("This removes the draft from this Mac. It can't be undone.") }
    }
}

struct DraftCover: View {
    let draft: StudioDraft
    let project: Project?
    let reference: ReferenceItem?
    var body: some View {
        if draft.format == .image {
            GeometryReader { proxy in
                ImageDraftCanvas(headline: draft.body.isEmpty || draft.body.contains("[Describe") ? draft.title : draft.body,
                                 projectName: project?.name ?? "Your product", color: project?.brandColor.color ?? Palette.mint)
                    .frame(width: 1080, height: 1080)
                    .scaleEffect(proxy.size.width / 1080, anchor: .topLeading)
            }.background(project?.brandColor.color ?? Palette.mint)
        } else if draft.format == .video, let reference {
            ReferenceArtwork(reference: reference)
                .overlay {
                    Image(systemName: "play.fill").font(.system(size: 22))
                        .foregroundStyle(.white).frame(width: 54, height: 54).background(.black.opacity(0.45), in: Circle())
                }
                .overlay(alignment: .bottomLeading) {
                    Text("VIDEO BRIEF").font(AppFont.ui(8, weight: .semibold)).tracking(1)
                        .padding(7).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4)).padding(10)
                }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Text(String(project?.name.prefix(1) ?? "P")).font(AppFont.ui(12, weight: .semibold))
                        .foregroundStyle(Palette.background).frame(width: 28, height: 28)
                        .background(project?.brandColor.color ?? Palette.mint, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project?.name ?? "Your product").font(AppFont.ui(11, weight: .semibold))
                        Text(draft.format.rawValue).font(AppFont.ui(9)).foregroundStyle(Palette.muted)
                    }
                }
                Text(draft.body.isEmpty || draft.body.contains("[Describe") ? draft.title : draft.body)
                    .font(AppFont.ui(18, weight: .medium)).lineSpacing(4).lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                Label("Original draft", systemImage: draft.format.symbol).font(AppFont.ui(9)).foregroundStyle(Palette.muted)
            }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Palette.surface)
        }
    }
}

struct ImageDraftCanvas: View {
    let headline: String
    let projectName: String
    let color: Color
    @MainActor static func png(headline: String, projectName: String, color: Color) throws -> Data {
        let renderer = ImageRenderer(content: ImageDraftCanvas(headline: headline, projectName: projectName, color: color))
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
    var body: some View {
        VStack(spacing: 65) {
            Text(headline).font(AppFont.ui(92, weight: .bold)).tracking(-4)
                .multilineTextAlignment(.center).lineSpacing(-2).minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity).frame(height: 365)
            VStack(spacing: 30) {
                HStack {
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                        Text(day).font(AppFont.ui(24, weight: .medium)).frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 18) {
                    ForEach(0..<7) { day in
                        Circle().fill(day == 3 ? Color.clear : color).frame(height: 80)
                            .overlay(Circle().strokeBorder(day == 3 ? .gray.opacity(0.5) : .clear, style: StrokeStyle(lineWidth: 3, dash: [8])))
                            .overlay {
                                if day != 3 { Image(systemName: "checkmark").font(.system(size: 35, weight: .medium)) }
                            }
                    }
                }
            }.padding(35).background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 36))
            Spacer(minLength: 0)
            HStack {
                Text(String(projectName.prefix(1))).font(AppFont.ui(26, weight: .bold))
                    .frame(width: 45, height: 45).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black, lineWidth: 2))
                Text(projectName).font(AppFont.ui(31, weight: .bold))
                Spacer()
                Text("A little progress counts.").font(AppFont.ui(23))
            }
        }.padding(70).frame(width: 1080, height: 1080).foregroundStyle(.black).background(color)
    }
}

struct DraftEditor: View {
    @Bindable var store: WorkspaceStore
    let draftID: UUID
    @State private var title = ""
    @State private var content = ""
    @State private var tab = "Design"
    @State private var copied = false
    @State private var loaded = false
    private var draft: StudioDraft? { store.drafts.first { $0.id == draftID } }
    private var reference: ReferenceItem? { store.references.first { $0.id == draft?.referenceID } }
    private var isImage: Bool { draft?.format == .image }
    private var headline: String { content.isEmpty || content.contains("[Describe") ? title : content }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 11) {
                    Button { store.editingDraftID = nil } label: { Label("Back to Studio", systemImage: "arrow.left") }
                        .buttonStyle(.plain).font(AppFont.ui(10)).foregroundStyle(Palette.secondary)
                    TextField("Untitled draft", text: $title).textFieldStyle(.plain).font(AppFont.ui(23, weight: .semibold)).tracking(-0.5)
                    Text(isImage ? "Image · 1080 × 1080" : (draft?.format.rawValue ?? "Draft") + " · Manual editor")
                        .font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 20)
                Label(store.persistenceError == nil ? "Saved" : "Save failed", systemImage: store.persistenceError == nil ? "checkmark" : "exclamationmark.circle")
                    .font(AppFont.ui(11)).foregroundStyle(store.persistenceError == nil ? Palette.secondary : .orange)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    copied = true
                } label: { Label(copied ? "Copied" : "Copy", systemImage: "doc.on.doc") }.buttonStyle(AppButtonStyle())
                Button { export() } label: { Label(isImage ? "Export PNG" : "Export text", systemImage: "square.and.arrow.up") }
                    .buttonStyle(AppButtonStyle(primary: true))
            }.padding(22)
            UnderlineTabs(tabs: isImage ? ["Design", "Copy", "References"] : ["Copy", "References"],
                          selection: $tab)
            Rectangle().fill(Palette.border).frame(height: 1)
            HStack(spacing: 0) {
                if isImage && tab == "Design" {
                    layerPanel.frame(width: 145).padding(.leading, 16).padding(.vertical, 15)
                    GeometryReader { proxy in
                        let size = max(100, min(proxy.size.width - 45, proxy.size.height - 65))
                        VStack(spacing: 15) {
                            ImageDraftCanvas(headline: headline, projectName: store.project?.name ?? "Your product",
                                             color: store.project?.brandColor.color ?? Palette.mint)
                                .frame(width: 1080, height: 1080)
                                .scaleEffect(size / 1080)
                                .frame(width: size, height: size)
                                .clipped()
                            HStack {
                                Text("Fit to canvas").font(AppFont.ui(10))
                                Spacer()
                                Text("1080 × 1080").font(AppFont.ui(10))
                            }.foregroundStyle(Palette.secondary).frame(width: size)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.background {
                        Canvas { context, size in
                            for x in stride(from: CGFloat(14), to: size.width, by: 16) {
                                for y in stride(from: CGFloat(14), to: size.height, by: 16) {
                                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(Palette.border))
                                }
                            }
                        }
                    }
                } else if tab == "References" {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if let reference {
                                ReferenceArtwork(reference: reference).frame(height: 270).clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(reference.title).font(AppFont.ui(17, weight: .semibold))
                                Text(reference.excerpt).font(AppFont.ui(12)).foregroundStyle(Palette.secondary).lineSpacing(5)
                                Text(reference.isExample ? "Illustrative reference" : "Manually imported").font(AppFont.ui(10)).foregroundStyle(Palette.muted)
                            } else { Text("This draft started from a blank page.").font(AppFont.ui(13)).foregroundStyle(Palette.secondary) }
                        }.padding(25)
                    }.frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Your copy").font(AppFont.ui(12, weight: .medium)).foregroundStyle(Palette.secondary)
                        TextEditor(text: $content).font(AppFont.ui(15)).lineSpacing(6)
                            .scrollContentBackground(.hidden).background(Palette.background)
                        Text("\(content.count) characters · \(content.split(whereSeparator: \.isWhitespace).count) words")
                            .font(AppFont.ui(10)).foregroundStyle(Palette.muted)
                    }.padding(24).frame(maxWidth: .infinity)
                }
                Rectangle().fill(Palette.border).frame(width: 1)
                inspector.frame(width: 267)
            }
            HStack(spacing: 9) {
                Image(systemName: "square.on.square").foregroundStyle(Palette.secondary)
                Text(reference == nil ? "Original draft" : "Based on 1 reference").font(AppFont.ui(11))
                Spacer()
                Text("Manual editing · Saved on this Mac").font(AppFont.ui(10)).foregroundStyle(Palette.muted)
            }.padding(16).background(Palette.surface).overlay(alignment: .top) { Rectangle().fill(Palette.border).frame(height: 1) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background)
            .onAppear {
                title = draft?.title ?? ""
                content = draft?.body ?? ""
                tab = isImage ? "Design" : "Copy"
                loaded = true
            }
            .onChange(of: title) { _, _ in if loaded { save() } }
            .onChange(of: content) { _, _ in if loaded { copied = false; save() } }
            .onDisappear { if loaded { save() } }
    }

    private var layerPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Layers").font(AppFont.ui(12, weight: .semibold)).padding(.horizontal, 12).padding(.top, 16)
            ForEach([("textformat", "Headline"), ("calendar", "Weekly calendar"), ("square", "Brand"), ("rectangle.fill", "Background")], id: \.1) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.0).font(.system(size: 12)).frame(width: 17)
                    Text(item.1).font(AppFont.ui(10))
                    Spacer(minLength: 0)
                }.foregroundStyle(item.1 == "Headline" ? Palette.text : Palette.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 10)
                    .background(item.1 == "Headline" ? Palette.selected : .clear, in: RoundedRectangle(cornerRadius: 5))
                    .padding(.horizontal, 5)
            }
            Spacer()
            Text("Layout preview").font(AppFont.ui(9)).foregroundStyle(Palette.muted).padding(13)
        }.frame(maxHeight: .infinity).background(Palette.surface, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.border))
    }
    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 25) {
                    Text(isImage ? "Design" : "Draft").font(AppFont.ui(12, weight: .semibold))
                    Text("Brand").font(AppFont.ui(12)).foregroundStyle(Palette.secondary)
                }
                Rectangle().fill(Palette.border).frame(height: 1)
                if isImage {
                    FormInput(label: "Headline", placeholder: "Your headline", text: $content, multiline: true)
                    HStack {
                        Text("Typeface").font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
                        Spacer()
                        Text("Inter / Bold").font(AppFont.ui(11))
                    }
                    Divider().overlay(Palette.border)
                }
                Text("Project brand").font(AppFont.ui(12, weight: .semibold))
                Text(store.project?.name ?? "Your product").font(AppFont.ui(11)).foregroundStyle(Palette.secondary)
                BrandColorPicker(selection: Binding(get: { store.project?.brandColor ?? .mint }, set: { store.updateBrand($0) }))
                if let reference {
                    Divider().overlay(Palette.border)
                    Text("Reference").font(AppFont.ui(12, weight: .semibold))
                    Text(reference.title).font(AppFont.ui(11)).foregroundStyle(Palette.secondary).lineSpacing(4)
                }
                Divider().overlay(Palette.border)
                Text("Creation tools").font(AppFont.ui(12, weight: .semibold))
                Text("Manual editing is available. AI generation and video rendering aren't connected yet.")
                    .font(AppFont.ui(11)).foregroundStyle(Palette.muted).lineSpacing(4)
                if let error = store.persistenceError { Text(error).font(AppFont.ui(11)).foregroundStyle(.orange) }
            }.padding(19)
        }.background(Palette.surface.opacity(0.6))
    }
    private func save() { store.updateDraft(draftID, title: title, body: content) }
    private func export() {
        save()
        guard isImage else { if let draft { store.exportDraft(draft) }; return }
        let png: Data
        do {
            png = try ImageDraftCanvas.png(headline: headline, projectName: store.project?.name ?? "Your product",
                                           color: store.project?.brandColor.color ?? Palette.mint)
        } catch {
            store.persistenceError = "The image couldn't be rendered."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = (title.isEmpty ? "Outloud creative" : title).replacingOccurrences(of: "/", with: "-") + ".png"
        if panel.runModal() == .OK, let url = panel.url {
            do { try png.write(to: url, options: .atomic) }
            catch { store.persistenceError = "Export failed: \(error.localizedDescription)" }
        }
    }
}
