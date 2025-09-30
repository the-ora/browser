//
//  DefaultBrowserManager.swift
//  ora
//
//  Created by keni on 9/30/25.
//


import CoreServices
import AppKit

enum DefaultBrowserManager {
    static var isDefault: Bool {
        guard let testURL = URL(string: "http://example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: testURL),
              let appBundle = Bundle(url: appURL) else {
            return false
        }
        
        return appBundle.bundleIdentifier == Bundle.main.bundleIdentifier
    }
    
    static func requestSetAsDefault() {
        let bundleID = Bundle.main.bundleIdentifier! as CFString
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleID)
    }
}
