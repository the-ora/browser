//
//  HSplit.swift
//  SplitView
//
//  Created by Steven Harris on 3/1/23.
//

import SwiftUI

@MainActor
public struct HSplit<P: View, D: SplitDivider, S: View>: View {
    private let fraction: FractionHolder
    private let hide: SideHolder
    private let constraints: SplitConstraints
    private let onDrag: ((CGFloat)->Void)?
    private let primary: P
    private let splitter: D
    private let secondary: S
    
    public var body: some View {
        Split(primary: { primary }, secondary: { secondary })
            .layout(LayoutHolder(.horizontal))
            .constraints(constraints)
            .onDrag(onDrag)
            .splitter { splitter }
            .fraction(fraction)
            .hide(hide)
    }
    
    public init(@ViewBuilder left: @escaping ()->P, @ViewBuilder right: @escaping ()->S) where D == Splitter {
        let fraction = FractionHolder()
        let hide = SideHolder()
        let constraints = SplitConstraints()
        self.init(fraction: fraction, hide: hide, constraints: constraints, onDrag: nil, primary: { left() }, splitter: { D() }, secondary: { right() })
    }
    
    private init(fraction: FractionHolder, hide: SideHolder, constraints: SplitConstraints, onDrag: ((CGFloat)->Void)?, @ViewBuilder primary: @escaping ()->P, @ViewBuilder splitter: @escaping ()->D, @ViewBuilder secondary: @escaping ()->S) {
        self.fraction = fraction
        self.hide = hide
        self.constraints = constraints
        self.onDrag = onDrag
        self.primary = primary()
        self.splitter = splitter()
        self.secondary = secondary()
    }
    
    //MARK: Modifiers
    
    // Note: Modifiers return a new HSplit instance with the same state except for what is
    // being modified.
    
    /// Return a new HSplit with the `splitter` set to the `splitter` passed-in.
    public func splitter<T>(@ViewBuilder _ splitter: @escaping ()->T) -> HSplit<P, T, S> where T: View {
        return HSplit<P, T, S>(fraction: fraction, hide: hide, constraints: constraints, onDrag: onDrag, primary: { primary }, splitter: splitter, secondary: { secondary })
    }
    
    /// Return a new instance of HSplit with `constraints` set to these values.
    public func constraints(minPFraction: CGFloat? = nil, minSFraction: CGFloat? = nil, priority: SplitSide? = nil, dragToHideP: Bool = false, dragToHideS: Bool = false) -> HSplit {
        let constraints = SplitConstraints(minPFraction: minPFraction, minSFraction: minSFraction, priority: priority, dragToHideP: dragToHideP, dragToHideS: dragToHideS)
        return HSplit(fraction: fraction, hide: hide, constraints: constraints, onDrag: onDrag, primary: { primary }, splitter: { splitter }, secondary: { secondary })
    }
    
    /// Return a new instance of HSplit with `onDrag` set to `callback`.
    ///
    /// The `callback` will be executed as `splitter` is dragged, with the current value of `privateFraction`.
    /// Note that `fraction` is different. It is only set when drag ends, and it is used to determine the initial fraction at open.
    public func onDrag(_ callback: ((CGFloat)->Void)?) -> HSplit {
        return HSplit(fraction: fraction, hide: hide, constraints: constraints, onDrag: callback, primary: { primary }, splitter: { splitter }, secondary: { secondary })
    }
    
    /// Return a new instance of HSplit with its `splitter.styling` set to these values.
    public func styling(color: Color? = nil, inset: CGFloat? = nil, visibleThickness: CGFloat? = nil, invisibleThickness: CGFloat? = nil, hideSplitter: Bool = false) -> HSplit {
        let styling = SplitStyling(color: color, inset: inset, visibleThickness: visibleThickness, invisibleThickness: invisibleThickness, hideSplitter: hideSplitter)
        splitter.styling.reset(from: styling)
        return HSplit(fraction: fraction, hide: hide, constraints: constraints, onDrag: onDrag, primary: { primary }, splitter: { splitter }, secondary: { secondary })
    }
    
    /// Return a new instance of HSplit with `fraction` set to this FractionHolder
    public func fraction(_ fraction: FractionHolder) -> HSplit<P, D, S> {
        HSplit(fraction: fraction, hide: hide, constraints: constraints, onDrag: onDrag, primary: { primary }, splitter: { splitter }, secondary: { secondary })
    }
    
    /// Return a new instance of HSplit with `fraction` set to a FractionHolder holding onto this CGFloat
    public func fraction(_ fraction: CGFloat) -> HSplit<P, D, S> {
        self.fraction(FractionHolder(fraction))
    }

    /// Return a new instance of HSplit with `hide` set to this SideHolder
    public func hide(_ side: SideHolder) -> HSplit<P, D, S> {
        HSplit(fraction: fraction, hide: side, constraints: constraints, onDrag: onDrag, primary: { primary }, splitter: { splitter }, secondary: { secondary })
    }
    
    /// Return a new instance of HSplit with `hide` set to a SideHolder holding onto this SplitSide
    public func hide(_ side: SplitSide) -> HSplit<P, D, S> {
        self.hide(SideHolder(side))
    }
    
}

struct HSplit_Previews: PreviewProvider {
    static var previews: some View {
        HSplit(
            left: { Color.green },
            right: {
                VSplit(
                    top: { Color.red },
                    bottom: {
                        HSplit(
                            left: { Color.blue },
                            right: { Color.yellow }
                        )
                    }
                )
            }
        )
        
        HSplit(
            left: {
                VSplit(top: { Color.red }, bottom: { Color.green })
            },
            right: {
                VSplit(top: { Color.yellow }, bottom: { Color.blue })
            }
        )
    }
}
