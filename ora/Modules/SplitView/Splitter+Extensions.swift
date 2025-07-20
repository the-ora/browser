//
//  Splitter+Extensions.swift
//  SplitView
//
//  This file is a place to hold generally useful extensions of Splitter. If you create one,
//  please add your name below to identify your extension, add it to this file, and submit
//  a pull request. Note that your custom Splitter should probably conform to SplitDivider.
//  Your custom splitter can get its layout from the LayoutHolder in the Environment or
//  directly as part of its initialization.
//
//  Created by Steven Harris on 2/16/23.
//
//  Extension authors:
//
//  Steven G. Harris created `line` and `invisible` extensions.
//

import SwiftUI

extension Splitter {
    
    /// A Splitter (that responds to changes in layout) that is a line across the full breadth of the view, by default gray and visibleThickness of 1
    public static func line(color: Color? = nil, visibleThickness: CGFloat? = nil) -> Splitter {
        return Splitter(color: color, inset: 0, visibleThickness: visibleThickness ?? 1)
    }
    
    /// An invisible Splitter (that responds to changes in layout) that is a line across the full breadth of the view
    public static func invisible() -> Splitter {
        Splitter.line(visibleThickness: 0)
    }

}
