import AppKit
import SwiftUI

enum LicenseKeyFormat {
    static func formatted(_ input: String) -> String {
        let raw = String(input.uppercased().unicodeScalars.filter { (65...90).contains($0.value) || (48...57).contains($0.value) })
        guard !raw.isEmpty else { return "" }
        if raw == "O" { return raw }
        let payload = String((raw.hasPrefix("OL") ? String(raw.dropFirst(2)) : raw).prefix(24))
        guard !payload.isEmpty else { return "OL-" }
        return "OL-" + stride(from: 0, to: payload.count, by: 6).map { start in
            String(payload.dropFirst(start).prefix(6))
        }.joined(separator: "-")
    }
    static func isComplete(_ key: String) -> Bool {
        key.range(of: #"^OL-(?:[A-Z2-7]{6}-){3}[A-Z2-7]{6}$"#, options: .regularExpression) != nil
    }
}

/// A genuinely single-line AppKit field. Pasting line breaks cannot grow it.
struct LicenseKeyField: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var enabled: Bool
    var submit: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = "OL-XXXXXX-XXXXXX-XXXXXX-XXXXXX"
        field.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        field.textColor = .white
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byClipping
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setAccessibilityIdentifier("outloud-license-key")
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        field.isEnabled = enabled
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LicenseKeyField
        init(_ parent: LicenseKeyField) { self.parent = parent }
        func controlTextDidBeginEditing(_ notification: Notification) { parent.focused = true }
        func controlTextDidEndEditing(_ notification: Notification) { parent.focused = false }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let raw = field.stringValue
            let editor = field.currentEditor() as? NSTextView
            let atEnd = editor?.selectedRange().location == raw.utf16.count
            let formatted = LicenseKeyFormat.formatted(raw)
            if raw != formatted {
                let oldLocation = editor?.selectedRange().location ?? raw.utf16.count
                field.stringValue = formatted
                editor?.setSelectedRange(NSRange(location: atEnd ? formatted.utf16.count : min(oldLocation, formatted.utf16.count), length: 0))
            }
            parent.text = formatted
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
            if command == #selector(NSResponder.insertNewline(_:)) { parent.submit(); return true }
            return false
        }
    }
}
struct ActivateButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.ui(13, weight: .semibold))
            .foregroundStyle(enabled ? Color(red: 0.04, green: 0.13, blue: 0.09) : Color.white.opacity(0.45))
            .frame(width: 166, height: 43)
            .background(enabled ? Color(red: 0.67, green: 0.94, blue: 0.82).opacity(configuration.isPressed ? 0.78 : 1) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(enabled ? 0.10 : 0.06)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
