import SwiftUI

public struct CardsView: View {
    @State private var cards: [CreditCardSummary] = []
    @State private var selectedCardID: UUID?
    @State private var projections: [MonthlyProjectionItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private struct CardsResponse: Codable {
        let cards: [CreditCardSummary]
    }
    
    private struct ProjectionsResponse: Codable {
        let projections: [MonthlyProjectionItem]
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading && cards.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else if cards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Nenhum cartão cadastrado")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Cadastre seu primeiro cartão de crédito para acompanhar faturas e parcelas.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(Brand.surface)
                        .cornerRadius(18)
                        .padding(.horizontal)
                    } else {
                        // Carrossel Horizontal de Cartões
                        TabView(selection: $selectedCardID) {
                            ForEach(cards) { summary in
                                NavigationLink(destination: CardDetailView(cardSummary: summary)) {
                                    cardCarouselItem(summary)
                                }
                                .buttonStyle(.plain)
                                .tag(Optional(summary.card.id))
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(height: 240)
                        .onChange(of: selectedCardID) { _, newID in
                            if let id = newID {
                                Task { await loadProjections(for: id) }
                            }
                        }
                        
                        // Seção de Projeção dos Próximos 12 Meses
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Projeção de Faturas (12 Meses)")
                                    .font(.title3.bold())
                                Spacer()
                                if let selected = selectedCard {
                                    NavigationLink(destination: CardDetailView(cardSummary: selected)) {
                                        Text("Ver Detalhes")
                                            .font(.subheadline.bold())
                                            .foregroundColor(Brand.primary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(projections) { proj in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(proj.monthLabel)
                                                .font(.body.weight(.semibold))
                                            
                                            if proj.installmentsCount > 0 {
                                                Text("\(proj.installmentsCount) parcelas ativas")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Text("Sem parcelas")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Divisão de Gastos por Membro do Casal
                                        if let shares = proj.memberShares, !shares.isEmpty {
                                            HStack(spacing: 4) {
                                                ForEach(shares) { s in
                                                    Text("\(s.userName): \(formatCurrency(cents: s.amountCents))")
                                                        .font(.caption2.bold())
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Brand.secondary.opacity(0.12))
                                                        .foregroundColor(Brand.secondary)
                                                        .cornerRadius(6)
                                                }
                                            }
                                        }
                                        
                                        Text(formatCurrency(cents: proj.totalAmountCents))
                                            .font(.callout.bold())
                                            .foregroundColor(proj.totalAmountCents > 0 ? .primary : .secondary)
                                    }
                                    .padding(14)
                                    .background(Brand.surface)
                                    .cornerRadius(14)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle("Cartões & Faturas")
            .refreshable {
                await loadCards()
            }
            .task {
                await loadCards()
            }
            .onAppear {
                Task { await loadCards() }
            }
        }
    }
    
    private var selectedCard: CreditCardSummary? {
        cards.first { $0.card.id == selectedCardID } ?? cards.first
    }
    
    private func cardCarouselItem(_ summary: CreditCardSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.card.name)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    if let last4 = summary.card.lastFourDigits {
                        Text("•••• \(last4)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            // Fatura Atual & Limite Disponível
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fatura Atual")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Text(formatCurrency(cents: summary.usedLimitCents))
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Disponível")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Text(formatCurrency(cents: summary.availableLimitCents))
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }
                }
                
                // Barra de Progresso do Limite
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(Brand.accent)
                            .frame(
                                width: max(0, min(geo.size.width, geo.size.width * limitRatio(summary))),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            LinearGradient(
                colors: [colorForCard(summary.card.color), Brand.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: colorForCard(summary.card.color).opacity(0.3), radius: 10, y: 5)
        .padding(.horizontal)
    }
    
    private func limitRatio(_ summary: CreditCardSummary) -> CGFloat {
        guard summary.card.creditLimitCents > 0 else { return 0 }
        return CGFloat(summary.usedLimitCents) / CGFloat(summary.card.creditLimitCents)
    }
    
    private func colorForCard(_ hex: String?) -> Color {
        guard let hex = hex, hex.hasPrefix("#") else { return Brand.primary }
        return Color(hex: hex)
    }
    
    private func formatCurrency(cents: Int64) -> String {
        let val = Double(cents) / 100.0
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: val)) ?? "R$ 0,00"
    }
    
    private func loadCards() async {
        guard let token = AuthSession.shared.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let res: CardsResponse = try await APIClient.shared.request("/v1/cards", token: token)
            self.cards = res.cards
            if selectedCardID == nil, let first = res.cards.first {
                self.selectedCardID = first.card.id
                await loadProjections(for: first.card.id)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func loadProjections(for cardID: UUID) async {
        guard let token = AuthSession.shared.accessToken else { return }
        do {
            let res: ProjectionsResponse = try await APIClient.shared.request(
                "/v1/cards/\(cardID)/installments",
                token: token
            )
            self.projections = res.projections
        } catch {}
    }
}
