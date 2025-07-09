import SwiftUI

// MARK: - Sidebar Tab Item
struct TabItem: View {
    @ObservedObject var tab: BrowserTab
    var isSelected: Bool
    var onSelect: () -> Void
    var onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Favicon or default icon
            faviconView
                .frame(width: 16, height: 16)
                .cornerRadius(4)
            

                Text(tab.title.isEmpty ? "New Tab" : tab.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            
            Spacer()
            
            // Close button or loading indicator
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else if (isHovering || isSelected) {
                closeButton
            }
        }
        .padding(.horizontal, isSelected ? 12 : 8)
        .padding(.vertical, 8)
        .background(backgroundView)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    @ViewBuilder
    private var faviconView: some View {
        Group {
            if let favicon = tab.favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.8),
                            Color.blue.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Text(String(tab.title.prefix(1).uppercased()))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    @ViewBuilder
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: isSelected ? 12 : 8)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: isSelected ? 12 : 8)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
        } else if isHovering {
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
        } else {
            return Color.clear
        }
    }
} 