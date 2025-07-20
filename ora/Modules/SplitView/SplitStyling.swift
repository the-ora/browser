//
//  SplitStyling.swift
//  SplitView
//
//  Created by Steven Harris on 3/6/23.
//

import SwiftUI

@MainActor
public class SplitStyling: ObservableObject {
    /// Color of the visible part of the default Splitter.
    public var color: Color
    /// The inset for the visible part of the default Splitter from the ends it reaches to.
    public var inset: CGFloat
    /// The visible thickness of the default Splitter and the `spacing` between the `primary` and `secondary` views.
    public var visibleThickness: CGFloat
    /// The thickness across which the dragging will be detected.
    public var invisibleThickness: CGFloat
    /// Whether to hide the splitter along with the side when SplitSide is set.
    public var hideSplitter: Bool
    /// Whether we are previewing what hiding will look like.
    @Published public var previewHide: Bool
    
    public init(color: Color? = nil, inset: CGFloat? = nil, visibleThickness: CGFloat? = nil, invisibleThickness: CGFloat? = nil, hideSplitter: Bool = false) {
        self.color = color ?? Splitter.defaultColor
        self.inset = inset ?? Splitter.defaultInset
        self.visibleThickness = visibleThickness ?? Splitter.defaultVisibleThickness
        self.invisibleThickness = invisibleThickness ?? Splitter.defaultInvisibleThickness
        self.hideSplitter = hideSplitter
        self.previewHide = false        // We never start out previewing
    }
    
    /// As an ObservableObject, when we want to change to a different SplitStyling, we need to just modify the properties of this instance.
    public func reset(from styling: SplitStyling) {
        color = styling.color
        inset = styling.inset
        visibleThickness = styling.visibleThickness
        invisibleThickness = styling.invisibleThickness
        hideSplitter = styling.hideSplitter
        previewHide = styling.previewHide
    }
}
