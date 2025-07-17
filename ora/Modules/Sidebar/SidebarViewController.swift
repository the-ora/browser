import SwiftUI
import SwiftData

// MARK: - Sidebar
struct Sidebar: View {
    @EnvironmentObject var tabManager: TabManager
    @Binding var isSidebarVisible: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""
    // Must specify the root type explicitly
    var body: some View {

        VStack(spacing: 0) {
            
            // Top section with search and profile
                VStack(spacing: 16) {
                    // Profile section
                    HStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("U")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            )
    
                        Spacer()
    
                        Button(action: {
                            if let container = tabManager.activeContainer {
                                _ = tabManager.addTab(container: container)
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
    
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
    
                        TextField("Search tabs...", text: $searchText)
                            .font(.system(size: 13))
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            // Tabs section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Pinned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                

                if let container = tabManager.activeContainer {
                    Text(
                        "Container: \(container.emoji) \(container.name)"
                    )
                }
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(
                                tabManager.activeContainer?.tabs
                                    .sorted(by: { $0.createdAt > $1.createdAt }) ?? []
                            ) { tab in
                                TabItem(
                                    tab: tab,
                                    isSelected: tabManager.isActive(tab),
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            tabManager.activateTab(tab)
                                        }
                                    },
                                    onClose: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            tabManager.closeTab(tab: tab)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            
            
            Spacer()
            
            // Bottom section
            VStack(spacing: 12) {
                Divider()
                    .opacity(0.3)
                
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 280)
    }
} 
