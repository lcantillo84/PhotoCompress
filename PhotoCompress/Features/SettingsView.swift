import SwiftUI

struct SettingsView: View {
    @Bindable var model: BatchModel
    @AppStorage("appLanguage") private var language = ""

    var body: some View {
        Form {
            Section("settings.language") {
                Picker("settings.language", selection: $language) {
                    Text("settings.language.system").tag("")
                    Text(verbatim: "English").tag("en")
                    Text(verbatim: "Español").tag("es")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                Toggle("compose.keepInfo", isOn: $model.keepMetadata).tint(Color.success)
            } footer: {
                Text("settings.keepInfo.footer")
            }
            Section("settings.about") {
                Label("home.promise.originals", systemImage: "checkmark")
                Label("home.promise.limits", systemImage: "checkmark")
                Label("home.promise.private", systemImage: "checkmark")
                LabeledContent("settings.version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
            }
        }
        .navigationTitle("tab.settings")
    }
}
