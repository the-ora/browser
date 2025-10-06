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
    @State private var isHeaderHovered = false

    private var filteredVisits: [History] {
        guard let containerId = tabManager.activeContainer?.id else { return [] }

        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return historyManager.getChronologicalHistory(for: containerId)
        } else {
            return historyManager.searchChronologicalHistory(searchText, activeContainerId: containerId)
        }
    }

    // Group visits by date
    private var groupedVisits: [(String, [History])] {
        let calendar = Calendar.current
        let today = Date()

        let grouped = Dictionary(grouping: filteredVisits) { visit in
            guard let visitDate = visit.visitedAt else { return "Unknown" }
            if calendar.isDate(visitDate, inSameDayAs: today) {
                return "Today"
            } else if calendar.isDate(
                visitDate,
                inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today) ?? today
            ) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .full
                formatter.timeStyle = .none
                return formatter.string(from: visitDate)
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
            return (key, visits.sorted {
                guard let date1 = $0.visitedAt, let date2 = $1.visitedAt else { return false }
                return date1 > date2
            })
        }
    }

    var body: some View {
        if privacyMode.isPrivate {
            HistoryViewPrivate()
        } else {
            VStack(spacing: 0) {
                // Header with search and controls
                VStack(spacing: 16) {
                    HStack {
                        Text("History")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Spacer()

                        if !isSelectMode {
                            HStack(spacing: 12) {
                                // Clear All - styled as proper UI button
                                Button(action: {
                                    showClearAllAlert = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Clear All")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .scaleEffect(isHeaderHovered ? 1.0 : 0.95)
                                .opacity(isHeaderHovered ? 1.0 : 0.7)
                                .animation(.easeInOut(duration: 0.2), value: isHeaderHovered)

                                // Select - appears on hover
                                if isHeaderHovered || isSelectMode {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isSelectMode = true
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("Select")
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(theme.accent.opacity(0.1))
                                        .foregroundColor(theme.accent)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        } else {
                            HStack(spacing: 12) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSelectMode = false
                                        selectedVisits.removeAll()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Cancel")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.1))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                if !selectedVisits.isEmpty {
                                    Button(action: {
                                        deleteSelectedVisits()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("Delete (\(selectedVisits.count))")
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundColor(.red)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHeaderHovered = hovering
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
                        Text("No history")
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
                                    searchText: searchText,
                                    isSelectMode: isSelectMode,
                                    selectedVisits: $selectedVisits,
                                    onVisitTap: { visit in
                                        openHistoryItem(visit)
                                    },
                                    onVisitDelete: { visit in
                                        deleteSingleVisit(visit)
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
    }

    private func openHistoryItem(_ visit: History) {
        guard !isSelectMode else { return }

        tabManager.openTab(
            url: visit.url,
            historyManager: historyManager,
            isPrivate: privacyMode.isPrivate
        )
    }

    private func deleteSelectedVisits() {
        let visitsToDelete = filteredVisits.filter { selectedVisits.contains($0.id) }
        historyManager.deleteHistories(visitsToDelete)
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

    private func deleteSingleVisit(_ visit: History) {
        historyManager.deleteHistory(visit)
    }
}

struct HistoryDateSection: View {
    @Environment(\.theme) private var theme

    let date: String
    let visits: [History]
    let searchText: String
    let isSelectMode: Bool
    @Binding var selectedVisits: Set<UUID>
    let onVisitTap: (History) -> Void
    let onVisitDelete: (History) -> Void

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
                HistoryRow(
                    visit: visit,
                    searchText: searchText,
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
                    },
                    onDelete: {
                        onVisitDelete(visit)
                    }
                )
            }
        }
        .padding(.bottom, 16)
    }
}

struct HistoryRow: View {
    @Environment(\.theme) private var theme

    let visit: History
    let searchText: String
    let isSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

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
                HighlightedText(
                    text: visit.title.isEmpty ? visit.urlString : visit.title,
                    searchText: searchText,
                    font: .system(size: 14, weight: .medium),
                    primaryColor: .primary,
                    highlightColor: theme.accent.opacity(0.3)
                )
                .lineLimit(1)

                HStack {
                    HighlightedText(
                        text: visit.urlString,
                        searchText: searchText,
                        font: .system(size: 12),
                        primaryColor: .secondary,
                        highlightColor: theme.accent.opacity(0.3)
                    )
                    .lineLimit(1)

                    Spacer()

                    Text(timeFormatter.string(from: visit.visitedAt ?? Date()))
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
                onDelete()
            }
        }
    }
}

#Preview {
    do {
        let historyContainer = try ModelContainer(for: History.self)
        let tabContainer = try ModelContainer(for: Tab.self)

        return HistoryView()
            .environmentObject(HistoryManager(
                modelContainer: historyContainer,
                modelContext: ModelContext(historyContainer)
            ))
            .environmentObject(TabManager(
                modelContainer: tabContainer,
                modelContext: ModelContext(tabContainer),
                mediaController: MediaController()
            ))
            .environmentObject(PrivacyMode(isPrivate: false))
            .withTheme()
    } catch {
        return Text("Preview unavailable: \(error.localizedDescription)")
            .foregroundColor(.red)
    }
}
