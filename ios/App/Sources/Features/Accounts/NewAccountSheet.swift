import SwiftUI

public struct NewAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var kind: AccountKind = .checking
    @State private var initialBalanceCents: Int64 = 0
    @State private var selectedColor: String = "#007AFF"
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    public var onSaved: ((Account) -> Void)?
    
    public init(onSaved: ((Account) -> Void)? = nil) {
        self.onSaved = onSaved
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
    
    private let colors = ["#007AFF", "#34C759", "#AF52DE", "#FF9500", "#FF2D55", "#5856D6", "#32ADE6"]
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Tipo da Conta
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo de Conta")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                kindButton("Conta Corrente", kind: .checking, icon: "building.columns.fill")
                                kindButton("Poupança / Reserva", kind: .savings, icon: "banknote.fill")
                                kindButton("Investimento", kind: .investment, icon: "chart.pie.fill")
                                kindButton("Dinheiro / Carteira", kind: .cash, icon: "dollarsign.circle.fill")
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Nome da Conta
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nome da Conta")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        TextField("Ex: Nubank Principal, Itaú, Carteira", text: $name)
                            .padding()
                            .background(Brand.surface)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Saldo Inicial
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saldo Inicial")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        CampoMonetario(amountCents: $initialBalanceCents, fontSize: 32)
                            .foregroundColor(Brand.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(Brand.surface)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    
                    // Paleta de Cor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cor de Identificação")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { hex in
                                Button {
                                    selectedColor = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 38, height: 38)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == hex ? 3 : 0)
                                        )
                                        .shadow(radius: selectedColor == hex ? 4 : 0)
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
            .navigationTitle("Nova Conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await saveAccount() }
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
    
    private func kindButton(_ title: String, kind: AccountKind, icon: String) -> some View {
        Button {
            self.kind = kind
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(self.kind == kind ? Brand.primary : Brand.surface)
            .foregroundColor(self.kind == kind ? .white : .primary)
            .cornerRadius(12)
        }
    }
    
    private func saveAccount() async {
        guard let token = AuthSession.shared.accessToken else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        let payload = CreateAccountPayload(
            name: name.trimmingCharacters(in: .whitespaces),
            kind: kind.rawValue,
            visibility: "shared",
            currency: "BRL",
            initial_balance_cents: initialBalanceCents,
            color: selectedColor
        )
        
        do {
            let res: CreateAccountResponse = try await APIClient.shared.request(
                "/v1/accounts",
                method: "POST",
                body: payload,
                token: token
            )
            onSaved?(res.account)
            dismiss()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
