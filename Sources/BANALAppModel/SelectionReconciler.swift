import Foundation

/// The list is the truth for selection (#213). When a folder, filter,
/// search, or tag change changes what is visible, a selection that is
/// no longer listed moves to the first listed note — or empties out,
/// so the editor shows its empty state instead of staying pinned to a
/// note from wherever you just were.
public enum SelectionReconciler {
    public static func target(selectedID: String?, visibleIDs: [String]) -> String? {
        if let selectedID, visibleIDs.contains(selectedID) { return selectedID }
        return visibleIDs.first
    }
}
