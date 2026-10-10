import SwiftUI
import UIKit

struct ItemThumbnail: View {
    let item: BatchJournal.Item
    let store: BatchStore
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let image = UIImage(contentsOfFile: store.thumbURL(for: item.id).path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(.tertiarySystemFill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size / 5))
        .accessibilityHidden(true)
    }
}

/// One photo in the progress and results lists.
struct ItemRow: View {
    let item: BatchJournal.Item
    let store: BatchStore
    var isCurrent = false
    var retry: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ItemThumbnail(item: item, store: store)
            Group {
                if item.name.isEmpty { Text("row.unreadable") } else { Text(verbatim: item.name) }
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            Spacer(minLength: 8)
            status
        }
        .frame(minHeight: 58)
    }

    @ViewBuilder private var status: some View {
        switch item.status {
        case .saved:
            Text(verbatim: "\(item.originalBytes.fileSize) → \((item.finalBytes ?? 0).fileSize)")
                .font(.footnote).foregroundStyle(.secondary)
            Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(Color.success)
                .accessibilityLabel(Text("row.saved"))
        case .skipped:
            Text("row.fits \(item.originalBytes.fileSize)").font(.footnote).foregroundStyle(.secondary)
        case .failed:
            if let retry, !item.inboxFile.isEmpty {
                Button("row.retry", action: retry)
                    .font(.footnote.weight(.semibold)).foregroundStyle(Color.failure)
                    .frame(minHeight: 44)
            } else {
                Text("row.failed").font(.footnote.weight(.semibold)).foregroundStyle(Color.failure)
            }
        case .pending:
            if isCurrent {
                Text("row.working").font(.footnote.weight(.semibold)).foregroundStyle(Color.brandText)
            } else {
                Text("row.waiting").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
