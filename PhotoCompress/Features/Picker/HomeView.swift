import PhotosUI
import SwiftUI

/// System photo picker with no selection limit. Needs no library permission.
struct PhotoPickerButton<Label: View>: View {
    let model: BatchModel
    @ViewBuilder var label: Label
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $selection, maxSelectionCount: nil, matching: .images) { label }
            .onChange(of: selection) { _, picked in
                guard !picked.isEmpty else { return }
                model.add(picked)
                selection = []
            }
    }
}

struct HomeView: View {
    let model: BatchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("home.headline").font(.largeTitle.weight(.heavy))
                Text("home.subtitle").font(.body).foregroundStyle(.secondary)
            }
            if let batch = model.unfinished { unfinishedCard(batch) }
            Spacer(minLength: 0)
            if let progress = model.importProgress {
                ProgressView(value: Double(progress.done), total: Double(progress.total)) {
                    Text("home.preparing \(progress.done) \(progress.total)").font(.subheadline)
                }
            }
            PhotoPickerButton(model: model) {
                Label("home.choose", systemImage: "plus")
                    .font(.title3.weight(.bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.brandFill, in: .rect(cornerRadius: 16))
            }
            .disabled(model.importProgress != nil)
            VStack(alignment: .leading, spacing: 10) {
                promise("home.promise.originals")
                promise("home.promise.limits")
                promise("home.promise.private")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ground)
        .navigationTitle("app.title")
    }

    private func unfinishedCard(_ batch: BatchJournal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.counterclockwise").font(.title3).foregroundStyle(Color.brandText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.unfinished.title").font(.callout.weight(.bold))
                    Text("home.unfinished.detail \(batch.saved.count) \(batch.pending.count)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                Button("home.resume") { model.resume() }.buttonStyle(PrimaryButtonStyle(height: 44))
                Button("home.discard") { model.discard() }.buttonStyle(SecondaryButtonStyle(height: 44))
            }
        }
        .padding(16)
        .card()
    }

    private func promise(_ key: LocalizedStringKey) -> some View {
        Label {
            Text(key).font(.footnote).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(Color.success)
        }
    }
}
