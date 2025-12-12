import SwiftUI

struct ThemeColorPicker: View {
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme Colors")
                .font(.headline)

            Text("Customize the primary colors used throughout the browser.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                // Primary Color (used for both light and dark modes)
                ColorPickerRow(
                    title: "Primary Color",
                    description: "Used for backgrounds and accents in both light and dark modes",
                    color: Binding(
                        get: {
                            if let hex = settings.themePrimaryColor {
                                return Color(hex: hex)
                            }
                            return Color(hex: "#d6f3ea")
                        },
                        set: { newColor in
                            settings.themePrimaryColor = newColor.toHex()
                        }
                    ),
                    defaultColor: Color(hex: "#d6f3ea"),
                    onReset: {
                        settings.themePrimaryColor = nil
                    }
                )

                // Accent Color
                ColorPickerRow(
                    title: "Accent Color",
                    description: "Used for interactive elements and highlights",
                    color: Binding(
                        get: {
                            if let hex = settings.themeAccentColor {
                                return Color(hex: hex)
                            }
                            return Color(hex: "#575dff")
                        },
                        set: { newColor in
                            settings.themeAccentColor = newColor.toHex()
                        }
                    ),
                    defaultColor: Color(hex: "#575dff"),
                    onReset: {
                        settings.themeAccentColor = nil
                    }
                )
            }
        }
    }
}

private struct ColorPickerRow: View {
    let title: String
    let description: String
    @Binding var color: Color
    let defaultColor: Color
    let onReset: () -> Void

    @State private var isUsingCustom = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 50)

            Button {
                onReset()
                isUsingCustom = false
            } label: {
                Text("Reset")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(!isUsingCustom)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .onChange(of: color) { _, newValue in
            // Check if color differs from default (with small tolerance for floating point)
            let defaultHex = defaultColor.toHex() ?? ""
            let newHex = newValue.toHex() ?? ""
            isUsingCustom = defaultHex.lowercased() != newHex.lowercased()
        }
        .onAppear {
            // Check initial state
            let defaultHex = defaultColor.toHex() ?? ""
            let currentHex = color.toHex() ?? ""
            isUsingCustom = defaultHex.lowercased() != currentHex.lowercased()
        }
    }
}

