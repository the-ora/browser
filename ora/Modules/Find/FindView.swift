//
//  FindWebView.swift
//  ora
//
//  Created by keni on 7/28/25.
//

import SwiftUI
import WebKit

struct FindView: View {
    @State private var searchText = ""
    @State private var matchCount = 0
    @State private var currentMatch = 0
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject private var appState: AppState
    @Environment(\.theme) var theme
    @Environment(\.colorScheme) var colorScheme
    private let controller: FindController
    
    init(webView: WKWebView) {
        self.controller = FindController(webView: webView)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            searchIcon
            searchTextField
            matchCounter
            navigationButtons
            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundView)
        .cornerRadius(16)
        .overlay(borderView)
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.15),
            radius: 12,
            x: 0,
            y: 4
        )
        .onAppear {
            DispatchQueue.main.async {
                controller.injectMarkJS()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isTextFieldFocused = true
            }
        }
    }
    
    @ViewBuilder
    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
    }
    
    @ViewBuilder
    private var searchTextField: some View {
        TextField("Find in page", text: $searchText)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 200)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(textFieldBackground)
            .foregroundColor(theme.foreground)
            .cornerRadius(6)
            .overlay(textFieldBorder)
            .focused($isTextFieldFocused)
            .onChange(of: searchText) { oldValue, newValue in
                Task { @MainActor in
                    handleSearchTextChange(newValue)
                }
            }
            .onSubmit {
                Task { @MainActor in
                    handleSearchSubmit()
                }
            }
            .onKeyPress(.escape) {
                Task { @MainActor in
                    handleEscapeKey()
                }
                return .handled
            }
    }
    
    @ViewBuilder
    private var textFieldBackground: some View {
        Rectangle()
            .fill(theme.mutedBackground)
    }
    
    @ViewBuilder
    private var textFieldBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(
                isTextFieldFocused 
                    ? theme.foreground
                    : theme.border, 
                lineWidth: isTextFieldFocused ? 2 : 1
            )
    }
    
    @ViewBuilder
    private var matchCounter: some View {
        // Fixed width container to prevent jumping
        HStack {
            if !searchText.isEmpty {
                if matchCount > 0 {
                    matchCounterBadge
                } else {
                    noMatchesBadge
                }
            } else {
                // Invisible placeholder to maintain layout
                Text("")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .frame(minWidth: 80) // Fixed minimum width
    }
    
    @ViewBuilder
    private var matchCounterBadge: some View {
        HStack(spacing: 3) {
            Text("\(currentMatch)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit() // Prevents width changes when numbers change
            Text("/")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            Text("\(matchCount)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .monospacedDigit() // Prevents width changes when numbers change
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.blue.opacity(0.8)))
    }
    
    @ViewBuilder
    private var noMatchesBadge: some View {
        Text("No matches")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.red.opacity(0.7)))
    }
    
    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 2) {
            previousButton
            buttonSeparator
            nextButton
        }
        .background(navigationButtonsBackground)
    }
    
    @ViewBuilder
    private var previousButton: some View {
        Button(action: {
            Task { @MainActor in
                controller.previousMatch()
                updateCurrentMatch()
            }
        }) {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .disabled(searchText.isEmpty || matchCount == 0)
        .buttonStyle(EnhancedFindButtonStyle(
            colorScheme: colorScheme,
            isEnabled: !(searchText.isEmpty || matchCount == 0)
        ))
    }
    
    @ViewBuilder
    private var nextButton: some View {
        Button(action: {
            Task { @MainActor in
                controller.nextMatch()
                updateCurrentMatch()
            }
        }) {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .disabled(searchText.isEmpty || matchCount == 0)
        .buttonStyle(EnhancedFindButtonStyle(
            colorScheme: colorScheme,
            isEnabled: !(searchText.isEmpty || matchCount == 0)
        ))
    }
    
    @ViewBuilder
    private var buttonSeparator: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 20)
    }
    
    @ViewBuilder
    private var navigationButtonsBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var closeButton: some View {
        Button(action: {
            Task { @MainActor in
                controller.clearMatches()
                appState.showFinderIn = nil
            }
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(
                        colorScheme == .dark 
                            ? Color.black.opacity(0.3)
                            : Color.white.opacity(0.7)
                    )
            )
    }
    
    @ViewBuilder
    private var borderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                colorScheme == .dark 
                    ? Color.white.opacity(0.2)
                    : Color.black.opacity(0.1),
                lineWidth: 1
            )
    }
    
    // MARK: - Action Handlers
    
    private func handleSearchTextChange(_ newValue: String) {
        if !newValue.isEmpty {
            controller.highlight(newValue)
            updateMatchCount()
        } else {
            controller.clearMatches()
            matchCount = 0
            currentMatch = 0
        }
    }
    
    private func handleSearchSubmit() {
        if !searchText.isEmpty {
            controller.nextMatch()
            updateCurrentMatch()
        }
    }
    
    private func handleEscapeKey() {
        controller.clearMatches()
        appState.showFinderIn = nil
    }
    
    private func updateMatchCount() {
        controller.getMatchInfo { current, total in
            DispatchQueue.main.async {
                self.currentMatch = current
                self.matchCount = total
            }
        }
    }
    
    private func updateCurrentMatch() {
        controller.getMatchInfo { current, total in
            DispatchQueue.main.async {
                self.currentMatch = current
                self.matchCount = total
            }
        }
    }
}

struct EnhancedFindButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme
    let isEnabled: Bool
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(buttonForegroundColor(configuration))
            .background(buttonBackgroundColor(configuration))
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                if isEnabled {
                    isHovering = hovering
                }
            }
    }
    
    private func buttonForegroundColor(_ configuration: Configuration) -> Color {
        if !isEnabled {
            return colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3)
        } else if configuration.isPressed {
            return colorScheme == .dark ? .white : .black
        } else if isHovering {
            return colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8)
        } else {
            return colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
        }
    }
    
    private func buttonBackgroundColor(_ configuration: Configuration) -> Color {
        if !isEnabled {
            return Color.clear
        } else if configuration.isPressed {
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
        } else if isHovering {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}
