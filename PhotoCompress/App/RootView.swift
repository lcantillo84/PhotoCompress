import SwiftUI

struct RootView: View {
    @State private var model = BatchModel()

    /// New screens push in from the right going forward and from the left going back.
    private var slide: AnyTransition {
        model.movedForward
            ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    }

    var body: some View {
        ZStack {
            switch model.phase {
            case .home: HomeView(model: model).transition(slide)
            case .compose: ComposeView(model: model).transition(slide)
            case .running: BatchProgressView(model: model).transition(slide)
            case .results: ResultsView(model: model).transition(slide)
            }
        }
        .animation(.snappy(duration: 0.3), value: model.phase)
        #if DEBUG
        .task { model.loadDemoIfRequested() }
        #endif
    }
}

#Preview {
    RootView()
}
