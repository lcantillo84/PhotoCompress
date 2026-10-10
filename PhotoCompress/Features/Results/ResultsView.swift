import SwiftUI

struct ResultsView: View {
    let model: BatchModel

    var body: some View {
        if let batch = model.journal {
            let saved = batch.saved
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.success, in: .circle)
                        .accessibilityHidden(true)
                    Text("results.saved \(saved.count)").font(.largeTitle.weight(.heavy))
                    if !saved.isEmpty {
                        let before = saved.reduce(0) { $0 + $1.originalBytes }
                        let after = saved.reduce(0) { $0 + ($1.finalBytes ?? 0) }
                        Text(verbatim: "\(before.fileSize) → \(after.fileSize)")
                            .font(.title3.weight(.semibold)).foregroundStyle(Color.success)
                    }
                }

                if !saved.isEmpty { whereCard }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(batch.items) { item in
                            ItemRow(item: item, store: model.store) { model.retry(item.id) }
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .card()

                Button("results.more") { model.discard() }
                    .buttonStyle(SecondaryButtonStyle(tint: .brandText))
            }
            .padding(20)
            .background(Color.ground)
        }
    }

    private var whereCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("results.where.title").font(.callout.weight(.bold))
                Text("results.where.detail").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button("results.openPhotos") {
                    if let url = URL(string: "photos-redirect://") { UIApplication.shared.open(url) }
                }
                .buttonStyle(PrimaryButtonStyle(height: 48))
                ShareLink(items: model.sharedFiles) {
                    Label("results.share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle(height: 48))
            }
        }
        .padding(16)
        .card()
    }
}
