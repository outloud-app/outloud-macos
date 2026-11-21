import AppKit
import Foundation

@MainActor enum ProjectIconAsset {
    static func pngData(_ source: Data, requireSquare: Bool = false) throws -> Data {
        guard source.count <= 10_000_000 else { throw IconImportError.tooLarge }
        guard let image = NSImage(data: source), image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if requireSquare {
            let bitmap = NSBitmapImageRep(data: source)
            let width = bitmap.map { CGFloat($0.pixelsWide) } ?? image.size.width
            let height = bitmap.map { CGFloat($0.pixelsHigh) } ?? image.size.height
            guard width == height else { throw IconImportError.squareRequired }
        }
        let edge = 256
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: edge, pixelsHigh: edge, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw CocoaError(.fileReadCorruptFile) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let scale = min(CGFloat(edge) / image.size.width, CGFloat(edge) / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: (CGFloat(edge) - size.width)/2, y: (CGFloat(edge) - size.height)/2, width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileReadCorruptFile) }
        return data
    }
    static func download(_ value: String) async throws -> Data {
        guard let url = ResearchSource.publicURL(value), url.scheme == "https" else { throw URLError(.badURL) }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength <= 4_000_000 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 4_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        return try pngData(data)
    }
}

enum IconImportError: LocalizedError {
    case squareRequired, unsupportedFormat, tooLarge
    var errorDescription: String? {
        switch self {
        case .squareRequired: "Choose a square (1:1) app icon. The width and height must match."
        case .unsupportedFormat: "This format isn’t supported. Choose a PNG, JPEG or HEIC image."
        case .tooLarge: "This image is too large. Choose an image smaller than 10 MB."
        }
    }
}
