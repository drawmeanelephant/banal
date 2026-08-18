import Foundation

/// What to do when the file on disk no longer matches the last load.
public enum ExternalEditAction: Equatable, Sendable {
    case ignore
    /// Buffer is clean — take disk.
    case reload
    /// Buffer is dirty and disk changed — keep the buffer.
    case keepBuffer
    /// File vanished. Dirty: keep buffer. Clean: leave the note.
    case noteGone(keepBuffer: Bool)
}

public enum ExternalEdit {
    public static func action(
        selectedStillOnDisk: Bool,
        dirty: Bool,
        loadedFingerprint: String,
        diskFingerprint: String,
        bufferMatchesDisk: Bool
    ) -> ExternalEditAction {
        if !selectedStillOnDisk {
            return .noteGone(keepBuffer: dirty)
        }
        if diskFingerprint == loadedFingerprint {
            return .ignore
        }
        if bufferMatchesDisk {
            return .ignore
        }
        if dirty {
            return .keepBuffer
        }
        return .reload
    }
}
