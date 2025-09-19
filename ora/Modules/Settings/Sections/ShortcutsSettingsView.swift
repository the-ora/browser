import AppKit
import SwiftUI

struct ShortcutsSettingsView: View {
    @State private var editingKey: String?
    @State private var capturedDescription: String = ""

    private var sections: [(category: String, items: [ShortcutItem])] {
        KeyboardShortcuts.itemsByCategory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts").foregroundStyle(.secondary)
            List {
                ForEach(sections, id: \.category) { section in
                    Section(section.category) {
                        ForEach(section.items) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text(item.display).monospaced()
                                Button("Edit") { editingKey = item.name }
                            }
                        }
                    }
                }
            }

            if editingKey != nil {
                GroupBox("Press new keys…") {
                    ZStack {
                        Color.clear
                        KeyCaptureView { event in
                            capturedDescription = describe(event)
                        }
                    }
                    .frame(height: 80)
                    HStack {
                        Text("Captured: \(capturedDescription)")
                        Spacer()
                        Button("Save") { editingKey = nil }
                        Button("Cancel") {
                            editingKey = nil
                            capturedDescription = ""
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func describe(_ event: NSEvent) -> String {
        var parts: [String] = []
        if event.modifierFlags.contains(.command) { parts.append("⌘") }
        if event.modifierFlags.contains(.option) { parts.append("⌥") }
        if event.modifierFlags.contains(.shift) { parts.append("⇧") }
        if event.modifierFlags.contains(.control) { parts.append("⌃") }
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            parts.append(chars.uppercased())
        }
        return parts.joined()
    }
}
