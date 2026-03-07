import SwiftUI

func performHapticFeedback(pattern: NSHapticFeedbackManager.FeedbackPattern) {
    let manager = NSHapticFeedbackManager.defaultPerformer
    manager.perform(pattern, performanceTime: .drawCompleted)
}
