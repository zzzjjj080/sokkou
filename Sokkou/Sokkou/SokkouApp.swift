import SwiftUI

@main
struct SokkouApp: App {
    @State private var game = GameModel()

    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
                .preferredColorScheme(.dark)
                .task { Haptics.warmUp() }
        }
    }
}
