import PhotosUI
import SwiftUI

/// Temporary on-device test screen for the engine. Writes nothing to the photo library.
struct CompressHarnessView: View {
    @State private var model = CompressHarnessModel()

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $model.selection, matching: .images) {
                        Label("harness.pick", systemImage: "photo")
                    }
                    LabeledContent("harness.target") {
                        TextField("harness.target", text: $model.targetKB)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Button("harness.compress") { model.compress() }
                        .disabled(!model.canCompress)
                }

                switch model.state {
                case .idle:
                    EmptyView()
                case .working:
                    Section { ProgressView() }
                case .failed:
                    Section { Text("harness.failed").foregroundStyle(.red) }
                case .done(let report):
                    ResultSection(report: report)
                }
            }
            .navigationTitle("app.title")
        }
    }
}

private struct ResultSection: View {
    let report: HarnessReport

    var body: some View {
        let r = report.result
        Section("harness.result") {
            LabeledContent("harness.original", value: bytes(r.originalBytes))
            LabeledContent("harness.final", value: bytes(r.finalBytes))
            LabeledContent("harness.quality", value: r.quality.formatted(.number.precision(.fractionLength(2))))
            LabeledContent("harness.scale", value: r.scale.formatted(.percent.precision(.fractionLength(0))))
            LabeledContent("harness.dimensions", value: "\(r.pixelWidth) × \(r.pixelHeight)")
            LabeledContent("harness.iterations", value: r.iterations.formatted())
        }
        Section("harness.metadata") {
            LabeledContent("harness.captureDate") { fallback(report.captureDate) }
            LabeledContent("harness.cameraModel") { fallback(report.cameraModel) }
            LabeledContent("harness.gps") { Text(report.hasGPS ? "harness.yes" : "harness.no") }
        }
    }

    private func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    @ViewBuilder
    private func fallback(_ value: String?) -> some View {
        if let value { Text(verbatim: value) } else { Text("harness.none") }
    }
}
