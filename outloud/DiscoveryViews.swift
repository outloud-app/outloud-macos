import SwiftUI
import ImageIO

@MainActor
private final class ReferenceThumbnailCache {
    static let shared = ReferenceThumbnailCache()
    private let images = NSCache<NSString, NSImage>()
    private var pending: [String: Task<NSImage?, Never>] = [:]
    private var failedAt: [String: Date] = [:]

    private init() { images.countLimit = 180 }

    func cached(_ key: String) -> NSImage? { images.object(forKey: key as NSString) }

    func load(_ reference: ReferenceItem, key: String) async -> NSImage? {
        if let image = cached(key) { return image }
        if let task = pending[key] { return await task.value }
        if let failure = failedAt[key], Date().timeIntervalSince(failure) < 180 {
            return nil
        }
        let task = Task<NSImage?, Never> {
            if let image = await download(reference.thumbnailURL) { return image }
            guard let original = reference.sourceURL,
                  let client = try? ResearchClient(),
                  let refreshed = try? await client.preview(original, includeVideo: reference.platform == .instagram) else {
                return nil
            }
            if refreshed.unavailable == true { return nil }
            guard refreshed.thumbnail != reference.thumbnailURL else { return nil }
            return await download(refreshed.thumbnail)
        }
        pending[key] = task
        let result = await task.value
        pending[key] = nil
        if let image = result {
            images.setObject(image, forKey: key as NSString)
            failedAt[key] = nil
        } else {
            if failedAt.count >= 500 { failedAt.removeAll() }
            failedAt[key] = Date()
        }
        return result
    }

    private func download(_ raw: String?) async -> NSImage? {
        guard let url = ResearchSource.publicURL(raw) else { return nil }
        if let expiration = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "x-expires" })?.value.flatMap(Double.init),
           expiration <= Date().timeIntervalSince1970 {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.hasPrefix("image/") == true, data.count <= 12_000_000 else { return nil }
        let thumbnail = await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil as CGImage? }
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: 900
            ] as CFDictionary
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        }.value
        return thumbnail.map { NSImage(cgImage: $0, size: .zero) }
    }
}

/// Editorial example artwork built from native shapes; never presented as fetched media.
struct ReferenceArtwork: View {
    let reference: ReferenceItem
    var fillsFrame = false
    var loadsWhenVisible = false
    @State private var image: NSImage?
    @State private var finished = false
    @State private var inViewport = false
    @State private var requested = false
    private var key: String { reference.sourceURL ?? reference.thumbnailURL ?? reference.id }
    private var ink: Color { Color(hex: 0x18271E) }
    var body: some View {
        if reference.isExample {
            exampleArtwork
        } else if loadsWhenVisible, #available(macOS 15.0, *) {
            artwork.onScrollVisibilityChange(threshold: 0.01) { visible in
                inViewport = visible
                if visible { requested = true }
            }
        } else {
            artwork.onAppear {
                inViewport = true
                requested = true
            }.onDisappear { inViewport = false }
        }
    }

    private var artwork: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.elevated
                if let image = image ?? ReferenceThumbnailCache.shared.cached(key) {
                    Image(nsImage: image).resizable()
                        .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if finished {
                    originalLinkPlaceholder
                } else if inViewport {
                    Palette.elevated.modifier(ResearchShimmer())
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.task(id: requested ? key : nil) {
            guard requested else { return }
            image = ReferenceThumbnailCache.shared.cached(key)
            finished = image != nil
            let loaded = await ReferenceThumbnailCache.shared.load(reference, key: key)
            guard !Task.isCancelled else { return }
            image = loaded
            finished = true
        }
    }
    private var originalLinkPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: reference.category == "Video" ? "play.rectangle" : "link").font(.system(size: 26, weight: .light))
            Text(reference.category == "Video" ? "Preview unavailable" : "No preview").font(AppFont.ui(12))
        }.foregroundStyle(Palette.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var exampleArtwork: some View {
        GeometryReader { geometry in
            ZStack {
                switch reference.artwork {
                case 0:
                    Color(hex: 0xBCF2D7)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Missed a day?\nYou're still\nmoving forward.")
                            .font(.system(size: 25, weight: .bold)).tracking(-0.9).lineSpacing(-1)
                        HStack(spacing: 6) {
                            ForEach(0..<7) { day in
                                Image(systemName: day == 3 ? "minus" : "checkmark").font(.system(size: 10, weight: .bold))
                                    .frame(maxWidth: .infinity).frame(height: 25)
                                    .background(.white.opacity(day == 3 ? 0.3 : 0.75), in: Circle())
                            }
                        }
                    }.foregroundStyle(ink).padding(22).padding(.top, 24)
                case 1:
                    Color(hex: 0xDAD0BD)
                    Circle().fill(Color(hex: 0xC7BAA4)).frame(width: 200, height: 200).offset(x: 85, y: 50)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("LESS PRESSURE.\nMORE PROGRESS.")
                            .font(.system(size: 24, weight: .black)).tracking(-0.7)
                        HStack {
                            Image(systemName: "play.fill").font(.system(size: 15)).padding(13)
                                .background(ink, in: Circle()).foregroundStyle(.white)
                            Text("A different kind\nof habit story.").font(.system(size: 11, weight: .medium))
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ink).padding(23).padding(.top, 20)
                case 2:
                    Color(hex: 0xE9E6DE)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: 0xD36F45)).frame(width: 18, height: 18)
                            Text("A QUESTION WORTH ASKING").font(.system(size: 8, weight: .bold)).tracking(0.7)
                        }
                        Text("“Why does one\nmissed day feel\nlike starting over?”")
                            .font(.system(size: 23, weight: .semibold, design: .serif)).tracking(-0.7)
                        Text("Listen before you create.").font(.system(size: 10)).foregroundStyle(ink.opacity(0.7))
                    }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ink).padding(23).padding(.top, 18)
                case 3:
                    Color(hex: 0x263D31)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("A SMALL\nPRODUCT\nOPINION.").font(.system(size: 29, weight: .heavy)).tracking(-0.8)
                        Text("Your app should be on your side.").font(.system(size: 11))
                    }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Color(hex: 0xD3EADB))
                        .padding(24).padding(.top, 16)
                case 4:
                    Color(hex: 0xD8CEF0)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("small\nis a start.").font(.system(size: 39, weight: .medium, design: .serif)).tracking(-2)
                        Rectangle().fill(ink).frame(width: 35, height: 2)
                        Text("A little counts. Every time.").font(.system(size: 11))
                    }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ink).padding(24).padding(.top, 15)
                case 5:
                    Color(hex: 0xE3B99E)
                    VStack(alignment: .leading, spacing: 13) {
                        Text("ONE TINY\nCHANGE.").font(.system(size: 30, weight: .black)).tracking(-1)
                        HStack(spacing: 9) {
                            Image(systemName: "sun.max").font(.system(size: 28, weight: .light))
                            Text("A morning you\ncan actually repeat.").font(.system(size: 12, weight: .medium))
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(ink).padding(24).padding(.top, 20)
                default:
                    Palette.elevated
                    VStack(spacing: 14) {
                        Image(systemName: "link").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.mint)
                        Text(reference.title).font(.system(size: 18, weight: .medium))
                            .multilineTextAlignment(.center).lineLimit(3).foregroundStyle(Palette.text)
                    }.padding(30)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityLabel(reference.title)
    }
}

