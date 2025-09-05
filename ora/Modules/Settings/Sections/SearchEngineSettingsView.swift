import AppKit
import SwiftUI

struct SearchEngineSettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var searchEngineService = SearchEngineService()
    @StateObject private var faviconService = FaviconService()
    @Environment(\.theme) var theme

    @State private var showingAddForm = false
    @State private var editingEngine: CustomSearchEngine? = nil
    @State private var newEngineName = ""
    @State private var newEngineURL = ""
    @State private var newEngineAliases = ""

    private var isValidURL: Bool {
        newEngineURL
            .contains("{query}") && URL(string: newEngineURL.replacingOccurrences(of: "{query}", with: "test")) != nil
    }

    var body: some View {
        SettingsContainer(maxContentWidth: 760) {
            Form {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Add custom search engines with your own URLs and shortcuts.")
                        Spacer()
                        Button(showingAddForm || editingEngine != nil ? "Cancel" : "Add Search Engine") {
                            if showingAddForm || editingEngine != nil {
                                cancelForm()
                            } else {
                                showingAddForm = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(theme.solidWindowBackgroundColor)
                    .cornerRadius(8)

                    if showingAddForm || editingEngine != nil {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(editingEngine != nil ? "Edit Search Engine" : "Add New Search Engine")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Name:")
                                        .frame(width: 80, alignment: .leading)
                                    TextField("Search Engine Name", text: $newEngineName)
                                }

                                HStack {
                                    Text("URL:")
                                        .frame(width: 80, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        TextField("https://example.com/search?q={query}", text: $newEngineURL)
                                        Text("Include {query} where the search term should go")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if !newEngineURL.isEmpty, !isValidURL {
                                            Text("URL must contain {query} and be a valid URL")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                        }
                                    }
                                }

                                HStack {
                                    Text("Aliases:")
                                        .frame(width: 80, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        TextField("e.g., ddg, duck", text: $newEngineAliases)
                                        Text("Comma-separated shortcuts (optional)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                HStack {
                                    Spacer()
                                    Button(editingEngine != nil ? "Update" : "Save") {
                                        saveSearchEngine()
                                    }
                                    .disabled(newEngineName.isEmpty || !isValidURL)
                                }
                            }
                        }
                        .padding(12)
                        .background(theme.solidWindowBackgroundColor.opacity(0.3))
                        .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Search Engine").foregroundStyle(.secondary)
                        HStack {
                            AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=google.com&sz=16"
                            )) { image in
                                image
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }

                            Text("Google")
                                .font(.body)

                            if settings.globalDefaultSearchEngine == nil {
                                Text("Default")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }

                            Spacer()

                            if settings.globalDefaultSearchEngine != nil {
                                Button("Set as Default") {
                                    settings.globalDefaultSearchEngine = nil
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if !settings.customSearchEngines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Search Engines").foregroundStyle(.secondary)
                            ForEach(settings.customSearchEngines) { engine in
                                CustomSearchEngineRow(
                                    engine: engine,
                                    faviconService: faviconService,
                                    onDelete: {
                                        if settings.globalDefaultSearchEngine == engine.name {
                                            settings.globalDefaultSearchEngine = nil
                                        }
                                        settings.removeCustomSearchEngine(withId: engine.id)
                                    },
                                    onSetAsDefault: {
                                        settings.globalDefaultSearchEngine = engine.name
                                    },
                                    onEdit: {
                                        editingEngine = engine
                                        populateForm(with: engine)
                                    },
                                    isDefault: settings.globalDefaultSearchEngine == engine.name
                                )
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            searchEngineService.setTheme(theme)
        }
    }

    private func clearForm() {
        newEngineName = ""
        newEngineURL = ""
        newEngineAliases = ""
        editingEngine = nil
    }

    private func cancelForm() {
        clearForm()
        showingAddForm = false
    }

    private func populateForm(with engine: CustomSearchEngine) {
        newEngineName = engine.name
        newEngineURL = engine.searchURL
        newEngineAliases = engine.aliases.joined(separator: ", ")
        showingAddForm = false
    }

    private func saveSearchEngine() {
        let aliasesList = newEngineAliases
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let editingEngine {
            // Update existing engine
            let updatedEngine = CustomSearchEngine(
                id: editingEngine.id,
                name: newEngineName,
                searchURL: newEngineURL,
                aliases: aliasesList
            )
            settings.updateCustomSearchEngine(updatedEngine)
        } else {
            // Add new engine
            let engine = CustomSearchEngine(
                name: newEngineName,
                searchURL: newEngineURL,
                aliases: aliasesList
            )
            settings.addCustomSearchEngine(engine)
        }

        clearForm()
        showingAddForm = false
    }
}

struct CustomSearchEngineRow: View {
    let engine: CustomSearchEngine
    let faviconService: FaviconService
    let onDelete: () -> Void
    let onSetAsDefault: () -> Void
    let onEdit: () -> Void
    let isDefault: Bool

    @State private var favicon: NSImage? = nil

    var body: some View {
        HStack {
            // Favicon
            Group {
                if let favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .frame(width: 16, height: 16)
                } else {
                    AsyncImage(url: faviconURL) { image in
                        image
                            .resizable()
                            .frame(width: 16, height: 16)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
            }

            // Name and Default badge
            HStack(spacing: 8) {
                Text(engine.name)
                    .font(.body)
                if isDefault {
                    Text("Default")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                if !isDefault {
                    Button("Set as Default") {
                        onSetAsDefault()
                    }
                }

                Button("Edit") {
                    onEdit()
                }

                Button("Delete") {
                    onDelete()
                }
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            favicon = faviconService.getFavicon(for: engine.searchURL)
        }
        .onReceive(faviconService.objectWillChange) {
            favicon = faviconService.getFavicon(for: engine.searchURL)
        }
    }

    private var faviconURL: URL? {
        guard let domain = URL(string: engine.searchURL)?.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=16")
    }
}
