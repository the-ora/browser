import SwiftUI

class ExtensionViewModel: ObservableObject {
    @Published var directories: [URL] = []
}

struct ExtensionsSettingsView: View {
    @StateObject private var viewModel = ExtensionViewModel()
    @State private var isImporting = false
    @State private var extensionsDir: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Extensions")
                .font(.title)
                .padding(.bottom, 10)

            if let dir = extensionsDir {
                Text("Extensions Directory: \(dir.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Import Extension Zip") {
                isImporting = true
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.zip],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await importAndExtractZip(from: url)
                        }
                    }
                case .failure(let error):
                    print("File import failed: \(error)")
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
            let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
            viewModel.directories = contents.filter { url in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue
            }
        } catch {
            print("Failed to load directories: \(error)")
        }
    }

    private func importAndExtractZip(from zipURL: URL) async {
        guard let destDir = extensionsDir else { return }

        // Create a subfolder named after the zip file (without .zip)
        let zipName = zipURL.deletingPathExtension().lastPathComponent
        let extractDir = destDir.appendingPathComponent(zipName)
        if !FileManager.default.fileExists(atPath: extractDir.path) {
            try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        }

        // Copy zip to temp location in extractDir
        let tempZipURL = extractDir.appendingPathComponent("temp.zip")
        do {
            try FileManager.default.copyItem(at: zipURL, to: tempZipURL)
        } catch {
            print("Failed to copy zip: \(error)")
            return
        }

        // Extract using bash unzip
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", tempZipURL.path, "-d", extractDir.path] // -o to overwrite

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("Extraction successful")
                // Remove temp zip
                try? FileManager.default.removeItem(at: tempZipURL)
                // Reload directories
                loadExtensionDirectories()
            } else {
                print("Extraction failed")
            }
        } catch {
            print("Failed to extract: \(error)")
        }
    }
}
