//
//  AppIconPicker.swift
//  ora
//
//  Created by $H!NDGEKYUME on 9/10/25.
//

import AppKit
import SwiftUI

enum AppIcon: String, CaseIterable, Identifiable {
    static let storageKey = "AppIcon"

    case `default`
    case dev

    var id: String { rawValue }

    var name: String {
        switch self {
        case .default: "OraIcon"
        case .dev: "OraIconDev"
        }
    }

    var image: NSImage {
        NSImage(named: name)!
    }

    static func applyPreferredAppIcon() {
        let storedValue = UserDefaults.standard.string(forKey: AppIcon.storageKey)
        let preferredIcon = storedValue.flatMap(AppIcon.init(rawValue:)) ?? .default
        NSApp.applicationIconImage = preferredIcon.image
    }
}

struct AppIconPicker: View {
    @AppStorage(AppIcon.storageKey) private var selected: AppIcon = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Icon")
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(AppIcon.allCases, id: \.self) { icon in
                    Image(nsImage: icon.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 64)
                        .onTapGesture {
                            selected = icon
                            NSApp.applicationIconImage = icon.image
                        }
                        .overlay(alignment: .bottom) {
                            if selected == icon {
                                Circle()
                                    .frame(width: 4)
                                    .padding(.bottom, -2)
                                    .alignmentGuide(.top) { $0.height }
                            }
                        }
                }
            }
            .padding(8)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    AppIconPicker()
}
