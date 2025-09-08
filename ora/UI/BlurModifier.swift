//
//  BlurModifier.swift
//  ora
//
//  Created by Aether on 9/7/25.
//

import SwiftUI

private struct BlurModifier: ViewModifier {
    public let isIdentity: Bool
    public var intensity: CGFloat

    public func body(content: Content) -> some View {
        content
            .blur(radius: isIdentity ? intensity : 0)
            .opacity(isIdentity ? 0 : 1)
    }
}

public extension AnyTransition {
    static var blur: AnyTransition {
        .blur()
    }

    static var blurSmooth: AnyTransition {
        .blur(scaleAnimation: Animation.bouncy)
    }

    static var blurWithoutScale: AnyTransition {
        .modifier(
            active: BlurModifier(isIdentity: true, intensity: 20),
            identity: BlurModifier(isIdentity: false, intensity: 20)
        )
    }

    static func blur(
        intensity: CGFloat = 5,
        scale: CGFloat = 0.8,
        scaleAnimation: Animation = .spring()
    ) -> AnyTransition {
        .scale(scale: scale)
            .animation(scaleAnimation)
            .combined(
                with: .modifier(
                    active: BlurModifier(isIdentity: true, intensity: intensity),
                    identity: BlurModifier(isIdentity: false, intensity: intensity)
                )
            )
    }
}
