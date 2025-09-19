import AppKit
import SwiftUI

struct SearchEngineSettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var searchEngineService = SearchEngineService()
    @StateObject private var faviconService = FaviconService()
    @Environment(\.theme) var theme

    @State private var showingAddForm = false
    @State private var newEngineName = ""
    @State private var newEngineURL = ""
    @State private var newEngineAliases = ""

    private var isValidURL: Bool {
        newEngineURL
            .contains("{query}")
            && URL(
                string: newEngineURL.replacingOccurrences(
                    of: "{query}",
                    with: "test"
                )
            ) != nil
    }

    var body: some View {
        VStack {
            Form {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search Engine Library")
                            .font(.headline)
                        Text(
                            "Manage available search engines and set global defaults. Individual spaces can override these in the Spaces tab."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Button(showingAddForm ? "Cancel" : "Add Custom Engine") {
                        if showingAddForm {
                            cancelForm()
                        } else {
                            showingAddForm = true
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showingAddForm {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Add New Search Engine")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $newEngineName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)

                            VStack(alignment: .leading) {
                                VStack(alignment: .leading, spacing: 4) {
                                    TextField("URL", text: $newEngineURL)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: .infinity)
                                    Text(
                                        "Include {query} where the search term should go"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    if !newEngineURL.isEmpty, !isValidURL {
                                        Text(
                                            "URL must contain {query} and be a valid URL"
                                        )
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity)

                            VStack(alignment: .leading, spacing: 4) {
                                TextField(
                                    "Aliases",
                                    text: $newEngineAliases
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                                Text("Comma-separated e.g., ddg, duck")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Spacer()
                                Button("Save") {
                                    saveSearchEngine()
                                }
                                .disabled(newEngineName.isEmpty || !isValidURL)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(12)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("Search Engines") {
                    ForEach(
                        searchEngineService.builtInSearchEngines,
                        id: \.name
                    ) { engine in
                        BuiltInSearchEngineRow(
                            engine: engine,
                            isDefault: settings.globalDefaultSearchEngine
                                == engine
                                .name
                                || (settings.globalDefaultSearchEngine == nil
                                    && engine.name == "Google"
                                ),
                            onSetAsDefault: {
                                if engine.name == "Google" {
                                    settings.globalDefaultSearchEngine = nil
                                } else {
                                    settings.globalDefaultSearchEngine =
                                        engine.name
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !settings.customSearchEngines.isEmpty {
                    Divider()

                    Text("Custom Search Engines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    ForEach(settings.customSearchEngines) { engine in
                        CustomSearchEngineRow(
                            engine: engine,
                            onDelete: {
                                if settings.globalDefaultSearchEngine
                                    == engine.name
                                {
                                    settings.globalDefaultSearchEngine = nil
                                }
                                settings.removeCustomSearchEngine(
                                    withId: engine.id
                                )
                            },
                            onSetAsDefault: {
                                settings.globalDefaultSearchEngine = engine.name
                            },
                            onEdit: {
                                // Edit is now handled inline in the row
                            },
                            isDefault: settings.globalDefaultSearchEngine
                                == engine.name,
                            settings: settings
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(maxWidth: .infinity)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.top, -20)
        }

        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .onAppear {
            searchEngineService.setTheme(theme)
        }
    }

    private func clearForm() {
        newEngineName = ""
        newEngineURL = ""
        newEngineAliases = ""
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
        let aliasesList =
            newEngineAliases
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        // Create engine with favicon fetched upfront
        CustomSearchEngine.createWithFavicon(
            name: newEngineName,
            searchURL: newEngineURL,
            aliases: aliasesList
        ) { [weak settings] engine in
            settings?.addCustomSearchEngine(engine)
        }

        clearForm()
        showingAddForm = false
    }
}

struct BuiltInSearchEngineRow: View {
    let engine: SearchEngine
    let isDefault: Bool
    let onSetAsDefault: () -> Void

    var body: some View {
        HStack {
            // Favicon or icon
            Group {
                if !engine.icon.isEmpty {
                    Image(engine.icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(engine.color.opacity(0.8))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(String(engine.name.first ?? "S"))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        )
                }
            }

            // Name and badges
            HStack(spacing: 8) {
                Text(engine.name)
                    .font(.body)

                if engine.isAIChat {
                    Text("AI")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }

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

            // Set as default button
            if !isDefault {
                Button("Set as Default") {
                    onSetAsDefault()
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CustomSearchEngineRow: View {
    let engine: CustomSearchEngine
    let onDelete: () -> Void
    let onSetAsDefault: () -> Void
    let onEdit: () -> Void
    let isDefault: Bool
    let settings: SettingsStore

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editURL = ""
    @State private var editAliases = ""

    private var isValidEditURL: Bool {
        editURL.contains("{query}")
            && URL(
                string: editURL.replacingOccurrences(
                    of: "{query}",
                    with: "test"
                )
            ) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                // Inline edit form
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Favicon
                        Group {
                            if let favicon = engine.favicon {
                                Image(nsImage: favicon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            } else {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                        }

                        Text("Edit Search Engine")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Name:")
                                .frame(width: 80, alignment: .leading)
                            TextField("Search Engine Name", text: $editName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }

                        HStack(alignment: .top) {
                            Text("URL:")
                                .frame(width: 80, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                TextField(
                                    "https://example.com/search?q={query}",
                                    text: $editURL
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                                if !editURL.isEmpty, !isValidEditURL {
                                    Text(
                                        "URL must contain {query} and be a valid URL"
                                    )
                                    .foregroundColor(.red)
                                    .font(.caption)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text("Aliases:")
                                .frame(width: 80, alignment: .leading)
                            TextField("e.g., ddg, duck", text: $editAliases)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }

                        HStack {
                            Spacer()
                            Button("Cancel") {
                                cancelEdit()
                            }
                            Button("Update") {
                                saveEdit()
                            }
                            .disabled(editName.isEmpty || !isValidEditURL)
                        }
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Normal display
                HStack {
                    // Favicon
                    Group {
                        if let favicon = engine.favicon {
                            Image(nsImage: favicon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 16, height: 16)
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
                            startEdit()
                        }

                        Button("Delete") {
                            onDelete()
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            populateEditFields()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startEdit() {
        populateEditFields()
        isEditing = true
    }

    private func cancelEdit() {
        isEditing = false
        populateEditFields()
    }

    private func populateEditFields() {
        editName = engine.name
        editURL = engine.searchURL
        editAliases = engine.aliases.joined(separator: ", ")
    }

    private func saveEdit() {
        let aliasesList =
            editAliases
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        // Create updated engine with favicon if URL changed, otherwise keep existing favicon
        if editURL != engine.searchURL {
            // URL changed, fetch new favicon
            CustomSearchEngine.createWithFavicon(
                id: engine.id,
                name: editName,
                searchURL: editURL,
                aliases: aliasesList
            ) { [weak settings] updatedEngine in
                settings?.updateCustomSearchEngine(updatedEngine)
            }
        } else {
            // URL unchanged, keep existing favicon
            let updatedEngine = CustomSearchEngine(
                id: engine.id,
                name: editName,
                searchURL: editURL,
                aliases: aliasesList,
                faviconData: engine.faviconData,
                faviconBackgroundColorData: engine.faviconBackgroundColorData
            )
            settings.updateCustomSearchEngine(updatedEngine)
        }

        isEditing = false
    }
}
