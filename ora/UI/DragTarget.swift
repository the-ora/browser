//
//  DragTarget.swift
//  ora
//
//  Created by Jack Hogan on 28/10/25.
//

import SwiftUI

struct DragTarget: View {
    @Environment(\.theme) private var theme: Theme
    let tab: Tab
    @Binding var draggedItem: UUID?
    @Binding var targetedDropItem: TargetedDropItem?
    var body: some View {
        HStack {
            ConditionallyConcentricRectangle(cornerRadius: 10)
                .stroke(
                    theme.accent,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                .overlay {
                    Image(systemName: "arrow.down.to.line")
                        .bold()
                }
                .onDrop(
                    of: [.text],
                    delegate: TabDropDelegate(
                        item: tab,
                        representative:
                        .tab(tabset: false), draggedItem: $draggedItem,
                        targetedItem: $targetedDropItem,
                        targetSection: .normal
                    )
                )
            ConditionallyConcentricRectangle(cornerRadius: 10)
                .stroke(
                    theme.accent,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                .overlay {
                    Image(systemName: "arrow.forward.to.line")
                        .bold()
                }
                .onDrop(
                    of: [.text],
                    delegate: TabDropDelegate(
                        item: tab,
                        representative:
                        .tab(tabset: true), draggedItem: $draggedItem,
                        targetedItem: $targetedDropItem,
                        targetSection: .normal
                    )
                )
        }
        .background {
            ConditionallyConcentricRectangle(cornerRadius: 10)
                .fill(.thickMaterial)
        }
    }
}
