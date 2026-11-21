#if DEBUG
import AppKit
import SwiftUI

/// Captures this app's own view for visual QA, never the desktop or other applications.
final class PreviewCaptureDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let stdoutCapture = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_STDOUT"] == "1"
        guard let path = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_PATH"], !path.isEmpty || stdoutCapture else { return }
        if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_SHIMMER_FRAMES"] == "1" {
            for index in 0..<12 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(index) * 0.2) {
                    guard let view = NSApp.windows.first(where: { $0.contentView != nil })?.contentView,
                          let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    if let png = bitmap.representation(using: .png, properties: [:]),
                       let line = try? JSONSerialization.data(withJSONObject: ["frame": index, "png": png.base64EncodedString()]) {
                        FileHandle.standardOutput.write(line)
                        FileHandle.standardOutput.write(Data([10]))
                    }
                    if index == 11 { NSApp.terminate(nil) }
                }
            }
            return
        }
        let delay = Double(ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_DELAY"] ?? "3") ?? 3
        DispatchQueue.main.asyncAfter(deadline: .now() + min(max(delay, 1), ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_MOTION_CHECK"] == "1" ? 60 : 30)) {
            let popover = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_PAGE"] == "quick-settings"
                ? NSApp.windows.first(where: { String(describing: type(of: $0)).localizedCaseInsensitiveContains("popover") && $0.isVisible }) : nil
            let window = popover ?? NSApp.windows.first(where: { $0.attachedSheet != nil })?.attachedSheet ?? NSApp.windows.first(where: { $0.contentView != nil })
            if let window { fputs("Window input: key=\(window.canBecomeKey), current=\(window.isKeyWindow), style=\(window.styleMask.rawValue)\n", stderr) }
            if ProcessInfo.processInfo.environment["OUTLOUD_TITLEBAR_DIAGNOSTICS"] == "1", let window {
                for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                    if let button = window.standardWindowButton(kind) {
                        var node: NSView? = button
                        for _ in 0..<4 {
                            guard let item = node else { break }
                            fputs("Titlebar geometry: \(type(of: item)) frame=\(item.frame) bounds=\(item.bounds) window=\(item.convert(item.bounds, to: nil)) flipped=\(item.isFlipped)\n", stderr)
                            node = item.superview
                        }
                    }
                }
            }
            let captureView = ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_FRAME"] == "1" ? window?.contentView?.superview : window?.contentView
            guard let view = captureView,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                fputs("Unable to capture app view.\n", stderr)
                NSApp.terminate(nil)
                return
            }
            if ProcessInfo.processInfo.environment["OUTLOUD_PREVIEW_NATIVE_WINDOW"] == "1", let window {
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
                do { try capture.run(); capture.waitUntilExit() } catch { fputs("Window capture failed.\n", stderr) }
                NSApp.terminate(nil)
                return
            }
            view.layoutSubtreeIfNeeded()
            view.cacheDisplay(in: view.bounds, to: bitmap)
            do {
                if let exportPath = ProcessInfo.processInfo.environment["OUTLOUD_CANVAS_EXPORT_PATH"] {
                    let data = try ImageDraftCanvas.png(headline: "Ideas worth sharing.", projectName: "Example", color: Palette.mint)
                    guard let exported = NSBitmapImageRep(data: data),
                          exported.pixelsWide == 1080, exported.pixelsHigh == 1080 else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    try data.write(to: URL(fileURLWithPath: exportPath), options: .atomic)
                    print("Canvas export verified: 1080 × 1080 PNG")
                }
                guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
                if stdoutCapture { FileHandle.standardOutput.write(data) }
                else { try data.write(to: URL(fileURLWithPath: path), options: .atomic) }
            } catch { fputs("Preview capture failed: \(error)\n", stderr) }
            if let sheet = window, let parent = sheet.sheetParent { parent.endSheet(sheet) }
            NSApp.terminate(nil)
        }
    }
}
#endif
