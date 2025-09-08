import SwiftUI

struct AudioTooltip: Equatable {
    let rect: CGRect   // in global coordinates
    let text: String
}

struct AudioTooltipPreferenceKey: PreferenceKey {
    static var defaultValue: AudioTooltip?
    static func reduce(value: inout AudioTooltip?, nextValue: () -> AudioTooltip?) {
        if let next = nextValue() {
            value = next
        }
    }
}
