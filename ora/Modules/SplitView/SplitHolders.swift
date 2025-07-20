//
//  SplitHolders.swift
//  SplitView
//
//  Created by Steven Harris on 2/8/23.
//

import Foundation

/// An ObservableObject that `Split` view observes to change what its `layout` is.
///
/// Use the static `usingUserDefaults` method to save state automatically in `UserDefaults.standard`.
public class LayoutHolder: ObservableObject {
    @Published public var value: SplitLayout {
        didSet {
            setter?(value)
        }
    }
    public var getter: (()->SplitLayout)?
    public var setter: ((SplitLayout)->Void)?
    
    public var isHorizontal: Bool { value == .horizontal }
    
    public init(_ layout: SplitLayout? = nil, getter: (()->SplitLayout)? = nil, setter: ((SplitLayout)->Void)? = nil) {
        value = getter?() ?? layout ?? .horizontal
        self.getter = getter
        self.setter = setter
    }

    public static func usingUserDefaults(_ layout: SplitLayout? = nil, key: String) -> LayoutHolder {
            LayoutHolder(
                layout,
            getter: {
                guard
                    let value = UserDefaults.standard.value(forKey: key) as? String,
                    let layout = SplitLayout(rawValue: value)
                else {
                    return .horizontal
                }
                return layout
            },
            setter: { layout in
                UserDefaults.standard.set(layout.rawValue, forKey: key)
            }
        )
    }
    
    public func toggle() {
        value = value == .horizontal ? .vertical : .horizontal
    }

}

/// An ObservableObject that `Split` view observes to change what fraction of the width/height the `splitter`
/// will be positioned at upon open.
///
/// Use the static `usingUserDefaults` method to save state automatically in `UserDefaults.standard`.
public class FractionHolder: ObservableObject {
    @Published public var value: CGFloat {
        didSet {
            setter?(value)
        }
    }
    public var getter: (()->CGFloat)?
    public var setter: ((CGFloat)->Void)?
    
    public init(_ fraction: CGFloat? = nil, getter: (()->CGFloat)? = nil, setter: ((CGFloat)->Void)? = nil) {
        value = getter?() ?? fraction ?? 0.5
        self.getter = getter
        self.setter = setter
    }

    public static func usingUserDefaults(_ fraction: CGFloat? = nil, key: String) -> FractionHolder {
        FractionHolder(
            fraction,
            getter: { UserDefaults.standard.value(forKey: key) as? CGFloat ?? fraction ?? 0.5 },
            setter: { fraction in UserDefaults.standard.set(fraction, forKey: key) }
        )
    }
}

/// An ObservableObject that `Split` view observes to change whether  one of the `SplitSide`s is hidden.
///
/// Use the static `usingUserDefaults` method to save state automatically in `UserDefaults.standard`.
public class SideHolder: ObservableObject {
    @Published private var value: SplitSide? {
        didSet {
            setter?(value)
        }
    }
    public var getter: (()->SplitSide?)?
    public var setter: ((SplitSide?)->Void)?
    public var side: SplitSide? {
        get { value }
        set { setValue(newValue) }
    }
    public var oldSide: SplitSide? { oldValue }
    private var oldValue: SplitSide?
    
    public init(_ hide: SplitSide? = nil, getter: (()->SplitSide?)? = nil, setter: ((SplitSide?)->Void)? = nil) {
        let value = getter?() ?? hide
        self.value = value
        self.getter = getter
        self.setter = setter
        // Note .secondary will always toggle() by default if hide is initially nil.
        // If you want to toggle .primary when hide is initially nil, then use toggle(.primary)
        // or toggle(.left) or toggle(.top). See discussion below in the toggle method.
        oldValue = value == nil ? .secondary : nil
    }
    
    /// Hide the `side`.
    public func hide(_ side: SplitSide) {
        setValue(side)
    }
    
    /// Toggle whether `side` is hidden or not. 
    ///
    /// For example, multiple invocations of `toggle(.primary)` will alternate between the
    /// `.primary`  (or `.left` or `.top`) side being hidden or visible.
    ///
    /// If `side` is not specified, then `toggle` does hide/show of the` .secondary` side or of the
    /// initially hidden `side` that was identified when the SideHolder was instantiated. Thus, you can use a
    /// SideHolder instantiated with `SideHolder()` and use `toggle()` to hide/show the `.secondary`
    /// side. If you want to hide/show the `.primary` side that will be initially visible, then you can use
    /// `SideHolder()` but hide/show using `toggle(.primary)`.
    public func toggle(_ side: SplitSide? = nil) {
        guard let side else {
            setValue(oldValue)
            return
        }
        if (side.isPrimary && value.isPrimary) || (side.isSecondary && value.isSecondary) {
            setValue(oldValue)
        } else {
            setValue(side)
        }
    }
    
    private func setValue(_ side: SplitSide?) {
        guard value != side else { return }
        let oldSide = value
        value = side
        oldValue = oldSide
    }
    
    public static func usingUserDefaults(_ hide: SplitSide? = nil, key: String) -> SideHolder {
        SideHolder(
            hide,
            getter: {
                guard
                    let value = UserDefaults.standard.value(forKey: key) as? String,
                    let side = SplitSide(rawValue: value)
                else {
                    return nil
                }
                return side
            },
            setter: { side in
                UserDefaults.standard.set(side?.rawValue, forKey: key)
            }
        )
    }
}
