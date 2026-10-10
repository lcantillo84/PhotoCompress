import SwiftUI

struct RootView: View {
    @State private var model = BatchModel()

    var body: some View {
        Group {
            switch model.phase {
            case .home: HomeView(model: model)
            case .compose: ComposeView(model: model)
            case .running: BatchProgressView(model: model)
            case .results: ResultsView(model: model)
            }
        }
        .animation(.default, value: model.phase)
        #if DEBUG
        .task { model.loadDemoIfRequested() }
        #endif
    }
}

#Preview {
    RootView()
}
