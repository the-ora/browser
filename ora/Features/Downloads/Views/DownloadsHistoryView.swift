import SwiftUI

struct DownloadsHistoryView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var sidebarManager: SidebarManager
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    @State private var searchText = ""

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchBar
            Divider().opacity(0.5)
            content
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.subtleWindowBackgroundColor)
        .background(BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            // Match SidebarHeader traffic light spacing when sidebar is primary
            if sidebarManager.sidebarPosition != .secondary {
                WindowControls(isFullscreen: appState.isFullscreen)
                    .frame(height: 30)
            }

            Text("Downloads")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.foreground)
                .lineLimit(1)

            Spacer()

            if hasNonActiveDownloads {
                Button(action: {
                    downloadManager.clearCompletedDownloads()
                }) {
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        OraInput(
            text: $searchText,
            placeholder: "Search files...",
            variant: .ghost,
            size: .sm,
            leadingIcon: "magnifyingglass"
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: dismissDownloads) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Spaces")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(theme.foreground.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let filteredActive = filteredDownloads(from: downloadManager.activeDownloads)
        let filteredHistory = filteredDownloads(
            from: downloadManager.recentDownloads.filter { $0.status != .downloading }
        )
        let groupedHistory = groupByDate(filteredHistory)

        if downloadManager.activeDownloads.isEmpty, downloadManager.recentDownloads.isEmpty {
            emptyState
        } else if isSearching, filteredActive.isEmpty, filteredHistory.isEmpty {
            noResultsState
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !filteredActive.isEmpty {
                        sectionHeader("Active")
                        ForEach(filteredActive) { download in
                            DownloadHistoryRow(download: download)
                        }
                    }

                    ForEach(groupedHistory, id: \.label) { group in
                        if !filteredActive.isEmpty || group.label != groupedHistory.first?.label {
                            Divider().opacity(0.3).padding(.vertical, 4)
                        }
                        sectionHeader(group.label)
                        ForEach(group.downloads) { download in
                            DownloadHistoryRow(download: download)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(theme.mutedForeground)

            Text("No Downloads")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.foreground)

            Text("Files you download will appear here")
                .font(.system(size: 12))
                .foregroundColor(theme.mutedForeground)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No results for \u{201C}\(searchText)\u{201D}")
                .font(.system(size: 13))
                .foregroundColor(theme.mutedForeground)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // MARK: - Helpers

    private struct DateGroup {
        let label: String
        let downloads: [Download]
    }

    private func filteredDownloads(from downloads: [Download]) -> [Download] {
        guard isSearching else { return downloads }
        let query = searchText.lowercased()
        return downloads.filter { download in
            download.fileName.lowercased().contains(query)
                || download.originalURLString.lowercased().contains(query)
        }
    }

    private func groupByDate(_ downloads: [Download]) -> [DateGroup] {
        guard !downloads.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()

        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfThisWeek = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: now
        ))!
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek)!
        let startOf2WeeksAgo = calendar.date(byAdding: .weekOfYear, value: -2, to: startOfThisWeek)!
        let startOf1MonthAgo = calendar.date(byAdding: .month, value: -1, to: startOfToday)!
        let startOf2MonthsAgo = calendar.date(byAdding: .month, value: -2, to: startOfToday)!
        let startOf3MonthsAgo = calendar.date(byAdding: .month, value: -3, to: startOfToday)!
        let startOf6MonthsAgo = calendar.date(byAdding: .month, value: -6, to: startOfToday)!
        let startOf1YearAgo = calendar.date(byAdding: .year, value: -1, to: startOfToday)!

        // Ordered buckets: (label, lowerBound). A download goes into the first bucket
        // whose lowerBound is <= its date.
        let buckets: [(String, Date)] = [
            ("Today", startOfToday),
            ("Yesterday", startOfYesterday),
            ("This Week", startOfThisWeek),
            ("Last Week", startOfLastWeek),
            ("2 Weeks Ago", startOf2WeeksAgo),
            ("Last Month", startOf1MonthAgo),
            ("2 Months Ago", startOf2MonthsAgo),
            ("3 Months Ago", startOf3MonthsAgo),
            ("6 Months Ago", startOf6MonthsAgo),
            ("Last Year", startOf1YearAgo),
            ("Older", .distantPast)
        ]

        var grouped: [String: [Download]] = [:]
        for download in downloads {
            let date = download.completedAt ?? download.createdAt
            let label = buckets.first { date >= $0.1 }?.0 ?? "Older"
            grouped[label, default: []].append(download)
        }

        // Return in bucket order, skipping empty groups
        return buckets.compactMap { label, _ in
            guard let items = grouped[label], !items.isEmpty else { return nil }
            return DateGroup(label: label, downloads: items)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private var hasNonActiveDownloads: Bool {
        downloadManager.recentDownloads.contains {
            $0.status == .completed || $0.status == .failed || $0.status == .cancelled
        }
    }

    private func dismissDownloads() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            downloadManager.isShowingDownloadsHistory = false
        }
    }
}
