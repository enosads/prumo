import SwiftUI

public struct BudgetsView: View {
    @State private var currentDate = Date()
    @State private var budget: BudgetData?
    @State private var items: [BudgetItemDetail] = []
    @State private var summary: BudgetSummaryData?
    @State private var isLoading = false
    @State private var showSetItemSheet = false
    @State private var selectedItemToEdit: BudgetItemDetail?
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Seletor de Mês
                    HStack {
                        Button {
                            changeMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.bold())
                                .foregroundColor(Brand.primary)
                        }
                        
                        Spacer()
                        
                        Text(currentMonthLabel)
                            .font(.title3.bold())
                        
                        Spacer()
                        
                        Button {
                            changeMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3.bold())
                                .foregroundColor(Brand.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Brand.surface)
                    .cornerRadius(14)
                    .padding(.horizontal)
                    
                    // Card Principal de Saúde Orçamentária e Livre para Investir
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Livre para Investir no Mês")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Text(formatCurrency(cents: summary?.freeToInvestCents ?? 0))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.title3)
                                        .foregroundColor(Brand.accent)
                                )
                        }
                        
                        Divider().background(.white.opacity(0.3))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Receitas")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(formatCurrency(cents: summary?.totalIncomeCents ?? 0))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .center, spacing: 2) {
                                Text("Total Orçado")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(formatCurrency(cents: summary?.totalBudgetedCents ?? 0))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Total Gasto")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(formatCurrency(cents: summary?.totalSpentCents ?? 0))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(22)
                    .background(
                        LinearGradient(
                            colors: [Brand.primary, Brand.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Brand.primary.opacity(0.3), radius: 10, y: 5)
                    .padding(.horizontal)
                    
                    // Seção de Envelopes por Categoria
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Envelopes por Categoria")
                                .font(.title3.bold())
                            Spacer()
                            Button {
                                selectedItemToEdit = nil
                                showSetItemSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Brand.primary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if isLoading && items.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if items.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "envelope.badge.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.secondary)
                                Text("Nenhum envelope configurado neste mês")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Toque em '+' para definir metas de teto de gastos para suas categorias.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(28)
                            .background(Brand.surface)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(items) { item in
                                    envelopeRow(item)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle("Orçamento")
            .refreshable {
                await loadBudget()
            }
            .sheet(isPresented: $showSetItemSheet) {
                if let b = budget {
                    SetBudgetItemSheet(budgetID: b.id, item: selectedItemToEdit) {
                        Task { await loadBudget() }
                    }
                }
            }
            .task {
                await loadBudget()
            }
            .onAppear {
                Task { await loadBudget() }
            }
        }
    }
    
    private func envelopeRow(_ item: BudgetItemDetail) -> some View {
        Button {
            selectedItemToEdit = item
            showSetItemSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(colorForCategory(item.categoryColor).opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: item.categoryIcon ?? "bag.fill")
                                .foregroundColor(colorForCategory(item.categoryColor))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.categoryName)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(formatCurrency(cents: item.spentAmountCents)) de \(formatCurrency(cents: item.allocatedAmountCents))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.remainingCents >= 0 ? "Resta \(formatCurrency(cents: item.remainingCents))" : "Estourou \(formatCurrency(cents: -item.remainingCents))")
                            .font(.caption.bold())
                            .foregroundColor(item.remainingCents >= 0 ? .secondary : Brand.expense)
                        
                        Text(String(format: "%.0f%%", item.spentPercentage))
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor(item.status).opacity(0.15))
                            .foregroundColor(statusColor(item.status))
                            .cornerRadius(6)
                    }
                }
                
                // Barra de Progresso com Transição de Cor
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(statusColor(item.status))
                            .frame(
                                width: max(0, min(geo.size.width, geo.size.width * CGFloat(item.spentPercentage / 100.0))),
                                height: 8
                            )
                            .animation(.snappy, value: item.spentPercentage)
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
            .background(Brand.surface)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: currentDate).capitalized
    }
    
    private func changeMonth(by val: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: val, to: currentDate) {
            currentDate = newDate
            Task { await loadBudget() }
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "normal": Brand.income
        case "warning": Brand.warning
        case "exceeded": Brand.expense
        default: Brand.income
        }
    }
    
    private func colorForCategory(_ hex: String?) -> Color {
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
    
    private func loadBudget() async {
        guard let token = AuthSession.shared.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        let cal = Calendar.current
        let year = cal.component(.year, from: currentDate)
        let month = cal.component(.month, from: currentDate)
        
        do {
            let res: BudgetResponse = try await APIClient.shared.request(
                "/v1/budgets?year=\(year)&month=\(month)",
                token: token
            )
            self.budget = res.budget
            self.items = res.items
            self.summary = res.summary
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
