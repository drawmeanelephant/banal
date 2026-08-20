import AppIntents
import BANALCore
import CoreSpotlight
import Foundation

/// App-level Spotlight helpers for navigation and user activity handling.
public enum NoteSpotlightNavigation {
    /// Extracts the note ID from a CoreSpotlight user activity.
    public static func noteID(from userActivity: NSUserActivity) -> String? {
        guard userActivity.activityType == CSSearchableItemActionType else { return nil }
        return userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
    }
}
