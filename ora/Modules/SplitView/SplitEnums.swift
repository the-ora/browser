//
//  SplitEnums.swift
//  SplitView
//
//  Created by Steven Harris on 1/31/23.
//

import Foundation

/// The orientation of the `primary` and `secondary` views (e.g., Vertical = VStack, Horizontal = HStack)
public enum SplitLayout: String, CaseIterable {
    case horizontal
    case vertical
}

/// The two sides of a SplitView.
///
/// Use `isPrimary` and `isSecondary` rather than accessing the cases directly.
///
/// For `SplitLayout.horizontal`, `primary` is left, `secondary` is right.
/// For `SplitLayout.vertical`, `primary` is top, `secondary` is bottom.
///
/// For convenience and clarity when creating and constraining an HSplit view, you can use
/// `left` and `right` instead of `primary` and `secondary`. Similarly you can
/// use `top` and `bottom` when creating and constraining a VSplit view.
public enum SplitSide: String {
    case primary
    case secondary
    case left
    case right
    case top
    case bottom
    
    public var isPrimary: Bool { self == .primary || self == .left || self == .top }
    public var isSecondary: Bool { self == .secondary || self == .right || self == .bottom }
}

/// A SplitSide is generally optional. If so, then if nil, it is neither primary nor secondary.
extension Optional where Wrapped == SplitSide {
    public var isPrimary: Bool { self == nil ? false : self!.isPrimary }
    public var isSecondary: Bool { self == nil ? false : self!.isSecondary }
}
