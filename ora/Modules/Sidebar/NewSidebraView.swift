import AppKit
import SwiftUI

// MARK: - Main View
struct NewSidebarView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedContainer = "personal"
  @State private var isContainerDropdownOpen = false
  @State private var draggedItem: String?
  @State private var containers: [ContainerData] = Self.defaultContainers

  private var selectedContainerData: ContainerData {
    containers.first { $0.id == selectedContainer } ?? containers[0]
  }

  private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      favoriteTabsGrid

      ScrollView(.vertical, showsIndicators: false) {
        pinnedTabsList
        if hasPinnedTabs && hasRegularTabs {
          Divider()
        }
        regularTabsList
      }

      containerSelector
    }
    .padding(.leading, 8)
    .padding(.bottom, 12)
  }
}

// MARK: - View Components
extension NewSidebarView {
  fileprivate var favoriteTabsGrid: some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(favoriteTabs) { tab in
        FavoriteTabButton(
          tab: tab,
          colorScheme: colorScheme,
          onTap: { selectTab(tab.id) },
          onFavoriteToggle: { toggleFavorite(tab.id) },
          onClose: { removeTab(tab.id) },
          onMoveToContainer: { moveTab(tab.id, to: $0) },
          availableContainers: containers,
          selectedContainerId: selectedContainer
        )
        .onDrag { dragTab(tab.id) }
        .onDrop(
          of: [.text],
          delegate: TabDropDelegate(
            item: tab,
            containers: $containers,
            selectedContainerId: selectedContainer,
            draggedItem: $draggedItem,
            targetSection: .favorites
          )
        )
      }
    }
  }

  fileprivate var pinnedTabsList: some View {
    LazyVStack(spacing: 6) {
      ForEach(pinnedTabs) { tab in
        tabItem(for: tab)
          .onDrag { dragTab(tab.id) }
          .onDrop(
            of: [.text],
            delegate: TabDropDelegate(
              item: tab,
              containers: $containers,
              selectedContainerId: selectedContainer,
              draggedItem: $draggedItem,
              targetSection: .pinned
            )
          )
      }
    }
  }

  fileprivate var regularTabsList: some View {
    LazyVStack(spacing: 6) {
      NewTabButton(addNewTab: addNewTab, colorScheme: colorScheme)

      ForEach(regularTabs) { tab in
        tabItem(for: tab)
          .onDrag { dragTab(tab.id) }
          .onDrop(
            of: [.text],
            delegate: TabDropDelegate(
              item: tab,
              containers: $containers,
              selectedContainerId: selectedContainer,
              draggedItem: $draggedItem,
              targetSection: .regular
            )
          )
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: regularTabs.map(\.id))
  }

  fileprivate var containerSelector: some View {
    VStack(spacing: 4) {
      if isContainerDropdownOpen {
        containerDropdown
      }

      containerButton
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isContainerDropdownOpen)
  }

  fileprivate var containerDropdown: some View {
    VStack(spacing: 2) {
      ForEach(containers) { container in
        ContainerButton(
          container: container,
          isSelected: selectedContainer == container.id,
          colorScheme: colorScheme
        ) {
          selectedContainer = container.id
          isContainerDropdownOpen = false
        }
      }
    }
    .padding(.top, 4)
    .padding(.horizontal, 4)
    .background(Color.adaptiveBackground(for: colorScheme).opacity(0.4))
    .cornerRadius(10)
    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
  }

  fileprivate var containerButton: some View {
    Button {
      isContainerDropdownOpen.toggle()
    } label: {
      HStack(spacing: 4) {
        Image(systemName: selectedContainerData.icon)
          .frame(width: 12, height: 12)

        Spacer()

        Text(selectedContainerData.title)
          .font(.system(size: 13, weight: .medium))

        Spacer()

        Image(systemName: "chevron.down")
          .frame(width: 12, height: 12)
          .rotationEffect(.degrees(isContainerDropdownOpen ? 180 : 0))
      }
      .foregroundColor(.secondary)
      .padding(8)
      .background(Color.adaptiveBackground(for: colorScheme).opacity(0.4))
      .cornerRadius(10)
    }
    .buttonStyle(.plain)
  }

  fileprivate func tabItem(for tab: TabData) -> some View {
    NewTabItem(
      tab: tab,
      isSelected: selectedContainerData.activeTabId == tab.id,
      isDragging: draggedItem == tab.id,
      colorScheme: colorScheme,
      onTap: { selectTab(tab.id) },
      onPinToggle: { togglePin(tab.id) },
      onFavoriteToggle: { toggleFavorite(tab.id) },
      onClose: { removeTab(tab.id) },
      onMoveToContainer: { moveTab(tab.id, to: $0) },
      availableContainers: containers,
      selectedContainerId: selectedContainer
    )
  }
}

// MARK: - Computed Properties
extension NewSidebarView {
  fileprivate var favoriteTabs: [TabData] {
    selectedContainerData.tabs.filter(\.isFavorite)
  }

  fileprivate var pinnedTabs: [TabData] {
    selectedContainerData.tabs.filter { $0.isPinned && !$0.isFavorite }
  }

  fileprivate var regularTabs: [TabData] {
    selectedContainerData.tabs.filter { !$0.isPinned && !$0.isFavorite }
  }

  fileprivate var hasPinnedTabs: Bool {
    !pinnedTabs.isEmpty
  }

  fileprivate var hasRegularTabs: Bool {
    !regularTabs.isEmpty
  }
}

// MARK: - Actions
extension NewSidebarView {
  fileprivate func addNewTab() {
    let newTab = TabData(
      id: "new-tab-\(Date().timeIntervalSince1970)",
      icon: "globe",
      title: "New Tab"
    )

    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].addTab(newTab)
  }

  fileprivate func removeTab(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].removeTab(withId: tabId)
  }

  fileprivate func togglePin(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].togglePin(tabId)
  }

  fileprivate func toggleFavorite(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].toggleFavorite(tabId)
  }

  fileprivate func selectTab(_ tabId: String) {
    guard let index = containers.firstIndex(where: { $0.id == selectedContainer }) else { return }
    containers[index].setActiveTab(tabId)
  }

  fileprivate func moveTab(_ tabId: String, to newContainerId: String) {
    guard let fromIndex = containers.firstIndex(where: { $0.id == selectedContainer }),
      let toIndex = containers.firstIndex(where: { $0.id == newContainerId }),
      fromIndex != toIndex,
      let tabIndex = containers[fromIndex].tabs.firstIndex(where: { $0.id == tabId })
    else { return }

    let tab = containers[fromIndex].tabs[tabIndex]
    containers[fromIndex].removeTab(withId: tabId)
    containers[toIndex].addTab(tab)
  }

  fileprivate func dragTab(_ tabId: String) -> NSItemProvider {
    draggedItem = tabId
    return NSItemProvider(object: NSString(string: tabId))
  }
}

// MARK: - Default Data
extension NewSidebarView {
  fileprivate static var defaultContainers: [ContainerData] {
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

// MARK: - Models
struct ContainerData: Identifiable {
  let id: String
  let icon: String
  let title: String
  var tabs: [TabData]
  var activeTabId: String?

  init(id: String, icon: String, title: String, activeTabId: String? = nil, tabs: [TabData]) {
    self.id = id
    self.icon = icon
    self.title = title
    self.tabs = tabs
    self.activeTabId = activeTabId ?? tabs.first?.id
  }

  mutating func addTab(_ tab: TabData) {
    tabs.insert(tab, at: 0)
    if activeTabId == nil {
      activeTabId = tab.id
    }
  }

  mutating func removeTab(withId id: String) {
    tabs.removeAll { $0.id == id }
    if activeTabId == id {
      activeTabId = tabs.first?.id
    }
  }

  mutating func setActiveTab(_ id: String) {
    if tabs.contains(where: { $0.id == id }) {
      activeTabId = id
    }
  }

  mutating func togglePin(_ id: String) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
    tabs[index].isPinned.toggle()
    if tabs[index].isPinned {
      tabs[index].isFavorite = false
    }
  }

  mutating func toggleFavorite(_ id: String) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
    tabs[index].isFavorite.toggle()
    if tabs[index].isFavorite {
      tabs[index].isPinned = false
    }
  }
}

struct TabData: Identifiable {
  let id: String
  let icon: String
  let title: String
  var isPinned: Bool
  var isFavorite: Bool

  init(id: String, icon: String, title: String, isPinned: Bool = false, isFavorite: Bool = false) {
    self.id = id
    self.icon = icon
    self.title = title
    self.isPinned = isPinned
    self.isFavorite = isFavorite
  }
}

// MARK: - Tab Item
struct NewTabItem: View {
  let tab: TabData
  let isSelected: Bool
  let isDragging: Bool
  let colorScheme: ColorScheme
  let onTap: () -> Void
  let onPinToggle: () -> Void
  let onFavoriteToggle: () -> Void
  let onClose: () -> Void
  let onMoveToContainer: (String) -> Void
  let availableContainers: [ContainerData]
  let selectedContainerId: String

  @State private var isHovering = false

  var body: some View {
    HStack {
      tabIcon
      tabTitle
      Spacer()
      actionButton
    }
    .padding(8)
    .background(backgroundColor)
    .cornerRadius(10)
    .overlay(dragOverlay)
    .shadow(color: isDragging ? .red.opacity(0.2) : .clear, radius: 8, y: 4)
    .opacity(isDragging ? 0.0 : 1.0)
    .onTapGesture(perform: onTap)
    .onHover { isHovering = $0 }
    .contextMenu { contextMenuItems }
    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
  }

  private var tabIcon: some View {
    Image(systemName: tab.icon)
      .frame(width: 12, height: 8.57143)
      .foregroundColor(textColor)
  }

  private var tabTitle: some View {
    Text(tab.title)
      .font(.system(size: 13, weight: .medium))
      .foregroundColor(textColor)
      .lineLimit(1)
  }

  private var backgroundColor: Color {
    if isSelected {
      return Color.adaptiveBackground(for: colorScheme)
    } else if isHovering {
      return Color.adaptiveBackground(for: colorScheme).opacity(0.3)
    }
    return .clear
  }

  private var textColor: Color {
    isSelected ? Color.adaptiveText(for: colorScheme) : .secondary
  }

  private var dragOverlay: some View {
    RoundedRectangle(cornerRadius: 10)
      .stroke(isDragging ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
  }

  @ViewBuilder
  private var actionButton: some View {
    if tab.isPinned {
      ActionButton(icon: "pin.slash", color: textColor, action: onPinToggle)
    } else if isHovering {
      ActionButton(icon: "xmark", color: textColor, action: onClose)
    }
  }

  @ViewBuilder
  private var contextMenuItems: some View {
    Button(action: onPinToggle) {
      Label(
        tab.isPinned ? "Unpin Tab" : "Pin Tab",
        systemImage: tab.isPinned ? "pin.slash" : "pin")
    }

    Button(action: onFavoriteToggle) {
      Label(
        tab.isFavorite ? "Remove from Favorites" : "Add to Favorites",
        systemImage: tab.isFavorite ? "star.slash" : "star")
    }

    Divider()

    Menu("Move to Container") {
      ForEach(availableContainers) { container in
        if container.id != selectedContainerId {
          Button(action: { onMoveToContainer(container.id) }) {
            Label(container.title, systemImage: container.icon)
          }
        }
      }
    }

    Divider()

    Button(role: .destructive, action: onClose) {
      Label("Close Tab", systemImage: "xmark")
    }
  }
}

// MARK: - Supporting Views
struct ActionButton: View {
  let icon: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .frame(width: 12, height: 12)
        .foregroundColor(color)
    }
    .buttonStyle(.plain)
  }
}

struct ContainerButton: View {
  let container: ContainerData
  let isSelected: Bool
  let colorScheme: ColorScheme
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: container.icon)
          .frame(width: 12, height: 12)

        Spacer()

        Text(container.title)
          .font(.system(size: 13, weight: .medium))

        Spacer()

        if isSelected {
          Image(systemName: "checkmark")
            .frame(width: 12, height: 12)
        }
      }
      .foregroundColor(.secondary)
      .padding(8)
      .background(isSelected ? Color.adaptiveBackground(for: colorScheme).opacity(0.8) : .clear)
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
  }
}

struct FavoriteTabButton: View {
  let tab: TabData
  let colorScheme: ColorScheme
  let onTap: () -> Void
  let onFavoriteToggle: () -> Void
  let onClose: () -> Void
  let onMoveToContainer: (String) -> Void
  let availableContainers: [ContainerData]
  let selectedContainerId: String

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 4) {
        Image(systemName: tab.icon)
          .frame(width: 16, height: 16)

        Text(tab.title)
          .font(.system(size: 10, weight: .medium))
          .lineLimit(1)
      }
      .foregroundColor(Color.adaptiveText(for: colorScheme))
      .frame(height: 48)
      .frame(maxWidth: .infinity)
      .background(Color.adaptiveBackground(for: colorScheme).opacity(0.6))
      .cornerRadius(10)
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button(action: onFavoriteToggle) {
        Label("Remove from Favorites", systemImage: "star.slash")
      }

      Divider()

      Menu("Move to Container") {
        ForEach(availableContainers) { container in
          if container.id != selectedContainerId {
            Button(action: { onMoveToContainer(container.id) }) {
              Label(container.title, systemImage: container.icon)
            }
          }
        }
      }

      Divider()

      Button(role: .destructive, action: onClose) {
        Label("Close Tab", systemImage: "xmark")
      }
    }
  }
}

struct NewTabButton: View {
  let addNewTab: () -> Void
  let colorScheme: ColorScheme
  @State private var isHovering = false

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

// MARK: - Tab Section Enum
enum TabSection {
  case favorites
  case pinned
  case regular
}

// MARK: - Tab Drop Delegate
struct TabDropDelegate: DropDelegate {
  let item: TabData
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  @Binding var draggedItem: String?
  let targetSection: TabSection

  func dropEntered(info: DropInfo) {
    guard let provider = info.itemProviders(for: [.text]).first else { return }

    provider.loadObject(ofClass: NSString.self) { string, _ in
      DispatchQueue.main.async {
        guard let fromId = string as? String,
          let containerIndex = containers.firstIndex(where: { $0.id == selectedContainerId }),
          let fromIndex = containers[containerIndex].tabs.firstIndex(where: { $0.id == fromId }),
          let toIndex = containers[containerIndex].tabs.firstIndex(where: { $0.id == item.id }),
          fromIndex != toIndex
        else { return }

        // Handle reordering within the same section
        if isInSameSection(fromId: fromId, toId: item.id) {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containers[containerIndex].tabs.move(
              fromOffsets: IndexSet(integer: fromIndex),
              toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
          }
        } else {
          // Handle moving between sections
          moveTabBetweenSections(fromId: fromId, toSection: targetSection)
        }
      }
    }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggedItem = nil
    return true
  }

  private func isInSameSection(fromId: String, toId: String) -> Bool {
    guard let containerIndex = containers.firstIndex(where: { $0.id == selectedContainerId }) else {
      return false
    }

    let fromTab = containers[containerIndex].tabs.first { $0.id == fromId }
    let toTab = containers[containerIndex].tabs.first { $0.id == toId }

    guard let fromTab = fromTab, let toTab = toTab else { return false }

    let fromSection = getSection(for: fromTab)
    let toSection = getSection(for: toTab)

    return fromSection == toSection
  }

  private func getSection(for tab: TabData) -> TabSection {
    if tab.isFavorite {
      return .favorites
    } else if tab.isPinned {
      return .pinned
    } else {
      return .regular
    }
  }

  private func moveTabBetweenSections(fromId: String, toSection: TabSection) {
    guard let containerIndex = containers.firstIndex(where: { $0.id == selectedContainerId }),
      let tabIndex = containers[containerIndex].tabs.firstIndex(where: { $0.id == fromId })
    else { return }

    var updatedContainers = containers
    let tab = updatedContainers[containerIndex].tabs[tabIndex]

    // Remove from current position
    updatedContainers[containerIndex].tabs.remove(at: tabIndex)

    // Update tab properties based on target section
    var updatedTab = tab
    switch toSection {
    case .favorites:
      updatedTab.isFavorite = true
      updatedTab.isPinned = false
    case .pinned:
      updatedTab.isPinned = true
      updatedTab.isFavorite = false
    case .regular:
      updatedTab.isPinned = false
      updatedTab.isFavorite = false
    }

    // Add to the beginning of the appropriate section
    updatedContainers[containerIndex].tabs.insert(updatedTab, at: 0)

    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      containers = updatedContainers
    }
  }
}

// MARK: - Color Extension
extension Color {
  static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .black : .white
  }

  static func adaptiveText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? .white : .black
  }
}
