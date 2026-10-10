import SwiftUI

struct BatchProgressView: View {
    let model: BatchModel

    var body: some View {
        if let batch = model.journal {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("progress.title \(batch.targetBytes.fileSize)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text("progress.count \(batch.doneCount) \(batch.items.count)")
                        .font(.system(.largeTitle, weight: .heavy)).monospacedDigit()
                }
                ProgressView(value: Double(batch.doneCount), total: Double(max(batch.items.count, 1)))
                    .tint(Color.brandFill)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(batch.items) { item in
                                ItemRow(item: item, store: model.store, isCurrent: item.id == model.currentID)
                                    .id(item.id)
                                Divider()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .card()
                    .onChange(of: model.currentID) { _, id in
                        if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    }
                    .onAppear {
                        if let id = model.currentID { proxy.scrollTo(id, anchor: .center) }
                    }
                }

                Label {
                    Text("progress.safe").font(.subheadline)
                } icon: {
                    Image(systemName: "checkmark.shield")
                }
                .foregroundStyle(Color.brandText)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brandFill.opacity(0.14), in: .rect(cornerRadius: 16))

                Button(model.isStopping ? LocalizedStringKey("progress.stopping") : LocalizedStringKey("progress.cancel")) { model.cancel() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(model.isStopping)
            }
            .padding(20)
            .background(Color.ground)
            .navigationTitle("progress.nav")
        }
    }
}
