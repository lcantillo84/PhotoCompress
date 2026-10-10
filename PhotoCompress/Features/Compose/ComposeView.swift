import SwiftUI

struct ComposeView: View {
    @Bindable var model: BatchModel
    @FocusState private var customFocused: Bool

    private var items: [BatchJournal.Item] { model.journal?.items ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button { model.discard() } label: { Label("compose.back", systemImage: "chevron.left") }
                    Spacer()
                    PhotoPickerButton(model: model) { Text("compose.addMore") }
                }
                .font(.body).tint(Color.brandText).frame(minHeight: 44)

                summary
                sizePicker
                metadataToggle
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ground)
        .swipeBack { model.discard() }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Text("compose.copies").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button { model.start() } label: { Text("compose.compress \(items.count)") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.targetBytes == nil || model.importProgress != nil)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.ground)
        }
        .alert("access.title", isPresented: $model.accessDenied) {
            Button("access.settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("access.cancel", role: .cancel) {}
        } message: {
            Text("access.message")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("compose.count \(items.count)").font(.title.weight(.heavy))
                Spacer()
                Text("compose.total \((model.journal?.totalOriginalBytes ?? 0).fileSize)")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(items.prefix(4)) { item in
                    ItemThumbnail(item: item, store: model.store, size: 64)
                        .overlay(alignment: .bottomLeading) {
                            Text(verbatim: item.originalBytes.fileSize)
                                .font(.caption2.weight(.semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
                                .padding(3)
                        }
                }
                if items.count > 4 {
                    Text(verbatim: "+\(items.count - 4)")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 13))
                }
            }
        }
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("compose.under").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(SizePreset.all, id: \.self) { bytes in
                    chip(selected: model.selectedPreset == bytes) {
                        model.selectedPreset = bytes
                        customFocused = false
                    } label: {
                        Text(verbatim: bytes.fileSize)
                    }
                }
                chip(selected: model.selectedPreset == nil) {
                    model.selectedPreset = nil
                    customFocused = true
                } label: {
                    Text("compose.custom")
                }
            }
            if model.selectedPreset == nil {
                HStack(spacing: 10) {
                    TextField("compose.custom.placeholder", value: $model.customAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($customFocused)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(Color.card, in: .rect(cornerRadius: 12))
                    Picker("compose.custom.unit", selection: $model.customUnit) {
                        Text(verbatim: "KB").tag(SizeUnit.kb)
                        Text(verbatim: "MB").tag(SizeUnit.mb)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }
            Text("compose.hint").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func chip(selected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .font(.subheadline.weight(selected ? .bold : .semibold))
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(selected ? Color.brandText : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(selected ? Color.brandFill.opacity(0.14) : Color.card, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Color.brandText : Color(.separator), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var metadataToggle: some View {
        Toggle(isOn: $model.keepMetadata) {
            VStack(alignment: .leading, spacing: 2) {
                Text("compose.keepInfo").font(.callout.weight(.semibold))
                Text("compose.keepInfo.detail").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .tint(Color.success)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .card()
    }
}
