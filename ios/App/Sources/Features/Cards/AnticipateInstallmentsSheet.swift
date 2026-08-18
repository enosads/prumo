import SwiftUI

public struct AnticipateInstallmentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let cardID: UUID
    public let cardName: String
    public var onAnticipated: (() -> Void)?
    
    @State private var projections: [MonthlyProjectionItem] = []
    @State private var selectedTxIDs: Set<UUID> = []
    @State private var annualDiscountRate: Double = 10.0
    @State private var simulation: SimulateAnticipationResponse?
    @State private var isLoading = false
    @State private var isSimulating = false
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    public init(cardID: UUID, cardName: String, onAnticipated: (() -> Void)? = nil) {
        self.cardID = cardID
        self.cardName = cardName
        self.onAnticipated = onAnticipated
    }
    
    private struct ProjectionsResponse: Codable {
        let projections: [MonthlyProjectionItem]
    }
    
    private struct AnticipationRequest: Codable {
        let transaction_ids: [UUID]
        let annual_discount_rate: Double
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Informativo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Antecipe parcelas futuras do cartão **\(cardName)** e ganhe desconto proporcional no valor total.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Taxa de Desconto Anual:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%% a.a.", annualDiscountRate))
                                .font(.subheadline.bold())
                                .foregroundColor(Brand.primary)
                        }
                        
                        Slider(value: $annualDiscountRate, in: 5.0...25.0, step: 0.5)
                            .tint(Brand.primary)
                            .onChange(of: annualDiscountRate) { _, _ in
                                Task { await simulate() }
                            }
                    }
                    .padding()
                    .background(Brand.surface)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Card de Simulação de Desconto
                    if let sim = simulation, !selectedTxIDs.isEmpty {
                        VStack(spacing: 12) {
                            Text("Resumo da Simulação")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Valor Original")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(formatCurrency(cents: sim.originalTotalCents))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .center) {
                                    Text("Desconto Ganho")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("-\(formatCurrency(cents: sim.totalDiscountCents))")
                                        .font(.subheadline.bold())
                                        .foregroundColor(Brand.accent)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Valor a Pagar")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(formatCurrency(cents: sim.anticipatedTotalCents))
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(18)
                        .background(
                            LinearGradient(
                                colors: [Brand.primary, Brand.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Lista de Parcelas Futuras Elegíveis
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selecione as parcelas para antecipar:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if availableTransactions.isEmpty {
                            Text("Nenhuma parcela futura disponível para antecipação.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(availableTransactions) { tx in
                                Button {
                                    toggleSelect(tx.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedTxIDs.contains(tx.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(selectedTxIDs.contains(tx.id) ? Brand.primary : .secondary)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tx.description)
                                                .font(.body.weight(.semibold))
                                                .foregroundColor(.primary)
                                            
                                            HStack(spacing: 6) {
                                                if let num = tx.installmentNumber, let tot = tx.installmentTotal {
                                                    Text("Parcela \(num)/\(tot)")
                                                        .font(.caption2.bold())
                                                        .foregroundColor(Brand.secondary)
                                                }
                                                
                                                Text("• \(formatDate(tx.transactedAt))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text(formatCurrency(cents: tx.amountCents))
                                            .font(.callout.bold())
                                            .foregroundColor(.primary)
                                    }
                                    .padding()
                                    .background(Brand.surface)
                                    .cornerRadius(14)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle("Antecipar Parcelas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Antecipar") {
                        Task { await applyAnticipation() }
                    }
                    .fontWeight(.bold)
                    .disabled(selectedTxIDs.isEmpty || isApplying)
                }
            }
            .alert("Sucesso!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    onAnticipated?()
                    dismiss()
                }
            } message: {
                Text("As parcelas foram antecipadas com desconto para a sua fatura atual.")
            }
            .task {
                await loadProjections()
            }
        }
    }
    
    private var availableTransactions: [Transaction] {
        var result: [Transaction] = []
        // Ignora o primeiro mês (fatura atual) e lista os meses subsequentes
        for proj in projections.dropFirst() {
            if let txs = proj.transactions {
                result.append(contentsOf: txs)
            }
        }
        return result
    }
    
    private func toggleSelect(_ id: UUID) {
        if selectedTxIDs.contains(id) {
            selectedTxIDs.remove(id)
        } else {
            selectedTxIDs.insert(id)
        }
        Task { await simulate() }
    }
    
    private func loadProjections() async {
        guard let token = AuthSession.shared.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let res: ProjectionsResponse = try await APIClient.shared.request(
                "/v1/cards/\(cardID)/installments",
                token: token
            )
            self.projections = res.projections
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func simulate() async {
        guard let token = AuthSession.shared.accessToken, !selectedTxIDs.isEmpty else {
            self.simulation = nil
            return
        }
        
        isSimulating = true
        defer { isSimulating = false }
        
        let payload = AnticipationRequest(
            transaction_ids: Array(selectedTxIDs),
            annual_discount_rate: annualDiscountRate
        )
        
        do {
            let res: SimulateAnticipationResponse = try await APIClient.shared.request(
                "/v1/cards/\(cardID)/installments/anticipate/simulate",
                method: "POST",
                body: payload,
                token: token
            )
            self.simulation = res
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func applyAnticipation() async {
        guard let token = AuthSession.shared.accessToken, !selectedTxIDs.isEmpty else { return }
        
        isApplying = true
        defer { isApplying = false }
        
        let payload = AnticipationRequest(
            transaction_ids: Array(selectedTxIDs),
            annual_discount_rate: annualDiscountRate
        )
        
        do {
            let _: [String: AnyCodable] = try await APIClient.shared.request(
                "/v1/cards/\(cardID)/installments/anticipate/apply",
                method: "POST",
                body: payload,
                token: token
            )
            self.showSuccessAlert = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func formatCurrency(cents: Int64) -> String {
        let val = Double(cents) / 100.0
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: val)) ?? "R$ 0,00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: date)
    }
}
