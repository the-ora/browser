import AppKit
import SwiftUI

struct SearchEngineSettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var searchEngineService = SearchEngineService()

    @Environment(\.theme) var theme

    @State private var showingAddForm = false
    @State private var newEngineName = ""
    @State private var newEngineURL = ""
    @State private var newEngineAliases = ""
    @State private var newEngineIsAI = false

    private var isValidURL: Bool {
        newEngineURL
            .contains("{query}")
            && URL(string: newEngineURL.replacingOccurrences(of: "{query}", with: "test")) != nil
    }

    var body: some View {
        SettingsContainer(maxContentWidth: 760) {
            Form {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
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
                            Spacer()
                            Button(showingAddForm ? "Cancel" : "Add Custom Engine") {
                                if showingAddForm {
                                    cancelForm()
                                } else {
                                    showingAddForm = true
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(theme.solidWindowBackgroundColor)
                    .cornerRadius(8)

                    if showingAddForm {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Add New Search Engine")
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
                                        TextField(
                                            "https://example.com/search?q={query}",
                                            text: $newEngineURL
                                        )
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
                                    Text("Type:")
                                        .frame(width: 80, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Toggle("AI Chat Engine", isOn: $newEngineIsAI)
                                        Text(
                                            "Check if this is an AI chat service (affects placeholder text)"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }

                                HStack {
                                    Spacer()
                                    Button("Save") {
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

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Global Default Engines")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("Individual spaces can override these defaults")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Choose which search engines to use by default across all spaces:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Conventional Search Engines
                        let conventionalEngines = searchEngineService.builtInSearchEngines.filter {
                            !$0.isAIChat
                        }
                        if !conventionalEngines.isEmpty {
                            Text("Conventional Search Engines")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)

                            ForEach(conventionalEngines, id: \.name) { engine in
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
                                            settings.globalDefaultSearchEngine = engine.name
                                        }
                                    }
                                )
                            }
                        }

                        // AI Search Engines
                        let aiEngines = searchEngineService.builtInSearchEngines.filter(\.isAIChat)
                        if !aiEngines.isEmpty {
                            Text("AI Search Engines")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            ForEach(aiEngines, id: \.name) { engine in
                                BuiltInSearchEngineRow(
                                    engine: engine,
                                    isDefault: settings.globalDefaultSearchEngine == engine.name,
                                    onSetAsDefault: {
                                        settings.globalDefaultSearchEngine = engine.name
                                    }
                                )
                            }
                        }

                        if !settings.customSearchEngines.isEmpty {
                            Divider()

                            Text("Custom Search Engines")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }

                        // Custom search engines
                        ForEach(settings.customSearchEngines) { engine in
                            CustomSearchEngineRow(
                                engine: engine,
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
                                    // Edit is now handled inline in the row
                                },
                                isDefault: settings.globalDefaultSearchEngine == engine.name,
                                settings: settings
                            )
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
        newEngineIsAI = false
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
            aliases: aliasesList,
            isAIChat: newEngineIsAI
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
    @State private var editIsAI = false

    private var isValidEditURL: Bool {
        editURL.contains("{query}")
            && URL(string: editURL.replacingOccurrences(of: "{query}", with: "test")) != nil
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
                        HStack {
                            Text("Name:")
                                .frame(width: 80, alignment: .leading)
                            TextField("Search Engine Name", text: $editName)
                        }

                        HStack {
                            Text("URL:")
                                .frame(width: 80, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("https://example.com/search?q={query}", text: $editURL)
                                if !editURL.isEmpty, !isValidEditURL {
                                    Text("URL must contain {query} and be a valid URL")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }

                        HStack {
                            Text("Aliases:")
                                .frame(width: 80, alignment: .leading)
                            TextField("e.g., ddg, duck", text: $editAliases)
                        }

                        HStack {
                            Text("Type:")
                                .frame(width: 80, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("AI Chat Engine", isOn: $editIsAI)
                                Text(
                                    "Check if this is an AI chat service (affects placeholder text)"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
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

                    // Name and badges
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
                        if engine.isAIChat {
                            Text("AI")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
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
            }
        }
        .onAppear {
            populateEditFields()
        }
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
        editIsAI = engine.isAIChat
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
                aliases: aliasesList,
                isAIChat: editIsAI
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
                faviconBackgroundColorData: engine.faviconBackgroundColorData,
                isAIChat: editIsAI
            )
            settings.updateCustomSearchEngine(updatedEngine)
        }

        isEditing = false
    }
}
