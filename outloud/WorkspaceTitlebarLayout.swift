import AppKit
import SwiftUI

/// Align the real macOS window controls with the custom 52-point workspace bar.
/// The starter and setup windows retain their existing native geometry.
struct WorkspaceTitlebarLayout: NSViewRepresentable {
    @Binding var isFullScreen: Bool
    func makeNSView(context: Context) -> AlignmentView { AlignmentView() }
    func updateNSView(_ view: AlignmentView, context: Context) {
        let binding = _isFullScreen
        view.onFullScreenChange = { fullScreen in
            guard binding.wrappedValue != fullScreen else { return }
            binding.wrappedValue = fullScreen
        }
        view.scheduleAlignment()
    }
    static func dismantleNSView(_ view: AlignmentView, coordinator: ()) { view.restore() }

    final class AlignmentView: NSView {
        private var observers: [NSObjectProtocol] = []
        private weak var alignedWindow: NSWindow?
        private weak var titlebar: NSView?
        private weak var container: NSView?
        private var originalHeight: CGFloat = 32
        private var originalButtonFrames: [NSWindow.ButtonType: NSRect] = [:]
        private var active = true
        private var aligning = false
        private var scheduled = false
        private var observedViews: Set<ObjectIdentifier> = []
        var onFullScreenChange: ((Bool) -> Void)?
        private var fullScreenTransition = false
        private var reportedFullScreen: Bool?
        private var controlReveal: DispatchWorkItem?
        private var concealingRestoredControls = false

        private func beginFullScreenExit() {
            controlReveal?.cancel()
            concealingRestoredControls = true
            // macOS briefly restores its shorter titlebar before our custom bar settles.
            // Keep that intermediate native control position out of the visible transition.
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                alignedWindow?.standardWindowButton(type)?.alphaValue = 0
            }
        }
        private func finishFullScreenExit() {
            scheduleAlignment()
            let reveal = DispatchWorkItem { [weak self] in
                guard let self, self.active, !self.fullScreenTransition,
                      let window = self.alignedWindow, !window.styleMask.contains(.fullScreen) else { return }
                self.align()
                self.concealingRestoredControls = false
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                        window.standardWindowButton(type)?.animator().alphaValue = 1
                    }
                }
                self.controlReveal = nil
            }
            controlReveal?.cancel()
            controlReveal = reveal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: reveal)
        }
        private func reportFullScreen(_ value: Bool) {
            guard active, reportedFullScreen != value else { return }
            reportedFullScreen = value
            onFullScreenChange?(value)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            alignedWindow = window
            for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification, NSWindow.didBecomeKeyNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleAlignment() }
                })
            }
            observers.append(NotificationCenter.default.addObserver(forName: .outloudExitFullScreen, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.active, !self.fullScreenTransition,
                          let window = self.alignedWindow, window.styleMask.contains(.fullScreen) else { return }
                    window.toggleFullScreen(nil)
                }
            })
            for name in [NSWindow.willEnterFullScreenNotification, NSWindow.didEnterFullScreenNotification,
                         NSWindow.willExitFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] notification in
                    MainActor.assumeIsolated {
                        guard let self, self.active else { return }
                        switch notification.name {
                        case NSWindow.willEnterFullScreenNotification:
                            self.controlReveal?.cancel()
                            self.controlReveal = nil
                            self.concealingRestoredControls = false
                            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                                window.standardWindowButton(type)?.alphaValue = 1
                            }
                            self.fullScreenTransition = true
                        case NSWindow.didEnterFullScreenNotification:
                            self.fullScreenTransition = false
                            self.reportFullScreen(true)
                        case NSWindow.willExitFullScreenNotification:
                            self.fullScreenTransition = true
                            self.beginFullScreenExit()
                            // Make room before the native window controls reappear.
                            self.reportFullScreen(false)
                        case NSWindow.didExitFullScreenNotification:
                            self.fullScreenTransition = false
                            self.reportFullScreen(false)
                            self.finishFullScreenExit()
                        default: break
                        }
                    }
                })
            }
            scheduleAlignment()
        }
        override func layout() {
            super.layout()
            align()
        }
        func scheduleAlignment() {
            guard active, !aligning, !scheduled else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active else { return }
                self.scheduled = false
                if !self.fullScreenTransition, let window = self.alignedWindow {
                    self.reportFullScreen(window.styleMask.contains(.fullScreen))
                }
                self.align()
            }
        }
        private func align() {
            guard active, !aligning, !fullScreenTransition, let window = alignedWindow, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton), let bar = close.superview,
                  let holder = bar.superview else { return }
            aligning = true
            defer { aligning = false }
            for item in [bar, holder] + [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap({ window.standardWindowButton($0) }) {
                guard observedViews.insert(ObjectIdentifier(item)).inserted else { continue }
                item.postsFrameChangedNotifications = true
                observers.append(NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: item, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleAlignment() }
                })
            }
            if titlebar == nil {
                titlebar = bar; container = holder; originalHeight = holder.frame.height
                for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                    originalButtonFrames[type] = window.standardWindowButton(type)?.frame
                }
            }
            // Native full-screen transitions own titlebar geometry until didExit.
            // Once settled, correct alignment without inheriting their animation context.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                let height: CGFloat = 52
                // Keep the titlebar anchored to the window's top edge, including on resize.
                let holderFrame = NSRect(x: holder.frame.minX, y: holder.frame.maxY - height, width: holder.frame.width, height: height)
                if holder.frame != holderFrame { holder.frame = holderFrame }
                let barFrame = NSRect(x: bar.frame.minX, y: 0, width: holder.bounds.width, height: height)
                if bar.frame != barFrame { bar.frame = barFrame }
                for (index, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
                    guard let button = window.standardWindowButton(type) else { continue }
                    if concealingRestoredControls { button.alphaValue = 0 }
                    let origin = NSPoint(x: 16 + CGFloat(index) * 23, y: height / 2 - button.frame.height / 2)
                    if button.frame.origin != origin { button.setFrameOrigin(origin) }
                }
            }
        }
        func restore() {
            guard active else { return }
            active = false
            controlReveal?.cancel()
            controlReveal = nil
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                alignedWindow?.standardWindowButton(type)?.alphaValue = 1
            }
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
            if let holder = container, let bar = titlebar {
                holder.setFrameOrigin(NSPoint(x: holder.frame.minX, y: holder.frame.maxY - originalHeight))
                holder.setFrameSize(NSSize(width: holder.frame.width, height: originalHeight))
                bar.frame = NSRect(x: bar.frame.minX, y: 0, width: holder.bounds.width, height: originalHeight)
            }
            for (type, frame) in originalButtonFrames { alignedWindow?.standardWindowButton(type)?.frame = frame }
        }
    }
}
