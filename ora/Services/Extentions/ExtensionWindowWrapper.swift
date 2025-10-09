import WebKit
import Foundation

final class ExtensionWindowWrapper: NSObject, WKWebExtensionWindow {
    let id: Int
    
    init(id: Int) {
        self.id = id
        super.init()
        print("[ExtWindow] init id=\(id)")
    }
    
    deinit {
        print("[ExtWindow] deinit id=\(id)")
    }
}



