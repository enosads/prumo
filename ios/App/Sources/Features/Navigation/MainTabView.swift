import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showNewTransactionSheet = false
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Visão Geral", systemImage: "chart.pie.fill")
                }
                .tag(0)
            
            CashFlowView()
                .tabItem {
                    Label("Extrato", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(1)
            
            CardsView()
                .tabItem {
                    Label("Cartões", systemImage: "creditcard.fill")
                }
                .tag(2)
            
            BudgetsView()
                .tabItem {
                    Label("Orçamento", systemImage: "envelope.badge.fill")
                }
                .tag(3)
            
            ChatView()
                .tabItem {
                    Label("Copilot", systemImage: "sparkles")
                }
                .tag(4)
        }
        .tint(Brand.primary)
    }
}
