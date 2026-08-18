import SwiftUI

@main
struct PrumoApp: App {
    @State private var session = AuthSession.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .task {
                await session.fetchMe()
            }
        }
    }
}
