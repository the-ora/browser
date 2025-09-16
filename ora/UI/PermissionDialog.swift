import SwiftUI

struct PermissionDialog: View {
    let request: PermissionRequest
    let onResponse: (Bool) -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and site info
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Permission icon with background
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: request.permissionType.iconName)
                            .font(.title2)
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.host)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("wants to \(request.permissionType.description.lowercased())")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }

                // Permission explanation
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.permissionType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(getPermissionExplanation())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Divider
            Divider()

            // Action buttons
            HStack(spacing: 0) {
                Button("Don't Allow") {
                    onResponse(false)
                }
                .buttonStyle(PermissionButtonStyle(isPrimary: false))
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 44)

                Button("Allow") {
                    onResponse(true)
                }
                .buttonStyle(PermissionButtonStyle(isPrimary: true))
                .frame(maxWidth: .infinity)
            }
            .frame(height: 44)
        }
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.15),
            radius: 20,
            x: 0,
            y: 8
        )
    }

    private func getPermissionExplanation() -> String {
        switch request.permissionType {
        case .camera:
            return "This allows the site to access your camera for video calls, photos, and other features."
        case .microphone:
            return "This allows the site to access your microphone for voice calls, recordings, and audio features."
        default:
            return "This allows the site to use \(request.permissionType.displayName.lowercased()) functionality."
        }
    }
}

struct PermissionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: isPrimary ? .semibold : .medium))
            .foregroundColor(
                isPrimary
                    ? .white
                    : (colorScheme == .dark ? .white : .black)
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                isPrimary
                    ? Color.blue
                    : Color.clear
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PermissionDialogOverlay: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            if permissionManager.showPermissionDialog, let request = permissionManager.pendingRequest {
                // Background overlay with blur effect
                ZStack {
                    Color.black.opacity(colorScheme == .dark ? 0.6 : 0.4)
                        .ignoresSafeArea()

                    // Subtle blur effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .opacity(0.3)
                }
                .onTapGesture {
                    // Dismiss on background tap (deny permission)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        permissionManager.handlePermissionResponse(allow: false)
                    }
                }

                // Permission dialog
                PermissionDialog(request: request) { allow in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        permissionManager.handlePermissionResponse(allow: allow)
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: permissionManager.showPermissionDialog)
    }
}
