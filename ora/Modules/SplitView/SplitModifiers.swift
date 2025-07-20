//
//  SplitModifiers.swift
//  SplitView
//
//  Created by Steven Harris on 2/2/23.
//

import SwiftUI

/// A ViewModifier to split Content with `secondary` in the SplitLayout direction held by `layout` direction.
///
/// The views are separated by a draggable Splitter.
///
/// Other customization after using this modifier (e.g., `fraction`, `hide`, `styling`, `constraints`, `splitter`) are done using
/// those separate modifiers on the Split instance returned from this modifier.
public struct SplitModifier<S: View>: ViewModifier {
    let layout: LayoutHolder
    let secondary: ()->S
    
    public func body(content: Content) -> some View {
        Split(primary: {content}, secondary: secondary)
            .layout(layout)
    }
    
    public init(_ layout: LayoutHolder, @ViewBuilder secondary: @escaping (()->S)) {
        self.layout = layout
        self.secondary = secondary
    }
}

/// A ViewModifier to split Content horizontally with `secondary`.
///
/// The views are separated by a draggable Splitter.
///
/// Other customization after using this modifier (e.g., `fraction`, `hide`, `styling`, `constraints`, `splitter`) are done using
/// those separate modifiers on the HSplit instance returned from this modifier.
public struct HSplitModifier<S: View>: ViewModifier {
    let secondary: ()->S
    
    public func body(content: Content) -> some View {
        HSplit(left: {content}, right: secondary)
    }
    
    public init(@ViewBuilder secondary: @escaping (()->S)) {
        self.secondary = secondary
    }
}

/// A ViewModifier to split Content vertically with `secondary`.
///
/// The views are separated by a draggable Splitter.
///
/// Other customization after using this modifier (e.g., `fraction`, `hide`, `styling`, `constraints`, `splitter`) are done using
/// those separate modifiers on the VSplit instance returned from this modifier.
public struct VSplitModifier<S: View>: ViewModifier {
    let secondary: ()->S
    
    public func body(content: Content) -> some View {
        VSplit(top: {content}, bottom: secondary)
    }
    
    public init(@ViewBuilder secondary: @escaping (()->S)) {
        self.secondary = secondary
    }
}

extension View {
    
    /// Return an instance of Split in the SplitLayout direction held by `layout`, with a Splitter separating this `primary` View and `secondary`.
    public func split(_ layout: LayoutHolder, @ViewBuilder secondary: @escaping (()->some View)) -> some View {
        modifier(SplitModifier(layout, secondary: secondary))
    }
    
    /// Return an instance of Split in `layout` direction, with a Splitter separating this `primary` View and `secondary`.
    public func split(_ layout: SplitLayout, @ViewBuilder secondary: @escaping (()->some View)) -> some View {
        split(LayoutHolder(layout), secondary: secondary)
    }
    
    /// Return an instance of Split in `.horizontal` direction, with a Splitter separating this `primary` View and `secondary`.
    public func split(@ViewBuilder secondary: @escaping (()->some View)) -> some View {
        split(LayoutHolder(.horizontal), secondary: secondary)
    }
    
    /// Return an instance of HSplit with a Splitter separating this `primary` View and `secondary`.
    public func hSplit(@ViewBuilder secondary: @escaping (()->some View)) -> some View {
        modifier(HSplitModifier(secondary: secondary))
    }

    /// Return an instance of VSplit with a Splitter separating this `primary` View and `secondary`.
    public func vSplit(@ViewBuilder secondary: @escaping (()->some View)) -> some View {
        modifier(VSplitModifier(secondary: secondary))
    }
    
}
