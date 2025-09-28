import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var privacyMode: PrivacyMode

    @State private var searchText = ""
    @State private var selectedVisits: Set<UUID> = []
    @State private var isSelectMode = false
    @State private var showClearAllAlert = false

    private var filteredVisits: [HistoryVisit] {
        guard let containerId = tabManager.activeContainer?.id else { return [] }

        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return historyManager.getChronologicalHistory(for: containerId)
        } else {
            return historyManager.searchChronologicalHistory(searchText, activeContainerId: containerId)
        }
    }

    // Group visits by date
    private var groupedVisits: [(String, [HistoryVisit])] {
        let calendar = Calendar.current
        let today = Date()

        let grouped = Dictionary(grouping: filteredVisits) { visit in
            if calendar.isDate(visit.visitedAt, inSameDayAs: today) {
                return "Today"
            } else if calendar.isDate(
                visit.visitedAt,
                inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today) ?? today
            ) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .full
                formatter.timeStyle = .none
                return formatter.string(from: visit.visitedAt)
            }
        }

        let sortedKeys = grouped.keys.sorted { key1, key2 in
            if key1 == "Today" { return true }
            if key2 == "Today" { return false }
            if key1 == "Yesterday" { return true }
            if key2 == "Yesterday" { return false }

            // For other dates, sort by actual date
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .none

            let date1 = formatter.date(from: key1) ?? Date.distantPast
            let date2 = formatter.date(from: key2) ?? Date.distantPast
            return date1 > date2
        }

        return sortedKeys.compactMap { key in
            guard let visits = grouped[key] else { return nil }
            return (key, visits.sorted { $0.visitedAt > $1.visitedAt })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and controls
            VStack(spacing: 16) {
                HStack {
                    Text("Browsing History")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    if !isSelectMode {
                        HStack(spacing: 12) {
                            Button("Clear All") {
                                showClearAllAlert = true
                            }
                            .foregroundColor(.red)
                            .buttonStyle(.plain)

                            Button("Select") {
                                isSelectMode = true
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack {
                            Button("Cancel") {
                                isSelectMode = false
                                selectedVisits.removeAll()
                            }
                            .buttonStyle(.plain)

                            if !selectedVisits.isEmpty {
                                Button("Delete Selected (\(selectedVisits.count))") {
                                    deleteSelectedVisits()
                                }
                                .foregroundColor(.red)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(theme.background.opacity(0.5))
                .cornerRadius(8)
            }
            .padding()

            Divider()

            // History list
            if groupedVisits.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No browsing history")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Start browsing to see your history here" : "No results found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedVisits, id: \.0) { dateGroup in
                            HistoryDateSection(
                                date: dateGroup.0,
                                visits: dateGroup.1,
                                isSelectMode: isSelectMode,
                                selectedVisits: $selectedVisits,
                                onVisitTap: { visit in
                                    openHistoryItem(visit)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()
        }
        .background(theme.background)
        .alert("Clear All History", isPresented: $showClearAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllHistory()
            }
        } message: {
            Text("Are you sure you want to delete all browsing history? This action cannot be undone.")
        }
    }

    private func openHistoryItem(_ visit: HistoryVisit) {
        guard !isSelectMode else { return }

        tabManager.openTab(
            url: visit.url,
            historyManager: historyManager,
            isPrivate: privacyMode.isPrivate
        )
    }

    private func deleteSelectedVisits() {
        let visitsToDelete = filteredVisits.filter { selectedVisits.contains($0.id) }
        historyManager.deleteHistoryVisits(visitsToDelete)
        selectedVisits.removeAll()
        isSelectMode = false
    }

    private func clearAllHistory() {
        guard let container = tabManager.activeContainer else { return }
        historyManager.clearContainerHistory(container)

        // Exit select mode if active
        if isSelectMode {
            isSelectMode = false
            selectedVisits.removeAll()
        }
    }
}

struct HistoryDateSection: View {
    @Environment(\.theme) private var theme

    let date: String
    let visits: [HistoryVisit]
    let isSelectMode: Bool
    @Binding var selectedVisits: Set<UUID>
    let onVisitTap: (HistoryVisit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
            HStack {
                Text(date)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(visits.count) \(visits.count == 1 ? "visit" : "visits")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)

            // Visit items
            ForEach(visits, id: \.id) { visit in
                HistoryVisitRow(
                    visit: visit,
                    isSelectMode: isSelectMode,
                    isSelected: selectedVisits.contains(visit.id),
                    onTap: {
                        if isSelectMode {
                            if selectedVisits.contains(visit.id) {
                                selectedVisits.remove(visit.id)
                            } else {
                                selectedVisits.insert(visit.id)
                            }
                        } else {
                            onVisitTap(visit)
                        }
                    }
                )
            }
        }
        .padding(.bottom, 16)
    }
}

struct HistoryVisitRow: View {
    @Environment(\.theme) private var theme

    let visit: HistoryVisit
    let isSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }

            // Favicon
            Group {
                if let faviconLocalFile = visit.faviconLocalFile,
                   let image = NSImage(contentsOf: faviconLocalFile)
                {
                    Image(nsImage: image)
                        .resizable()
                } else {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 16, height: 16)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.title.isEmpty ? visit.urlString : visit.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack {
                    Text(visit.urlString)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(timeFormatter.string(from: visit.visitedAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? theme.accent.opacity(0.3) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("Open in New Tab") {
                // TODO: Implement open in new tab
            }

            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(visit.urlString, forType: .string)
            }

            Button("Delete This Visit") {
                // TODO: Implement single visit deletion
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(HistoryManager(
            modelContainer: try! ModelContainer(for: History.self, HistoryVisit.self),
            modelContext: ModelContext(try! ModelContainer(for: History.self, HistoryVisit.self))
        ))
        .environmentObject(TabManager(
            modelContainer: try! ModelContainer(for: Tab.self),
            modelContext: ModelContext(try! ModelContainer(for: Tab.self)),
            mediaController: MediaController()
        ))
        .environmentObject(PrivacyMode(isPrivate: false))
        .withTheme()
}
