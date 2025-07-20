//
//  SplitConstraints.swift
//  SplitView
//
//  Created by Steven Harris on 2/13/23.
//

import SwiftUI

public struct SplitConstraints {
    /// The minimum fraction that the primary view will be constrained within. A value of `nil` means unconstrained.
    var minPFraction: CGFloat?
    /// The minimum fraction that the secondary view will be constrained within. A value of `nil` means unconstrained.
    var minSFraction: CGFloat?
    /// The side that should have sizing priority (i.e., stay fixed) as the containing view is resized. A value of `nil` means the fraction remains unchanged.
    var priority: SplitSide?
    /// Whether to hide the primary side when dragging stops past minPFraction
    var dragToHideP: Bool
    /// Whether to hide the secondary side when dragging stops past minSFraction
    var dragToHideS: Bool
    
    public init(minPFraction: CGFloat? = nil, minSFraction: CGFloat? = nil, priority: SplitSide? = nil, dragToHideP: Bool = false, dragToHideS: Bool = false) {
        self.minPFraction = minPFraction
        self.minSFraction = minSFraction
        self.priority = priority
        // Note: minPFraction/minSFraction must be specified if dragToHideP/dragToHideS is true,
        // else dragToHideP/dragToHideS are ignored.
        self.dragToHideP = dragToHideP
        self.dragToHideS = dragToHideS
    }
}
