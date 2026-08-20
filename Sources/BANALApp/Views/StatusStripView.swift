import AppKit
import BANALCore
import SwiftUI

struct StatusStripView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 8) {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .accessibilityLabel(statusText)
                .accessibilityAddTraits(.updatesFrequently)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            if contrast == .increased {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
            } else {
                Divider()
            }
        }
        .onTapGesture {
            if model.statusMessage != nil {
                model.statusMessage = nil
            }
        }
    }

    private var statusText: String {
        if let status = model.statusMessage {
            return status
        }
        if model.selectedNote != nil {
            return model.editorWordCountDescription
        }
        let count = model.store.notes.count
        if count == 0 {
            return "No notes"
        } else if count == 1 {
            return "1 note"
        } else {
            return "\(count.formatted()) notes"
        }
    }
}
