import Foundation

class BrowserEngineProfile {
    let identifier: UUID
    let isPrivate: Bool
    let engineKind: BrowserEngineKind

    init(identifier: UUID, isPrivate: Bool, engineKind: BrowserEngineKind) {
        self.identifier = identifier
        self.isPrivate = isPrivate
        self.engineKind = engineKind
    }

    func clearData(
        ofTypes types: Set<BrowserWebsiteDataType>,
        forHost host: String? = nil,
        completion: (() -> Void)? = nil
    ) {
        completion?()
    }
}
