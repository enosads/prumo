import SwiftUI

public struct CardDetailView: View {
    public let cardSummary: CreditCardSummary
    
    @State private var invoices: [CreditCardInvoice] = []
    @State private var selectedInvoiceID: UUID?
    @State private var invoiceTransactions: [Transaction] = []
    @State private var checkingAccounts: [Account] = []
    @State private var isLoading = false
    @State private var isPaying = false
    @State private var showAnticipateSheet = false
    @State private var showPaymentAlert = false
    @State private var errorMessage: String?
    
    private struct InvoicesResponse: Codable {
        let invoices: [CreditCardInvoice]
    }
    
    private struct InvoiceDetailsResponse: Codable {
        let invoice: CreditCardInvoice
        let transactions: [Transaction]
    }
    
    private struct AccountsResponse: Codable {
        let accounts: [Account]
    }
    
    private struct PayPayload: Codable {
        let payment_account_id: UUID
        let amount_cents: Int64
    }
    
    public init(cardSummary: CreditCardSummary) {
        self.cardSummary = cardSummary
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Card de Informações do Cartão
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cardSummary.card.name)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            if let last4 = cardSummary.card.lastFourDigits {
                                Text("•••• \(last4)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Divider().background(.white.opacity(0.3))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Limite Total")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text(formatCurrency(cents: cardSummary.card.creditLimitCents))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text("Fechamento")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Dia \(cardSummary.card.closingDay)")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Vencimento")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Dia \(cardSummary.card.dueDay)")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [colorForCard(cardSummary.card.color), Brand.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .padding(.horizontal)
                
                // Ações Rápidas (Pagar Fatura / Antecipar Parcelas)
                HStack(spacing: 12) {
                    Button {
                        showPaymentAlert = true
                    } label: {
                        Label("Pagar Fatura", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Brand.primary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(selectedInvoice?.remainingAmountCents == 0 || isPaying)
                    
                    Button {
                        showAnticipateSheet = true
                    } label: {
                        Label("Antecipar", systemImage: "bolt.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Brand.surface)
                            .foregroundColor(Brand.primary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Brand.primary, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal)
                
                // Seletor de Faturas (Histórico de Meses)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Faturas")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(invoices) { inv in
                                Button {
                                    selectedInvoiceID = inv.id
                                    Task { await loadInvoiceTransactions(inv.id) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(monthLabel(inv))
                                            .font(.subheadline.bold())
                                        
                                        Text(formatCurrency(cents: inv.totalAmountCents))
                                            .font(.caption.weight(.semibold))
                                        
                                        Text(statusLabel(inv.status))
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(statusColor(inv.status).opacity(0.2))
                                            .foregroundColor(statusColor(inv.status))
                                            .cornerRadius(6)
                                    }
                                    .padding(12)
                                    .frame(width: 140, alignment: .leading)
                                    .background(selectedInvoiceID == inv.id ? Brand.primary.opacity(0.1) : Brand.surface)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedInvoiceID == inv.id ? Brand.primary : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Lançamentos da Fatura Selecionada
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lançamentos da Fatura")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if invoiceTransactions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Nenhum lançamento nesta fatura.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Brand.surface)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    } else {
                        ForEach(invoiceTransactions) { tx in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Brand.primary.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: tx.categoryIcon ?? "bag.fill")
                                            .foregroundColor(Brand.primary)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tx.description)
                                        .font(.body.weight(.semibold))
                                    
                                    HStack(spacing: 6) {
                                        if let cat = tx.categoryName {
                                            Text(cat)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let num = tx.installmentNumber, let tot = tx.installmentTotal, tot > 1 {
                                            Text("• \(num)/\(tot)")
                                                .font(.caption2.bold())
                                                .foregroundColor(Brand.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Text(formatCurrency(cents: tx.amountCents))
                                    .font(.callout.bold())
                            }
                            .padding(14)
                            .background(Brand.surface)
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle(cardSummary.card.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAnticipateSheet) {
            AnticipateInstallmentsSheet(cardID: cardSummary.card.id, cardName: cardSummary.card.name) {
                Task {
                    await loadInvoices()
                }
            }
        }
        .confirmationDialog("Pagar Fatura", isPresented: $showPaymentAlert, titleVisibility: .visible) {
            ForEach(checkingAccounts) { acc in
                Button("Pagar com \(acc.name)") {
                    Task { await payInvoice(with: acc.id) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if let inv = selectedInvoice {
                Text("Deseja pagar o valor restante de \(formatCurrency(cents: inv.remainingAmountCents))?")
            }
        }
        .task {
            await loadInvoices()
            await loadCheckingAccounts()
        }
    }
    
    private var selectedInvoice: CreditCardInvoice? {
        invoices.first { $0.id == selectedInvoiceID }
    }
    
    private func monthLabel(_ inv: CreditCardInvoice) -> String {
        let months = ["", "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
        let idx = Int(inv.periodMonth)
        let name = (idx >= 1 && idx <= 12) ? months[idx] : "\(inv.periodMonth)"
        return "\(name) \(inv.periodYear)"
    }
    
    private func statusLabel(_ status: String) -> String {
        switch status {
        case "open": "Aberta"
        case "closed": "Fechada"
        case "paid": "Paga"
        case "partially_paid": "Parcial"
        case "overdue": "Atrasada"
        default: status.capitalized
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "open": Brand.investment
        case "closed": Brand.warning
        case "paid": Brand.income
        case "overdue": Brand.expense
        default: .secondary
        }
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
    
    private func loadInvoices() async {
        guard let token = AuthSession.shared.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let res: InvoicesResponse = try await APIClient.shared.request(
                "/v1/cards/\(cardSummary.card.id)/invoices",
                token: token
            )
            self.invoices = res.invoices
            if selectedInvoiceID == nil, let first = res.invoices.first {
                self.selectedInvoiceID = first.id
                await loadInvoiceTransactions(first.id)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func loadInvoiceTransactions(_ invoiceID: UUID) async {
        guard let token = AuthSession.shared.accessToken else { return }
        do {
            let res: InvoiceDetailsResponse = try await APIClient.shared.request(
                "/v1/cards/\(cardSummary.card.id)/invoices/\(invoiceID)",
                token: token
            )
            self.invoiceTransactions = res.transactions
        } catch {}
    }
    
    private func loadCheckingAccounts() async {
        guard let token = AuthSession.shared.accessToken else { return }
        do {
            let res: AccountsResponse = try await APIClient.shared.request("/v1/accounts", token: token)
            self.checkingAccounts = res.accounts.filter { $0.kind == .checking || $0.kind == .savings }
        } catch {}
    }
    
    private func payInvoice(with accountID: UUID) async {
        guard let token = AuthSession.shared.accessToken,
              let inv = selectedInvoice else { return }
        isPaying = true
        defer { isPaying = false }
        
        let payload = PayPayload(
            payment_account_id: accountID,
            amount_cents: inv.remainingAmountCents
        )
        
        do {
            try await APIClient.shared.send(
                "/v1/cards/\(cardSummary.card.id)/invoices/\(inv.id)/pay",
                method: "POST",
                body: payload,
                token: token
            )
            await loadInvoices()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
