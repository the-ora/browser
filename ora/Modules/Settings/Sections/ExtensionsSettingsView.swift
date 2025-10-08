import SwiftUI

@Observable
class ExtensionViewModel {
    var directories: [URL] = []
    var isInstalled = false
}

struct ExtensionsSettingsView: View {
    @State private var viewModel = ExtensionViewModel()
    @State private var isImporting = false
    @State private var extensionsDir: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Manage Extensions")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.top, 20)

            if let dir = extensionsDir {
                Text("Extensions Directory: \(dir.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Button("Import Extension Zip") {
                isImporting = true
                Task {
                    await importAndExtractZip()
                }
            }

            Divider()

            Text("Installed Extensions:")
                .font(.headline)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.directories, id: \.path) { dir in
                        HStack {
                            Text(dir.lastPathComponent)
                            Spacer()
                            Button("Install") {
                                Task {
                                    await OraExtensionManager.shared.installExtension(from: dir)

                                    // Reload view if extension has been installed.
                                    viewModel.isInstalled = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        viewModel.isInstalled = false
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            if let extensionToUninstall = OraExtensionManager.shared.extensionMap[dir] {
                                Button("Delete") {
                                    OraExtensionManager.shared.uninstallExtension(extensionToUninstall)
                                    // Remove the directory
                                    try? FileManager.default.removeItem(at: dir)
                                    // Reload directories
                                    loadExtensionDirectories()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .onAppear {
            setupExtensionsDirectory()
            loadExtensionDirectories()
        }
        .onChange(of: viewModel.isInstalled) { _, _ in
            loadExtensionDirectories()
        }
    }

    private func setupExtensionsDirectory() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        extensionsDir = supportDir.appendingPathComponent("extensions")
        if !FileManager.default.fileExists(atPath: extensionsDir!.path) {
            try? FileManager.default.createDirectory(at: extensionsDir!, withIntermediateDirectories: true)
        }
    }

    private func loadExtensionDirectories() {
        guard let dir = extensionsDir else { return }
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            viewModel.directories = contents.filter { url in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue
            }
        } catch {
            print("Failed to load directories: \(error)")
        }
    }

    private func importAndExtractZip() async {
        // Use NSOpenPanel to let the user select a ZIP file
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.zip]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false

        guard openPanel.runModal() == .OK, let zipURL = openPanel.urls.first else {
            print("No file selected or user canceled.")
            return
        }

        guard let destDir = extensionsDir else { return }

        // Create a subfolder named after the zip file (without .zip)
        let zipName = zipURL.deletingPathExtension().lastPathComponent
        let extractDir = destDir.appendingPathComponent(zipName)
        if !FileManager.default.fileExists(atPath: extractDir.path) {
            try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        }

        // Copy zip to temp location inside extractDir
        let tempZipURL = extractDir.appendingPathComponent("temp.zip")
        do {
            try FileManager.default.copyItem(at: zipURL, to: tempZipURL)
        } catch {
            print("Failed to copy zip: \(error)")
            return
        }

        // Extract using Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", tempZipURL.path, "-d", extractDir.path]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("Extraction successful")

                // Delete temp.zip
                try? FileManager.default.removeItem(at: tempZipURL)

                // Flattens extension folder structure.
                flattenDir(from: extractDir, to: zipName)

                // Remove __MACOSX (macOS metadata) if it exists
                cleanUp(extractDir)

                // Reload as needed
                loadExtensionDirectories()
            } else {
                print("Extraction failed")
            }
        } catch {
            print("Failed to extract: \(error)")
        }
    }

    func flattenDir(from extractDir: URL, to zipName: String) {
        // Move contents of extractDir/zipName to extractDir
        let nestedDir = extractDir.appendingPathComponent(zipName)
        if FileManager.default.fileExists(atPath: nestedDir.path) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: nestedDir,
                    includingPropertiesForKeys: nil
                )
                for item in contents {
                    let destinationURL = extractDir.appendingPathComponent(item.lastPathComponent)
                    try? FileManager.default.moveItem(at: item, to: destinationURL)
                }

                // Remove the nested folder after moving
                try? FileManager.default.removeItem(at: nestedDir)
            } catch {
                print("Error moving nested contents: \(error)")
            }
        }
    }

    func cleanUp(_ extractDir: URL) {
        let macosxDir = extractDir.appendingPathComponent("__MACOSX")
        if FileManager.default.fileExists(atPath: macosxDir.path) {
            try? FileManager.default.removeItem(at: macosxDir)
        }
    }
}
