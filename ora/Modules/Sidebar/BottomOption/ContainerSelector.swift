import SwiftUI
import SwiftData

struct ContainerSelector: View {


  @Binding var isDropdownOpen: Bool
  @Environment(\.theme) private var theme
    @EnvironmentObject var tabManger: TabManager
    

  var body: some View {
    VStack(spacing: 4) {
      if isDropdownOpen {
        ContainerDropdown(
          isDropdownOpen: $isDropdownOpen
        )
      }
      HStack {
          if let container = tabManger.activeContainer {
              Button(action: { isDropdownOpen.toggle() }) {
                  HStack(spacing: 4) {
                      Text(container.emoji)
                      
                      Spacer()
                      
                      Text(container.name)
                          .font(.system(size: 13, weight: .medium))
                      
                      Spacer()
                      
                      Image(systemName: isDropdownOpen ? "chevron.up" : "chevron.down")
                          .frame(width: 12, height: 12)
                  }
                  .foregroundColor(.secondary)
                  .padding(8)
                  .background(
                    theme.background.opacity(0.6)
                  )
                  .cornerRadius(8)
              }
              .buttonStyle(.plain)
          }
        NewContainerButton(action: {})
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDropdownOpen)
  }
}

struct ContainerDropdown: View {
  @Binding var isDropdownOpen: Bool
  @Environment(\.theme) private var theme
  @EnvironmentObject var tabManager: TabManager
  @Query var containers: [TabContainer]

  var body: some View {
    VStack(spacing: 2) {
      ForEach(containers) { container in
        ContainerButton(
          container: container,
          isSelected: tabManager.activeContainer?.id == container.id,
          action: {
              tabManager.activateContainer(container)
            isDropdownOpen = false
          }
        )
      }
    }
    .padding(.top, 4)
    .padding(.horizontal, 4)
    .background(theme.background.opacity(0.4))
    .cornerRadius(10)
    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
  }
}

struct ContainerButton: View {
    let container: TabContainer
  let isSelected: Bool?
  let action: () -> Void

    init(
        container: TabContainer,
        isSelected: Bool? = nil,
        action: @escaping () -> Void
    ) {
    self.container = container
    self.isSelected = isSelected
    self.action = action
  }

  @Environment(\.theme) private var theme

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
          Text(container.emoji)

        Spacer()

        Text(container.name)
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
        isSelected == true ? theme.background.opacity(0.8) : .clear
      )
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
  }
}
