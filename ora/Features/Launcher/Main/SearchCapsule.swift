import AppKit
import SwiftUI

struct SearchEngineCapsule: View {
    let text: String
    let color: Color
    let foregroundColor: Color
    let icon: String
    let favicon: NSImage?
    let faviconBackgroundColor: Color?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else if icon.isEmpty {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(foregroundColor)
            } else {
                Image(icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(foregroundColor)
            }
            Text(text)
                .font(.callout)
                .bold()
                .foregroundStyle(foregroundColor)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(alignment: .leading)
        .background(faviconBackgroundColor ?? color)
        .cornerRadius(99)
    }
}
