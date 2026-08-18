import SwiftUI

public struct CashFlowView: View {
    @State private var transactions: [Transaction] = []
    @State private var members: [FamilyMember] = []
    @State private var selectedKind: TransactionKind? = nil
    @State private var selectedMemberID: UUID? = nil
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showNewTransaction = false
    @State private var errorMessage: String?
    
    private struct TransactionsResponse: Codable {
        let transactions: [Transaction]
        let totals: CashFlowSummary?
    }
    
    private struct MembersResponse: Codable {
        let members: [FamilyMember]
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtros de Tipo
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "Todos", isSelected: selectedKind == nil && selectedMemberID == nil) {
                            selectedKind = nil
                            selectedMemberID = nil
                        }
                        
                        filterChip(title: "Despesas", isSelected: selectedKind == .expense) {
                            selectedKind = selectedKind == .expense ? nil : .expense
                        }
                        
                        filterChip(title: "Receitas", isSelected: selectedKind == .income) {
                            selectedKind = selectedKind == .income ? nil : .income
                        }
                        
                        filterChip(title: "Transferências", isSelected: selectedKind == .transfer) {
                            selectedKind = selectedKind == .transfer ? nil : .transfer
                        }
                        
                        // Membros da Família
                        ForEach(members) { m in
                            filterChip(title: m.nickname ?? m.fullName, isSelected: selectedMemberID == m.userID) {
                                selectedMemberID = selectedMemberID == m.userID ? nil : m.userID
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Brand.surface)
                
                // Lista de Transações agrupadas por data
                if isLoading && transactions.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredTransactions.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Nenhum lançamento encontrado")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Toque em '+' para registrar uma nova movimentação.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { dateKey in
                            Section(header: Text(dateKey).font(.subheadline.bold()).foregroundColor(.secondary)) {
                                ForEach(groupedTransactions[dateKey] ?? []) { tx in
                                    transactionRow(tx)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadTransactions()
                    }
                }
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle("Extrato")
            .searchable(text: $searchText, prompt: "Buscar por descrição ou tag...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(Brand.primary)
                    }
                }
            }
            .sheet(isPresented: $showNewTransaction) {
                NewTransactionSheet {
                    Task { await loadTransactions() }
                }
            }
            .task {
                await loadTransactions()
                await loadMembers()
            }
        }
    }
    
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Brand.primary : Brand.background)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private func transactionRow(_ tx: Transaction) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(colorForCategory(tx.categoryColor).opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: tx.categoryIcon ?? "dollarsign")
                        .foregroundColor(colorForCategory(tx.categoryColor))
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.description)
                    .font(.body.weight(.semibold))
                
                HStack(spacing: 6) {
                    if let catName = tx.categoryName {
                        Text(catName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let accName = tx.accountName {
                        Text("• \(accName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let target = tx.targetName {
                        Text("• \(target)")
                            .font(.caption.bold())
                            .foregroundColor(Brand.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatAmount(tx))
                    .font(.callout.bold())
                    .foregroundColor(colorForAmount(tx))
                
                if let num = tx.installmentNumber, let tot = tx.installmentTotal, tot > 1 {
                    Text("\(num)/\(tot)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var filteredTransactions: [Transaction] {
        transactions.filter { tx in
            if let k = selectedKind, tx.kind != k {
                return false
            }
            if !searchText.isEmpty {
                let term = searchText.lowercased()
                let matchDesc = tx.description.lowercased().contains(term)
                let matchCat = tx.categoryName?.lowercased().contains(term) ?? false
                if !matchDesc && !matchCat {
                    return false
                }
            }
            return true
        }
    }
    
    private var groupedTransactions: [String: [Transaction]] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        
        let calendar = Calendar.current
        var groups: [String: [Transaction]] = [:]
        
        for tx in filteredTransactions {
            let key: String
            if calendar.isDateInToday(tx.transactedAt) {
                key = "Hoje"
            } else if calendar.isDateInYesterday(tx.transactedAt) {
                key = "Ontem"
            } else {
                key = formatter.string(from: tx.transactedAt)
            }
            groups[key, default: []].append(tx)
        }
        return groups
    }
    
    private func formatAmount(_ tx: Transaction) -> String {
        let prefix = tx.kind == .income ? "+" : (tx.kind == .expense ? "-" : "")
        let val = Double(tx.amountCents) / 100.0
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return "\(prefix)\(f.string(from: NSNumber(value: val)) ?? "R$ 0,00")"
    }
    
    private func colorForAmount(_ tx: Transaction) -> Color {
        switch tx.kind {
        case .income: Brand.income
        case .expense: Brand.expense
        case .transfer: Brand.investment
        }
    }
    
    private func colorForCategory(_ hex: String?) -> Color {
        guard let hex = hex, hex.hasPrefix("#") else { return Brand.primary }
        return Color(hex: hex)
    }
    
    private func loadTransactions() async {
        guard let token = AuthSession.shared.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            var url = "/v1/transactions?limit=100"
            if let uid = selectedMemberID {
                url += "&user_id=\(uid.uuidString)"
            }
            let res: TransactionsResponse = try await APIClient.shared.request(url, token: token)
            self.transactions = res.transactions
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func loadMembers() async {
        guard let token = AuthSession.shared.accessToken,
              let familyID = AuthSession.shared.activeFamilyID else { return }
        do {
            let res: MembersResponse = try await APIClient.shared.request("/v1/families/\(familyID)/members", token: token)
            self.members = res.members
        } catch {}
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
