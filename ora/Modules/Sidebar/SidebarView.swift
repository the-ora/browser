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
      FavoriteTabsGrid(
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
        colorScheme: colorScheme
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

struct FavoriteTabsGrid: View {
  let tabs: [TabData]
  let selectedTabId: String?
  let draggedItem: String?
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  let onSelect: (String) -> Void
  let onFavoriteToggle: (String) -> Void
  let onClose: (String) -> Void
  let onMoveToContainer: (String, String) -> Void

  private let columns = Array(repeating: GridItem(spacing: 10), count: 3)

  var body: some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(tabs) { tab in
        FavoriteTabButton(
          tab: tab,
          isSelected: selectedTabId == tab.id,
          isDragging: draggedItem == tab.id,
          onTap: { onSelect(tab.id) },
          onFavoriteToggle: { onFavoriteToggle(tab.id) },
          onClose: { onClose(tab.id) },
          onMoveToContainer: { onMoveToContainer(tab.id, $0) },
          availableContainers: containers,
          selectedContainerId: selectedContainerId
        )
        .onDrag { NSItemProvider(object: NSString(string: tab.id)) }
        .onDrop(
          of: [.text],
          delegate: TabDropDelegate(
            item: tab,
            containers: $containers,
            selectedContainerId: selectedContainerId,
            draggedItem: .constant(draggedItem),
            targetSection: .favorites
          )
        )
      }
    }
  }
}

struct PinnedTabsList: View {
  let tabs: [TabData]
  let selectedTabId: String?
  let draggedItem: String?
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  let onSelect: (String) -> Void
  let onPinToggle: (String) -> Void
  let onFavoriteToggle: (String) -> Void
  let onClose: (String) -> Void
  let onMoveToContainer: (String, String) -> Void

  var body: some View {
    LazyVStack(spacing: 6) {
      ForEach(tabs) { tab in
        TabItem(
          tab: tab,
          isSelected: selectedTabId == tab.id,
          isDragging: draggedItem == tab.id,
          onTap: { onSelect(tab.id) },
          onPinToggle: { onPinToggle(tab.id) },
          onFavoriteToggle: { onFavoriteToggle(tab.id) },
          onClose: { onClose(tab.id) },
          onMoveToContainer: { onMoveToContainer(tab.id, $0) },
          availableContainers: containers,
          selectedContainerId: selectedContainerId
        )
        .onDrag { NSItemProvider(object: NSString(string: tab.id)) }
        .onDrop(
          of: [.text],
          delegate: TabDropDelegate(
            item: tab,
            containers: $containers,
            selectedContainerId: selectedContainerId,
            draggedItem: .constant(draggedItem),
            targetSection: .pinned
          )
        )
      }
    }
  }
}

struct RegularTabsList: View {
  let tabs: [TabData]
  let selectedTabId: String?
  let draggedItem: String?
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  let onSelect: (String) -> Void
  let onPinToggle: (String) -> Void
  let onFavoriteToggle: (String) -> Void
  let onClose: (String) -> Void
  let onMoveToContainer: (String, String) -> Void
  let onAddNewTab: () -> Void

  var body: some View {
    LazyVStack(spacing: 6) {
      NewTabButton(addNewTab: onAddNewTab)
      ForEach(tabs) { tab in
        TabItem(
          tab: tab,
          isSelected: selectedTabId == tab.id,
          isDragging: draggedItem == tab.id,
          onTap: { onSelect(tab.id) },
          onPinToggle: { onPinToggle(tab.id) },
          onFavoriteToggle: { onFavoriteToggle(tab.id) },
          onClose: { onClose(tab.id) },
          onMoveToContainer: { onMoveToContainer(tab.id, $0) },
          availableContainers: containers,
          selectedContainerId: selectedContainerId
        )
        .onDrag { NSItemProvider(object: NSString(string: tab.id)) }
        .onDrop(
          of: [.text],
          delegate: TabDropDelegate(
            item: tab,
            containers: $containers,
            selectedContainerId: selectedContainerId,
            draggedItem: .constant(draggedItem),
            targetSection: .regular
          )
        )
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tabs.map(\.id))
  }
}

struct ContainerSelector: View {
  let containers: [ContainerData]
  @Binding var selectedContainerId: String
  @Binding var isDropdownOpen: Bool
  let colorScheme: ColorScheme

  var body: some View {
    VStack(spacing: 4) {
      if isDropdownOpen {
        ContainerDropdown(
          containers: containers,
          selectedContainerId: $selectedContainerId,
          isDropdownOpen: $isDropdownOpen,
          colorScheme: colorScheme
        )
      }
      HStack {
        Button(action: { isDropdownOpen.toggle() }) {
          HStack(spacing: 4) {
            Image(systemName: containers.first { $0.id == selectedContainerId }?.icon ?? "person")
              .frame(width: 12, height: 12)

            Spacer()

            Text(containers.first { $0.id == selectedContainerId }?.title ?? "Personal")
              .font(.system(size: 13, weight: .medium))

            Spacer()

            Image(systemName: isDropdownOpen ? "chevron.up" : "chevron.down")
              .frame(width: 12, height: 12)
          }
          .foregroundColor(.secondary)
          .padding(8)
          .background(
            Color.adaptiveBackground(for: colorScheme).opacity(0.8)
          )
          .cornerRadius(8)
        }
        .buttonStyle(.plain)
        NewContainerButton(action: {})
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDropdownOpen)
  }
}

struct ContainerDropdown: View {
  let containers: [ContainerData]
  @Binding var selectedContainerId: String
  @Binding var isDropdownOpen: Bool
  let colorScheme: ColorScheme

  var body: some View {
    VStack(spacing: 2) {
      ForEach(containers) { container in
        ContainerButton(
          container: container,
          isSelected: selectedContainerId == container.id,
          action: {
            selectedContainerId = container.id
            isDropdownOpen = false
          }
        )
      }
    }
    .padding(.top, 4)
    .padding(.horizontal, 4)
    .background(Color.adaptiveBackground(for: colorScheme).opacity(0.4))
    .cornerRadius(10)
    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
  }
}

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

struct TabItem: View {
  let tab: TabData
  let isSelected: Bool
  let isDragging: Bool
  let onTap: () -> Void
  let onPinToggle: () -> Void
  let onFavoriteToggle: () -> Void
  let onClose: () -> Void
  let onMoveToContainer: (String) -> Void
  let availableContainers: [ContainerData]
  let selectedContainerId: String

  @Environment(\.colorScheme) var colorScheme
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
  let isSelected: Bool?
  let action: () -> Void

  init(container: ContainerData, isSelected: Bool? = nil, action: @escaping () -> Void) {
    self.container = container
    self.isSelected = isSelected
    self.action = action
  }

  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: container.icon)
          .frame(width: 12, height: 12)

        Spacer()

        Text(container.title)
          .font(.system(size: 13, weight: .medium))

        Spacer()

        if isSelected == nil {
          Image(systemName: "chevron.down")
            .frame(width: 12, height: 12)
        } else if isSelected == true {
          Image(systemName: "checkmark")
            .frame(width: 12, height: 12)
        }
      }
      .foregroundColor(.secondary)
      .padding(8)
      .background(
        isSelected == true ? Color.adaptiveBackground(for: colorScheme).opacity(0.8) : .clear
      )
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
  }
}

struct NewContainerButton: View {
  let action: () -> Void

  @State private var isHovering = false
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    Button(action: action) {
      Image(systemName: "plus")
        .frame(width: 12, height: 12)
        .foregroundColor(.secondary)
        .padding(8)
        .background(isHovering ? Color.adaptiveBackground(for: colorScheme).opacity(0.3) : .clear)
        .cornerRadius(10)
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
  }
}

struct FavoriteTabButton: View {
  let tab: TabData
  let isSelected: Bool
  let isDragging: Bool
  let onTap: () -> Void
  let onFavoriteToggle: () -> Void
  let onClose: () -> Void
  let onMoveToContainer: (String) -> Void
  let availableContainers: [ContainerData]
  let selectedContainerId: String

  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    ZStack {
      Image(systemName: tab.icon)
        .frame(width: 16, height: 16)
    }
    .foregroundColor(Color.adaptiveText(for: colorScheme))
    .frame(height: 48)
    .frame(maxWidth: .infinity)
    .background(
      isSelected
        ? Color.adaptiveBackground(for: colorScheme) : Color.mutedBackground(for: colorScheme)
    )
    .cornerRadius(10)
    .opacity(isDragging ? 0.0 : 1.0)
    .onTapGesture(perform: onTap)
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

enum TabSection {
  case favorites
  case pinned
  case regular
}

struct TabDropDelegate: DropDelegate {
  let item: TabData
  @Binding var containers: [ContainerData]
  let selectedContainerId: String
  @Binding var draggedItem: String?
  let targetSection: TabSection

  func dropEntered(info: DropInfo) {
    guard let provider = info.itemProviders(for: [.text]).first else { return }

    provider.loadObject(ofClass: NSString.self) { object, _ in
      guard let fromId = object as? String else { return }

      DispatchQueue.main.async {
        guard let containerIndex = containers.firstIndex(where: { $0.id == selectedContainerId }),
          let fromIndex = containers[containerIndex].tabs.firstIndex(where: { $0.id == fromId }),
          let toIndex = containers[containerIndex].tabs.firstIndex(where: { $0.id == item.id }),
          fromId != item.id
        else { return }

        if isInSameSection(containerIndex: containerIndex, fromId: fromId, toId: item.id) {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containers[containerIndex].tabs.move(
              fromOffsets: IndexSet(integer: fromIndex),
              toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
          }
        } else {
          moveTabBetweenSections(
            containerIndex: containerIndex, fromId: fromId, toSection: targetSection)
        }
      }
    }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    .init(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggedItem = nil
    return true
  }

  private func isInSameSection(containerIndex: Int, fromId: String, toId: String) -> Bool {
    let tabs = containers[containerIndex].tabs

    guard let fromTab = tabs.first(where: { $0.id == fromId }),
      let toTab = tabs.first(where: { $0.id == toId })
    else { return false }

    return section(for: fromTab) == section(for: toTab)
  }

  private func section(for tab: TabData) -> TabSection {
    if tab.isFavorite { return .favorites }
    if tab.isPinned { return .pinned }
    return .regular
  }

  private func moveTabBetweenSections(containerIndex: Int, fromId: String, toSection: TabSection) {
    var tabs = containers[containerIndex].tabs

    guard let fromIndex = tabs.firstIndex(where: { $0.id == fromId }) else { return }

    var tab = tabs.remove(at: fromIndex)
    tab.isFavorite = (toSection == .favorites)
    tab.isPinned = (toSection == .pinned)

    tabs.insert(tab, at: 0)

    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
      containers[containerIndex].tabs = tabs
    }
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
