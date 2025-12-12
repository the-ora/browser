//
//  DropCapsule.swift
//  ora
//
//  Created by Jack Hogan on 29/10/25.
//

import SwiftUI

struct DropCapsule: View {
    @Environment(\.theme) private var theme
    let id: UUID
    @Binding var targetedDropItem: TargetedDropItem?
    @Binding var draggedItem: UUID?
    let delegate: DropDelegate

    var body: some View {
        Capsule()
            .frame(height: 5)
            .foregroundStyle(theme.accent)
            .opacity(targetedDropItem?
                .imTargeted(withMyIdBeing: id, andType: .divider) ?? false ? 0.75 : 0.0)
            .onDrop(
                of: [.text],
                delegate: delegate
            )
    }
}
