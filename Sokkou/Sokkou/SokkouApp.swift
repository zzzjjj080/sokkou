import SwiftUI

@main
struct SokkouApp: App {
    @State private var game = GameModel()

    var body: some Scene {
        WindowGroup {
            // 明るい画面にも合わせる。色は Palette が切り替える
            ContentView(game: game)
                .task { Haptics.warmUp() }
        }
    }
}
