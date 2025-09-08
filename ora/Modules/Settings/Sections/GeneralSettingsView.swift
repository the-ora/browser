import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var updateService: UpdateService
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.theme) var theme
    @State private var isColorPickerOpen = false
    @State private var customColor: Color = {
        // Load saved custom color or default to orange
        if let hexString = UserDefaults.standard.string(forKey: ThemeConstants.customColorLightKey) {
            return Color(hex: hexString)
        }
        return .orange
    }()

    var body: some View {
        SettingsContainer(maxContentWidth: 760) {
            Form {
                VStack(alignment: .leading, spacing: 16) {
                    // App Version Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ora Browser")
                                .font(.headline)
                            Spacer()
                            Text(getAppVersion())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("Fast, secure, and beautiful browser built for macOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(theme.solidWindowBackgroundColor)
                    .cornerRadius(8)

                    HStack {
                        Text("Born for your Mac. Make Ora your default browser.")
                        Spacer()
                        Button("Set Ora as default") { openDefaultBrowserSettings() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(theme.solidWindowBackgroundColor)
                    .cornerRadius(8)

                    AppearanceSelector(selection: $appearanceManager.appearance)

                    // Color Scheme Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color Scheme").foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                            spacing: 12
                        ) {
                            ForEach(ColorTheme.allCases) { colorTheme in
                                let isSelected = appearanceManager.colorTheme == colorTheme

                                if colorTheme == .custom {
                                    // Custom color picker button with popover
                                    Button {
                                        isColorPickerOpen = true
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                // Show the actual selected custom color
                                                Circle()
                                                    .fill(customColor)
                                                    .frame(width: 32, height: 32)
                                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                                
                                                // Paint palette icon overlay with dynamic color
                                                Image(systemName: "paintpalette.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(contrastColor(for: customColor))
                                                    .shadow(color: .black.opacity(0.3), radius: 1)

                                                // Always reserve space for border, show/hide with opacity
                                                Circle()
                                                    .stroke(theme.foreground, lineWidth: 2)
                                                    .frame(width: 38, height: 38)
                                                    .opacity(isSelected ? 1 : 0)
                                            }

                                            Text(colorTheme.rawValue)
                                                .font(.caption)
                                                .fontWeight(isSelected ? .semibold : .regular)
                                                .foregroundColor(isSelected ? theme.foreground : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: $isColorPickerOpen, arrowEdge: .bottom) {
                                        ColorPickerView(selectedColor: $customColor) { newColor in
                                            // Apply the custom color live as user drags
                                            customColor = newColor
                                            
                                            // Generate a darker version for dark mode
                                            let lightHex = newColor.toHex() ?? "#f3e5d6"
                                            let darkColor = newColor.adjusted(brightness: 0.3, saturation: 1.2)
                                            let darkHex = darkColor.toHex() ?? "#63411D"
                                            
                                            // Store custom colors
                                            UserDefaults.standard.set(lightHex, forKey: ThemeConstants.customColorLightKey)
                                            UserDefaults.standard.set(darkHex, forKey: ThemeConstants.customColorDarkKey)
                                            
                                            // Force theme update
                                            withAnimation(.easeInOut(duration: ThemeConstants.colorTransitionDuration)) {
                                                appearanceManager.colorTheme = .custom
                                                // Post notifications to update theme
                                                NotificationCenter.default.post(name: .colorThemeChanged, object: ColorTheme.custom)
                                                NotificationCenter.default.post(name: .customColorChanged, object: nil)
                                            }
                                        }
                                    }
                                } else {
                                    // Regular color theme buttons
                                    Button {
                                        withAnimation(.easeInOut(duration: ThemeConstants.colorTransitionDuration)) {
                                            appearanceManager.colorTheme = colorTheme
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                colorTheme.primaryLight,
                                                                colorTheme.primaryDark
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 32, height: 32)
                                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                                                // Always reserve space for border, show/hide with opacity
                                                Circle()
                                                    .stroke(theme.foreground, lineWidth: 2)
                                                    .frame(width: 38, height: 38)
                                                    .opacity(isSelected ? 1 : 0)
                                            }

                                            Text(colorTheme.rawValue)
                                                .font(.caption)
                                                .fontWeight(isSelected ? .semibold : .regular)
                                                .foregroundColor(isSelected ? theme.foreground : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Updates")
                            .font(.headline)

                        Toggle("Automatically check for updates", isOn: $settings.autoUpdateEnabled)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("Check for Updates") {
                                    updateService.checkForUpdates()
                                }

                                if updateService.isCheckingForUpdates {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 16, height: 16)
                                }

                                if updateService.updateAvailable {
                                    Text("Update available!")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }

                            if let result = updateService.lastCheckResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(updateService.updateAvailable ? .green : .secondary)
                            }

                            // Show current app version
                            if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                Text("Current version: \(appVersion)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            // Show last check time
                            if let lastCheck = updateService.lastCheckDate {
                                Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func openDefaultBrowserSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.general?DefaultWebBrowser"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version) (\(build))"
    }
    
    // Calculate the best contrast color (black or white) for the given background color
    private func contrastColor(for backgroundColor: Color) -> Color {
        let nsColor = NSColor(backgroundColor)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return .white }
        
        // Calculate relative luminance
        let r = rgbColor.redComponent
        let g = rgbColor.greenComponent
        let b = rgbColor.blueComponent
        
        // Convert to linear RGB
        let linearR = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let linearG = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let linearB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        let luminance = 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB
        
        // Return soft dark for light backgrounds, soft light for dark backgrounds
        return luminance > 0.5 ? Color(hex: "2C2C2E") : Color(hex: "F2F2F7")
    }
}
