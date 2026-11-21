import AppKit
import SwiftUI

@main
struct GenerateAppIcon {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Pass the AppIcon.appiconset directory.")
        }
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let renderer = ImageRenderer(content:
                ZStack {
                    RoundedRectangle(cornerRadius: 205).fill(Palette.background).padding(40)
                    OutloudMark().padding(215)
                }.frame(width: 1024, height: 1024)
            )
            renderer.scale = Double(size) / 1024
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else {
                fatalError("Could not render icon at \(size).")
            }
            try data.write(to: folder.appendingPathComponent("icon-\(size).png"))
        }
        print("Rendered native fan app icon assets.")
    }
}
