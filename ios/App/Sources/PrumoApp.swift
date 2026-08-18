import SwiftUI

@main
struct PrumoApp: App {
    @State private var session = AuthSession.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    DashboardView()
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
