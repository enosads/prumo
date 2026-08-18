import SwiftUI

public struct SetBudgetItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let budgetID: UUID
    public let item: BudgetItemDetail?
    public var onSaved: (() -> Void)?
    
    @State private var amountCents: Int64 = 0
    @State private var selectedCategoryID: UUID?
    @State private var rolloverEnabled = false
    @State private var categories: [Category] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private struct CategoriesResponse: Codable {
        let categories: [Category]
    }
    
    private struct UpsertItemPayload: Codable {
        let category_id: UUID
        let allocated_amount_cents: Int64
        let rollover_enabled: Bool
    }
    
    public init(budgetID: UUID, item: BudgetItemDetail? = nil, onSaved: (() -> Void)? = nil) {
        self.budgetID = budgetID
        self.item = item
        self.onSaved = onSaved
        if let it = item {
            _amountCents = State(initialValue: it.allocatedAmountCents)
            _selectedCategoryID = State(initialValue: it.categoryID)
            _rolloverEnabled = State(initialValue: it.rolloverEnabled)
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Campo Monetário com teto do envelope
                VStack(spacing: 6) {
                    Text("Teto Mensal do Envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    CampoMonetario(amountCents: $amountCents, fontSize: 36)
                        .foregroundColor(Brand.primary)
                }
                .padding(.top)
                
                // Teclado Numérico Rápido
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(1...9, id: \.self) { num in
                        Button {
                            appendDigit(num)
                        } label: {
                            Text("\(num)")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Brand.surface)
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                    
                    Button {
                        amountCents = 0
                    } label: {
                        Text("C")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Brand.surface)
                            .foregroundColor(.secondary)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        appendDigit(0)
                    } label: {
                        Text("0")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Brand.surface)
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        deleteDigit()
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Brand.surface)
                            .foregroundColor(.secondary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Seletor de Categoria (se novo envelope)
                if item == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categoria do Envelope")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories) { cat in
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
                    .padding(.horizontal)
                }
                
                // Opção de Rollover
                Toggle(isOn: $rolloverEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Acúmulo de Saldo (Rollover)")
                            .font(.subheadline.weight(.semibold))
                        Text("Transfere saldo positivo ou negativo restante para o mês seguinte.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Brand.surface)
                .cornerRadius(14)
                .padding(.horizontal)
                
                if let err = errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(Brand.expense)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle(item == nil ? "Novo Envelope" : "Ajustar Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await saveBudgetItem() }
                    }
                    .fontWeight(.bold)
                    .disabled(selectedCategoryID == nil || isSaving)
                }
            }
            .task {
                await loadCategories()
            }
        }
    }
    
    private func appendDigit(_ d: Int) {
        if amountCents < 100_000_000 {
            amountCents = amountCents * 10 + Int64(d)
        }
    }
    
    private func deleteDigit() {
        amountCents = amountCents / 10
    }
    
    private func loadCategories() async {
        guard let token = AuthSession.shared.accessToken, item == nil else { return }
        do {
            let res: CategoriesResponse = try await APIClient.shared.request("/v1/categories", token: token)
            self.categories = res.categories.filter { $0.kind == .expense || $0.kind == .both }
            if selectedCategoryID == nil, let first = self.categories.first {
                self.selectedCategoryID = first.id
            }
        } catch {}
    }
    
    private func saveBudgetItem() async {
        guard let token = AuthSession.shared.accessToken,
              let catID = selectedCategoryID else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        let payload = UpsertItemPayload(
            category_id: catID,
            allocated_amount_cents: amountCents,
            rollover_enabled: rolloverEnabled
        )
        
        do {
            let _: [String: AnyCodable] = try await APIClient.shared.request(
                "/v1/budgets/\(budgetID)/items",
                method: "PUT",
                body: payload,
                token: token
            )
            onSaved?()
            dismiss()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
