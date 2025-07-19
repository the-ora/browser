import SwiftUI

struct SearchEngineCapsule: View {
  let text: String
  let color: Color
  let foregroundColor: Color
  let icon: String

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      if icon.isEmpty {
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
    .background(color)
    .cornerRadius(99)
  }
}