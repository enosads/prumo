import AppIntents
import Foundation

// MARK: - App Shortcuts Provider para Apple Intelligence & Siri

public struct PrumoShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetNetWorthIntent(),
            phrases: [
                "Qual é o meu patrimônio no \(.applicationName)?",
                "Consultar saldo consolidado no \(.applicationName)",
                "Ver patrimônio familiar no \(.applicationName)"
            ],
            shortTitle: "Patrimônio Consolidado",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: QueryCashFlowIntent(),
            phrases: [
                "Quanto gastei este mês no \(.applicationName)?",
                "Ver extrato do mês no \(.applicationName)",
                "Gastos da família no \(.applicationName)"
            ],
            shortTitle: "Extrato do Mês",
            systemImageName: "list.bullet.rectangle.fill"
        )
        AppShortcut(
            intent: GetBudgetStatusIntent(),
            phrases: [
                "Como estão os orçamentos no \(.applicationName)?",
                "Ver envelopes de orçamento no \(.applicationName)",
                "Quanto tenho livre para investir no \(.applicationName)?"
            ],
            shortTitle: "Status dos Orçamentos",
            systemImageName: "envelope.badge.fill"
        )
        AppShortcut(
            intent: GetCardProjectionsIntent(),
            phrases: [
                "Qual a fatura do cartão no \(.applicationName)?",
                "Ver parcelas futuras no \(.applicationName)",
                "Projeção de cartões no \(.applicationName)"
            ],
            shortTitle: "Faturas de Cartão",
            systemImageName: "creditcard.fill"
        )
    }
}

// MARK: - Intent 1: Consulta de Patrimônio Consolidado

public struct GetNetWorthIntent: AppIntent {
    public static var title: LocalizedStringResource = "Consultar Patrimônio Consolidado"
    public static var description: LocalizedStringResource = "Calcula o patrimônio líquido consolidado e saldo de todas as contas da família."
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = await AuthSession.shared.accessToken else {
            return .result(dialog: "Por favor, abra o Prumo e faça login para consultar suas informações.")
        }
        
        do {
            let accounts: [Account] = try await APIClient.shared.request("/v1/accounts", token: token)
            var totalCents: Int64 = 0
            for a in accounts {
                if a.kind == .creditCard {
                    totalCents -= a.currentBalanceCents
                } else {
                    totalCents += a.currentBalanceCents
                }
            }
            let reais = Double(totalCents) / 100.0
            let formatted = String(format: "R$ %.2f", reais)
            return .result(dialog: "Seu patrimônio líquido consolidado familiar é de \(formatted), distribuído em \(accounts.count) contas.")
        } catch {
            return .result(dialog: "Não foi possível consultar as contas no momento.")
        }
    }
}

// MARK: - Intent 2: Consulta de Extrato & Gastos

public struct QueryCashFlowIntent: AppIntent {
    public static var title: LocalizedStringResource = "Consultar Extrato e Gastos"
    public static var description: LocalizedStringResource = "Consulta o extrato de lançamentos e fluxo de caixa da família."
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = await AuthSession.shared.accessToken else {
            return .result(dialog: "Por favor, faça login no Prumo.")
        }
        
        do {
            let transactions: [Transaction] = try await APIClient.shared.request("/v1/transactions", token: token)
            var totalExpenseCents: Int64 = 0
            for t in transactions where t.kind == .expense {
                totalExpenseCents += t.amountCents
            }
            let formatExpense = String(format: "R$ %.2f", Double(totalExpenseCents) / 100.0)
            return .result(dialog: "Nos lançamentos recentes, foram registrados \(formatExpense) em despesas na família.")
        } catch {
            return .result(dialog: "Não foi possível carregar o extrato.")
        }
    }
}

// MARK: - Intent 3: Status dos Envelopes de Orçamento

public struct GetBudgetStatusIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ver Envelopes de Orçamento"
    public static var description: LocalizedStringResource = "Verifica o progresso dos envelopes mensais e o valor livre para investir."
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = await AuthSession.shared.accessToken else {
            return .result(dialog: "Por favor, faça login no Prumo.")
        }
        
        do {
            let budgetResp: BudgetResponse = try await APIClient.shared.request("/v1/budgets", token: token)
            let freeToInvest = String(format: "R$ %.2f", Double(budgetResp.summary.freeToInvestCents) / 100.0)
            let totalSpent = String(format: "R$ %.2f", Double(budgetResp.summary.totalSpentCents) / 100.0)
            return .result(dialog: "Seus orçamentos somam \(totalSpent) realizados. Você possui \(freeToInvest) Livre para Investir este mês.")
        } catch {
            return .result(dialog: "Não foi possível carregar os orçamentos.")
        }
    }
}

// MARK: - Intent 4: Projeção de Faturas de Cartão

public struct GetCardProjectionsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Consultar Faturas de Cartão"
    public static var description: LocalizedStringResource = "Consulta limites e próximas faturas dos cartões de crédito da família."
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = await AuthSession.shared.accessToken else {
            return .result(dialog: "Por favor, faça login no Prumo.")
        }
        
        do {
            let cards: [CreditCardSummary] = try await APIClient.shared.request("/v1/cards", token: token)
            if cards.isEmpty {
                return .result(dialog: "Nenhum cartão de crédito cadastrado na família.")
            }
            let first = cards[0]
            let used = String(format: "R$ %.2f", Double(first.usedLimitCents) / 100.0)
            let avail = String(format: "R$ %.2f", Double(first.availableLimitCents) / 100.0)
            return .result(dialog: "Cartão \(first.card.name): \(used) em fatura e limite disponível de \(avail).")
        } catch {
            return .result(dialog: "Não foi possível carregar os cartões.")
        }
    }
}
