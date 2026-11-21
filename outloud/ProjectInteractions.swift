import SwiftUI
import AppKit

/// Track horizontal trackpad motion without intercepting row clicks or vertical scrolling.
struct ProjectRowSwipeSurface: NSViewRepresentable {
    let changed: (CGFloat, Bool) -> Void
    func makeNSView(context: Context) -> SwipeView { let view = SwipeView(); view.changed = changed; return view }
    func updateNSView(_ view: SwipeView, context: Context) { view.changed = changed }
    final class SwipeView: NSView {
        var changed: ((CGFloat, Bool) -> Void)?
        private var monitor: Any?
        private var trackingSwipe = false
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(point) || self.trackingSwipe else { return event }
                let horizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                guard horizontal || self.trackingSwipe else { return event }
                if event.phase == .began || horizontal { self.trackingSwipe = true }
                let finished = event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended
                if event.momentumPhase.isEmpty { self.changed?(-event.scrollingDeltaX, finished) }
                if finished { self.trackingSwipe = false }
                return nil
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}

struct ProjectDeletionConfirmation: View {
    let project: Project
    let cancel: () -> Void
    let confirm: (String) -> Void
    @State private var typedName = ""
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var scheme
    private var matches: Bool { typedName == project.name }
    var body: some View {
        ZStack {
            Color.black.opacity(scheme == .dark ? 0.22 : 0.12).ignoresSafeArea().onTapGesture(perform: cancel)
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Delete project").font(.system(size: 18, weight: .semibold))
                    Text("Saved work will be lost. This action cannot be undone.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 3)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type “\(project.name)”").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    TextField("Project name", text: $typedName).textFieldStyle(.plain).font(.system(size: 14))
                        .padding(.horizontal, 13).frame(height: 44).focused($focused)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.primary.opacity(focused ? 0.25 : 0.1)))
                        .onSubmit { if matches { confirm(typedName) } }
                        .accessibilityLabel("Project name confirmation")
                }
                HStack(spacing: 12) {
                    Spacer()
                    Button("Cancel", action: cancel).buttonStyle(.plain).font(.system(size: 13, weight: .medium)).padding(.horizontal, 14)
                    Button { if matches { confirm(typedName) } } label: {
                        Text("Delete").font(.system(size: 13, weight: .medium)).padding(.horizontal, 20).frame(height: 35)
                            .foregroundStyle(matches ? Color.white : Color.secondary)
                            .background(matches ? Color(red: 0.72, green: 0.22, blue: 0.23) : Color.primary.opacity(0.07), in: Capsule())
                    }.buttonStyle(FluidPressStyle()).disabled(!matches)
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: matches)
                }.padding(.top, 4)
            }.padding(22).frame(width: 360).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(scheme == .dark ? 0.1 : 0.6)))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8).padding(20)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.86).offset(y: appeared || reduceMotion ? 0 : 12).opacity(appeared ? 1 : 0)
        }.onAppear { focused = true; withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.67)) { appeared = true } }.onExitCommand(perform: cancel)
    }
}

struct FluidPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct ImageImportWarning: View {
    let message: String
    let dismiss: () -> Void
    @State private var dark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        ZStack {
            Color.black.opacity(dark ? 0.25 : 0.12).ignoresSafeArea().onTapGesture(perform: dismiss)
            VStack(alignment: .leading, spacing: 17) {
                Image(systemName: "photo.badge.exclamationmark").font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                Text("This image couldn’t be added").font(.system(size: 19, weight: .semibold))
                Text(message).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
                HStack { Spacer(); Button("Got it", action: dismiss).buttonStyle(.borderedProminent).controlSize(.large).tint(dark ? .white.opacity(0.2) : .black.opacity(0.8)) }
            }.padding(26).frame(width: 370)
                .background { WarningGlassSurface(dark: dark).clipShape(RoundedRectangle(cornerRadius: 23)) }
                .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.white.opacity(dark ? 0.12 : 0.65)))
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.88).opacity(appeared ? 1 : 0)
                .environment(\.colorScheme, dark ? .dark : .light)
        }.onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.73)) { appeared = true } }
            .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))) { _ in
                withAnimation(.easeInOut(duration: 0.25)) { dark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" }
            }.onExitCommand(perform: dismiss)
    }
}

private struct WarningGlassSurface: NSViewRepresentable {
    let dark: Bool
    func makeNSView(context: Context) -> NSVisualEffectView { let view = NSVisualEffectView(); view.material = .hudWindow; view.blendingMode = .withinWindow; view.state = .active; return view }
    func updateNSView(_ view: NSVisualEffectView, context: Context) { view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua) }
}
