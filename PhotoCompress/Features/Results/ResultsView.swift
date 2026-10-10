import SwiftUI

struct ResultsView: View {
    let model: BatchModel
    @State private var previewed: BatchJournal.Item?

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

                if !saved.isEmpty {
                    Text("results.tapHint").font(.footnote).foregroundStyle(.secondary)
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(batch.items) { item in
                            ItemRow(
                                item: item, store: model.store,
                                retry: { model.retry(item.id) },
                                open: item.status == .saved ? { previewed = item } : nil)
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
            .swipeBack { model.discard() }
            .navigationTitle("results.nav")
            .sheet(item: $previewed) { item in
                CompressedPreview(item: item, store: model.store)
            }
            #if DEBUG
            .task {
                if UserDefaults.standard.bool(forKey: "demoPreview") { previewed = saved.first }
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.discard() } label: { Label("nav.home", systemImage: "chevron.left").labelStyle(.titleAndIcon) }
                }
            }
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

/// Shows one compressed copy full-size, so the user can check it without hunting in Photos.
struct CompressedPreview: View {
    let item: BatchJournal.Item
    let store: BatchStore
    @Environment(\.dismiss) private var dismiss

    private var url: URL { store.outbox.appendingPathComponent(item.outputFile ?? "") }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    if let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFit()
                    } else {
                        Color(.tertiarySystemFill)
                    }
                }
                .clipShape(.rect(cornerRadius: 12))
                .frame(maxHeight: .infinity)

                VStack(spacing: 4) {
                    Text("preview.compressed").font(.headline)
                    Text(verbatim: "\(item.originalBytes.fileSize) → \((item.finalBytes ?? 0).fileSize)")
                        .font(.title3.weight(.semibold)).foregroundStyle(Color.success)
                    Text(verbatim: url.lastPathComponent).font(.footnote).foregroundStyle(.secondary)
                    Text("preview.note").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                ShareLink(item: url) {
                    Label("results.share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle(height: 56))
            }
            .padding(20)
            .background(Color.ground)
            .navigationTitle(Text(verbatim: item.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("preview.done") { dismiss() }
                }
            }
        }
    }
}
