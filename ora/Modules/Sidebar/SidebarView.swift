import AppKit
import SwiftUI

struct SidebarView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedContainer = "personal"
  @State private var isContainerDropdownOpen = false
  @State private var draggedItem: String?
  @State private var containers: [ContainerData] = SidebarView.defaultContainers

  private var selectedContainerData: ContainerData {
    containers.first { $0.id == selectedContainer } ?? containers[0]
  }

  private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      FavTabsGrid(
        tabs: favoriteTabs,
        selectedTabId: selectedContainerData.activeTabId,
        draggedItem: draggedItem,
        containers: $containers,
        selectedContainerId: selectedContainer,
        onSelect: selectTab,
        onFavoriteToggle: toggleFavorite,
        onClose: removeTab,
        onMoveToContainer: moveTab
      )

      ScrollView(.vertical, showsIndicators: false) {
        PinnedTabsList(
          tabs: pinnedTabs,
          selectedTabId: selectedContainerData.activeTabId,
          draggedItem: draggedItem,
          containers: $containers,
          selectedContainerId: selectedContainer,
          onSelect: selectTab,
          onPinToggle: togglePin,
          onFavoriteToggle: toggleFavorite,
          onClose: removeTab,
          onMoveToContainer: moveTab
        )
        Divider()
        RegularTabsList(
          tabs: regularTabs,
          selectedTabId: selectedContainerData.activeTabId,
          draggedItem: draggedItem,
          containers: $containers,
          selectedContainerId: selectedContainer,
          onSelect: selectTab,
          onPinToggle: togglePin,
          onFavoriteToggle: toggleFavorite,
          onClose: removeTab,
          onMoveToContainer: moveTab,
          onAddNewTab: addNewTab
        )
      }

      ContainerSelector(
        containers: containers,
        selectedContainerId: $selectedContainer,
        isDropdownOpen: $isContainerDropdownOpen,
      )
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 12)
  }

  private var favoriteTabs: [TabData] {
    selectedContainerData.tabs.filter(\.isFavorite)
  }

  private var pinnedTabs: [TabData] {
    selectedContainerData.tabs.filter { $0.isPinned && !$0.isFavorite }
  }

  private var regularTabs: [TabData] {
    selectedContainerData.tabs.filter { !$0.isPinned && !$0.isFavorite }
  }

  private func addNewTab() {
    let newTab = TabData(
      id: "new-tab-\(Date().timeIntervalSince1970)",
      icon: "globe",
      title: "New Tab"
    )
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].addTab(newTab)
  }

  private func removeTab(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].removeTab(withId: tabId)
  }

  private func togglePin(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].togglePin(tabId)
  }

  private func toggleFavorite(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].toggleFavorite(tabId)
  }

  private func selectTab(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].setActiveTab(tabId)
  }

  private func moveTab(_ tabId: String, to newContainerId: String) {
    guard let fromIndex = containers.firstIndex(where: { $0.id == selectedContainer }),
      let toIndex = containers.firstIndex(where: { $0.id == newContainerId }),
      fromIndex != toIndex,
      let tabIndex = containers[fromIndex].tabs.firstIndex(where: { $0.id == tabId })
    else { return }

    let tab = containers[fromIndex].tabs[tabIndex]
    containers[fromIndex].removeTab(withId: tabId)
    containers[toIndex].addTab(tab)
  }

  private func dragTab(_ tabId: String) -> NSItemProvider {
    draggedItem = tabId
    return NSItemProvider(object: NSString(string: tabId))
  }

  private static var defaultContainers: [ContainerData] {
    [
      ContainerData(
        id: "personal", icon: "person", title: "Personal", activeTabId: "ora",
        tabs: [
          TabData(id: "ora", icon: "globe", title: "Ora", isFavorite: true),
          TabData(id: "mail", icon: "envelope", title: "Gmail", isPinned: true),
          TabData(id: "photos", icon: "photo", title: "Photos", isFavorite: true),
          TabData(id: "music", icon: "music.note", title: "Music", isPinned: true),
          TabData(id: "notes", icon: "note.text", title: "Notes", isFavorite: true),
          TabData(id: "calendar", icon: "calendar", title: "Calendar"),
          TabData(id: "maps", icon: "map", title: "Maps"),
          TabData(id: "reminders", icon: "list.bullet", title: "Reminders"),
          TabData(id: "settings", icon: "gearshape", title: "Settings"),
        ]
      ),
      ContainerData(
        id: "work", icon: "briefcase", title: "Work", activeTabId: "github",
        tabs: [
          TabData(
            id: "slack", icon: "bubble.left.and.bubble.right", title: "Slack", isPinned: true,
            isFavorite: true),
          TabData(
            id: "github", icon: "chevron.left.slash.chevron.right", title: "GitHub", isPinned: true,
            isFavorite: true),
          TabData(id: "notion", icon: "square.grid.2x2", title: "Notion", isFavorite: true),
          TabData(id: "google", icon: "globe", title: "Google", isFavorite: true),
          TabData(id: "zoom", icon: "video", title: "Zoom", isPinned: true),
          TabData(id: "drive", icon: "externaldrive", title: "Drive", isFavorite: true),
          TabData(id: "docs", icon: "doc.text", title: "Docs", isFavorite: true),
          TabData(id: "figma", icon: "pencil.and.outline", title: "Figma"),
          TabData(id: "calendar-work", icon: "calendar", title: "Work Calendar"),
          TabData(id: "terminal", icon: "terminal", title: "Terminal"),
        ]
      ),
      ContainerData(
        id: "school", icon: "graduationcap", title: "School", activeTabId: "classroom",
        tabs: [
          TabData(
            id: "classroom", icon: "books.vertical", title: "Classroom", isPinned: true,
            isFavorite: true),
          TabData(
            id: "assignments", icon: "checklist", title: "Assignments", isPinned: true,
            isFavorite: true),
          TabData(id: "grades", icon: "chart.bar", title: "Grades", isFavorite: true),
          TabData(id: "lectures", icon: "tv", title: "Lectures", isFavorite: true),
          TabData(
            id: "notes", icon: "note.text", title: "Class Notes", isPinned: true, isFavorite: true),
          TabData(id: "messages", icon: "message", title: "Messages", isFavorite: true),
          TabData(id: "research", icon: "magnifyingglass", title: "Research", isFavorite: true),
          TabData(id: "school-calendar", icon: "calendar", title: "School Calendar"),
          TabData(id: "quizlet", icon: "square.stack.3d.up", title: "Quizlet"),
          TabData(id: "library", icon: "book", title: "Library"),
          TabData(id: "school-settings", icon: "gearshape", title: "Settings"),
        ]
      ),
    ]
  }
}

struct NewTabButton: View {
  let addNewTab: () -> Void

  @State private var isHovering = false
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    Button(action: addNewTab) {
      HStack(spacing: 8) {
        Image(systemName: "plus")
          .frame(width: 12, height: 12)

        Text("New Tab")
          .font(.system(size: 13, weight: .medium))
      }
      .foregroundColor(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
    .padding(8)
    .background(isHovering ? Color.adaptiveBackground(for: colorScheme).opacity(0.3) : .clear)
    .cornerRadius(10)
    .onHover { isHovering = $0 }
  }
}

extension Color {
  static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .black : .white
  }

  static func adaptiveText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .white : .black
  }

  static func mutedBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .black.opacity(0.15) : .white.opacity(0.5)
  }
}
