import SwiftUI

public struct NewTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var amountCents: Int64 = 0
    @State private var kind: TransactionKind = .expense
    @State private var descriptionText: String = ""
    @State private var selectedAccountID: UUID?
    @State private var selectedDestinationAccountID: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var selectedTargetUserID: UUID?
    @State private var transactedAt: Date = Date()
    @State private var installmentTotal: Int = 1
    @State private var tagsText: String = ""
    @State private var notesText: String = ""
    
    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var members: [FamilyMember] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    public var onSaved: (() -> Void)?
    
    public init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }
    
    private struct AccountsResponse: Codable {
        let accounts: [Account]
    }
    
    private struct CategoriesResponse: Codable {
        let categories: [Category]
    }
    
    private struct MembersResponse: Codable {
        let members: [FamilyMember]
    }
    
    private struct CreateTxPayload: Codable {
        let account_id: UUID
        let category_id: UUID?
        let destination_account_id: UUID?
        let target_user_id: UUID?
        let kind: String
        let amount_cents: Int64
        let description: String
        let transacted_at: Date
        let installment_total: Int
        let tags: [String]
        let notes: String?
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Seletor de Tipo (Segmented)
                    Picker("Tipo", selection: $kind) {
                        Text("Despesa").tag(TransactionKind.expense)
                        Text("Receita").tag(TransactionKind.income)
                        Text("Transferência").tag(TransactionKind.transfer)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Campo Monetário com valor grande
                    VStack(spacing: 8) {
                        Text(kind == .income ? "Valor a Receber" : (kind == .expense ? "Valor a Pagar" : "Valor a Transferir"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        CampoMonetario(amountCents: $amountCents, fontSize: 40)
                            .foregroundColor(kindColor)
                    }
                    .padding(.vertical, 8)
                    
                    // Teclado Numérico Rápido / Numpad
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(1...9, id: \.self) { num in
                            Button {
                                appendDigit(num)
                            } label: {
                                Text("\(num)")
                                    .font(.title2.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Brand.surface)
                                    .foregroundColor(.primary)
                                    .cornerRadius(14)
                            }
                        }
                        
                        Button {
                            amountCents = 0
                        } label: {
                            Text("C")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Brand.surface)
                                .foregroundColor(.secondary)
                                .cornerRadius(14)
                        }
                        
                        Button {
                            appendDigit(0)
                        } label: {
                            Text("0")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Brand.surface)
                                .foregroundColor(.primary)
                                .cornerRadius(14)
                        }
                        
                        Button {
                            deleteDigit()
                        } label: {
                            Image(systemName: "delete.left.fill")
                                .font(.title3)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Brand.surface)
                                .foregroundColor(.secondary)
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Detalhes do Lançamento
                    VStack(spacing: 16) {
                        // Descrição
                        TextField("Descrição (ex: Supermercado, Aluguel)", text: $descriptionText)
                            .padding()
                            .background(Brand.surface)
                            .cornerRadius(12)
                        
                        // Conta de Origem
                        VStack(alignment: .leading, spacing: 6) {
                            Text(kind == .transfer ? "Conta de Origem" : "Conta / Carteira")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(accounts) { acc in
                                        Button {
                                            selectedAccountID = acc.id
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: iconForKind(acc.kind))
                                                Text(acc.name)
                                                    .font(.subheadline.bold())
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(selectedAccountID == acc.id ? Brand.primary : Brand.surface)
                                            .foregroundColor(selectedAccountID == acc.id ? .white : .primary)
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Conta de Destino (para transferências)
                        if kind == .transfer {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Conta de Destino")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(accounts.filter { $0.id != selectedAccountID }) { acc in
                                            Button {
                                                selectedDestinationAccountID = acc.id
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: iconForKind(acc.kind))
                                                    Text(acc.name)
                                                        .font(.subheadline.bold())
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(selectedDestinationAccountID == acc.id ? Brand.primary : Brand.surface)
                                                .foregroundColor(selectedDestinationAccountID == acc.id ? .white : .primary)
                                                .cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Categoria (para receitas e despesas)
                        if kind != .transfer {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Categoria")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(filteredCategories) { cat in
                                            Button {
                                                selectedCategoryID = cat.id
                                            } label: {
                                                HStack(spacing: 6) {
                                                    if let icon = cat.icon {
                                                        Image(systemName: icon)
                                                    }
                                                    Text(cat.name)
                                                        .font(.subheadline.bold())
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(selectedCategoryID == cat.id ? Brand.primary : Brand.surface)
                                                .foregroundColor(selectedCategoryID == cat.id ? .white : .primary)
                                                .cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Parcelamento (se conta for cartão de crédito e tipo despesa)
                        if isSelectedAccountCreditCard && kind == .expense {
                            HStack {
                                Label("Parcelamento", systemImage: "creditcard.fill")
                                    .font(.subheadline)
                                Spacer()
                                Picker("Parcelas", selection: $installmentTotal) {
                                    ForEach(1...24, id: \.self) { n in
                                        Text(n == 1 ? "À vista (1x)" : "\(n)x de \(formatInstallment(n))")
                                            .tag(n)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding()
                            .background(Brand.surface)
                            .cornerRadius(12)
                        }
                        
                        // Data da Transação
                        DatePicker("Data", selection: $transactedAt, displayedComponents: [.date, .hourAndMinute])
                            .padding()
                            .background(Brand.surface)
                            .cornerRadius(12)
                        
                        // Membro Responsável (Casal / Família)
                        if !members.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Responsável pelo Gasto")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(members) { m in
                                            Button {
                                                selectedTargetUserID = m.userID
                                            } label: {
                                                Text(m.nickname ?? m.fullName)
                                                    .font(.subheadline.bold())
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(selectedTargetUserID == m.userID ? Brand.secondary : Brand.surface)
                                                    .foregroundColor(selectedTargetUserID == m.userID ? .white : .primary)
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(Brand.expense)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle("Novo Lançamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await saveTransaction() }
                    }
                    .fontWeight(.bold)
                    .disabled(amountCents <= 0 || isSaving)
                }
            }
            .task {
                await loadDependencies()
            }
        }
    }
    
    private var kindColor: Color {
        switch kind {
        case .income: Brand.income
        case .expense: Brand.expense
        case .transfer: Brand.investment
        }
    }
    
    private var filteredCategories: [Category] {
        categories.filter { cat in
            if kind == .income {
                return cat.kind == .income || cat.kind == .both
            } else {
                return cat.kind == .expense || cat.kind == .both
            }
        }
    }
    
    private var isSelectedAccountCreditCard: Bool {
        accounts.first { $0.id == selectedAccountID }?.kind == .creditCard
    }
    
    private func appendDigit(_ d: Int) {
        if amountCents < 100_000_000 {
            amountCents = amountCents * 10 + Int64(d)
        }
    }
    
    private func deleteDigit() {
        amountCents = amountCents / 10
    }
    
    private func formatInstallment(_ n: Int) -> String {
        let part = Double(amountCents / Int64(n)) / 100.0
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: part)) ?? "R$ 0,00"
    }
    
    private struct CreateAccountPayload: Codable {
        let name: String
        let kind: String
        let visibility: String
        let currency: String
        let initial_balance_cents: Int64
        let color: String
    }
    
    private struct CreateAccountResponse: Codable {
        let account: Account
    }
    
    private func loadDependencies() async {
        guard let token = AuthSession.shared.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let accReq: AccountsResponse = APIClient.shared.request("/v1/accounts", token: token)
            async let catReq: CategoriesResponse = APIClient.shared.request("/v1/categories", token: token)
            
            let (accRes, catRes) = try await (accReq, catReq)
            
            if accRes.accounts.isEmpty {
                let initialAccount = CreateAccountPayload(
                    name: "Conta Principal",
                    kind: "checking",
                    visibility: "shared",
                    currency: "BRL",
                    initial_balance_cents: 0,
                    color: "#007AFF"
                )
                do {
                    let created: CreateAccountResponse = try await APIClient.shared.request(
                        "/v1/accounts",
                        method: "POST",
                        body: initialAccount,
                        token: token
                    )
                    self.accounts = [created.account]
                    self.selectedAccountID = created.account.id
                } catch {
                    self.accounts = []
                }
            } else {
                self.accounts = accRes.accounts
                if selectedAccountID == nil, let first = accRes.accounts.first {
                    self.selectedAccountID = first.id
                }
            }
            
            self.categories = catRes.categories
            if selectedCategoryID == nil, let firstCat = catRes.categories.first {
                self.selectedCategoryID = firstCat.id
            }
            
            if let familyID = AuthSession.shared.activeFamilyID {
                let memRes: MembersResponse = try await APIClient.shared.request("/v1/families/\(familyID)/members", token: token)
                self.members = memRes.members
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func saveTransaction() async {
        guard let token = AuthSession.shared.accessToken,
              let accID = selectedAccountID else {
            self.errorMessage = "Selecione uma conta para registrar a transação."
            return
        }
        
        isSaving = true
        defer { isSaving = false }
        
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (kind == .income ? "Receita" : (kind == .transfer ? "Transferência" : "Despesa"))
            : descriptionText
        
        let payload = CreateTxPayload(
            account_id: accID,
            category_id: kind == .transfer ? nil : selectedCategoryID,
            destination_account_id: kind == .transfer ? selectedDestinationAccountID : nil,
            target_user_id: selectedTargetUserID,
            kind: kind.rawValue,
            amount_cents: amountCents,
            description: desc,
            transacted_at: transactedAt,
            installment_total: installmentTotal,
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            notes: notesText.isEmpty ? nil : notesText
        )
        
        do {
            try await APIClient.shared.send(
                "/v1/transactions",
                method: "POST",
                body: payload,
                token: token
            )
            onSaved?()
            dismiss()
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
}
