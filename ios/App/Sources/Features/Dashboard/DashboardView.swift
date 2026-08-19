import SwiftUI

public struct DashboardView: View {
    @State private var accounts: [Account] = []
    @State private var isLoading = false
    @State private var showNewAccountSheet = false
    @State private var errorMessage: String?
    
    private struct AccountsResponse: Codable {
        let accounts: [Account]
    }
    
    public init() {}
    
    private var totalBalanceCents: Int64 {
        accounts.reduce(0) { $0 + $1.currentBalanceCents }
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Card Principal de Patrimônio
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Patrimônio Familiar Consolidado")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        CampoMonetario(amountCents: .constant(totalBalanceCents), fontSize: 36)
                            .foregroundColor(.white)
                        
                        HStack {
                            Label("Espaço Compartilhado", systemImage: "person.2.fill")
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.2))
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Text("\(accounts.count) contas ativas")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Brand.primary, Brand.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Brand.primary.opacity(0.3), radius: 10, y: 5)
                    
                    // Seção de Contas
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Contas & Carteiras")
                                .font(.title3.bold())
                            Spacer()
                            Button {
                                showNewAccountSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Brand.primary)
                            }
                        }
                        
                        if isLoading && accounts.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if accounts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "creditcard.and.123")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Nenhuma conta cadastrada ainda.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button {
                                    showNewAccountSheet = true
                                } label: {
                                    Label("Criar Primeira Conta", systemImage: "plus")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Brand.primary)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(Brand.surface)
                            .cornerRadius(14)
                        } else {
                            ForEach(accounts) { acc in
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(Brand.primary.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: iconForKind(acc.kind))
                                                .foregroundColor(Brand.primary)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acc.name)
                                            .font(.body.weight(.semibold))
                                        Text(acc.kind.label)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatCurrency(cents: acc.currentBalanceCents))
                                        .font(.callout.weight(.bold))
                                        .foregroundColor(acc.currentBalanceCents >= 0 ? .primary : Brand.expense)
                                }
                                .padding(14)
                                .background(Brand.surface)
                                .cornerRadius(14)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle("Prumo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        AuthSession.shared.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showNewAccountSheet) {
                NewAccountSheet { _ in
                    Task { await loadAccounts() }
                }
            }
            .refreshable {
                await loadAccounts()
            }
            .task {
                await loadAccounts()
            }
            .onAppear {
                Task { await loadAccounts() }
            }
        }
    }
    
    private func loadAccounts() async {
        guard let token = AuthSession.shared.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let res: AccountsResponse = try await APIClient.shared.request("/v1/accounts", token: token)
            self.accounts = res.accounts
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func iconForKind(_ kind: AccountKind) -> String {
        switch kind {
        case .checking: "building.columns.fill"
        case .savings: "banknote.fill"
        case .investment: "chart.pie.fill"
        case .cash: "dollarsign.circle.fill"
        case .creditCard: "creditcard.fill"
        }
    }
    
    private func formatCurrency(cents: Int64) -> String {
        let val = Double(cents) / 100.0
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: val)) ?? "R$ 0,00"
    }
}
