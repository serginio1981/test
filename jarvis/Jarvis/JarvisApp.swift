import SwiftUI

@main
struct JarvisApp: App {
    @State private var viewModel = AssistantViewModel()

    var body: some Scene {
        WindowGroup {
            HUDView()
                .environment(viewModel)
        }
    }
}
