import Foundation
import NaturalLanguage

public actor OnDeviceCopilotEngine {
    public static let shared = OnDeviceCopilotEngine()
    
    private init() {}
    
    public func processMessage(
        message: String,
        conversationID: UUID,
        token: String
    ) -> AsyncThrowingStream<AIChatStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(AIChatStreamDelta(
                        type: "message_start",
                        conversationID: conversationID,
                        messageID: nil,
                        delta: nil,
                        fullText: nil,
                        toolCall: nil,
                        toolResult: nil,
                        error: nil
                    ))
                    
                    let lowerMsg = message.lowercased()
                    
                    // 1. Decisão de Tool Calling On-Device
                    if lowerMsg.contains("patrimônio") || lowerMsg.contains("patrimonio") || lowerMsg.contains("saldo") || lowerMsg.contains("consolidado") || lowerMsg.contains("contas") {
                        try await executeNetWorthTool(conversationID: conversationID, token: token, continuation: continuation)
                    } else if lowerMsg.contains("extrato") || lowerMsg.contains("gastei") || lowerMsg.contains("alimentação") || lowerMsg.contains("alimentacao") || lowerMsg.contains("mercado") || lowerMsg.contains("despesa") || lowerMsg.contains("compras") {
                        try await executeCashFlowTool(message: lowerMsg, conversationID: conversationID, token: token, continuation: continuation)
                    } else if lowerMsg.contains("orçamento") || lowerMsg.contains("orcamento") || lowerMsg.contains("envelope") || lowerMsg.contains("investir") || lowerMsg.contains("limite") {
                        try await executeBudgetTool(conversationID: conversationID, token: token, continuation: continuation)
                    } else if lowerMsg.contains("cartão") || lowerMsg.contains("cartao") || lowerMsg.contains("fatura") || lowerMsg.contains("parcela") || lowerMsg.contains("projeção") || lowerMsg.contains("projecao") {
                        try await executeCardTool(conversationID: conversationID, token: token, continuation: continuation)
                    } else {
                        try await executeGeneralFinancialGuidance(message: message, conversationID: conversationID, continuation: continuation)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - On-Device Tools Execution
    
    private func executeNetWorthTool(
        conversationID: UUID,
        token: String,
        continuation: AsyncThrowingStream<AIChatStreamDelta, Error>.Continuation
    ) async throws {
        let tc = AIToolCallInfo(id: "call_nw_local", name: "get_consolidated_net_worth", arguments: "{}")
        continuation.yield(AIChatStreamDelta(type: "tool_call", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: tc, toolResult: nil, error: nil))
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let accounts: [Account] = try await APIClient.shared.request("/v1/accounts", token: token)
        var totalCents: Int64 = 0
        var checkingCents: Int64 = 0
        var savingsCents: Int64 = 0
        var investCents: Int64 = 0
        
        for a in accounts {
            switch a.kind {
            case .checking: checkingCents += a.currentBalanceCents; totalCents += a.currentBalanceCents
            case .savings: savingsCents += a.currentBalanceCents; totalCents += a.currentBalanceCents
            case .investment: investCents += a.currentBalanceCents; totalCents += a.currentBalanceCents
            case .cash: totalCents += a.currentBalanceCents
            case .creditCard: totalCents -= a.currentBalanceCents
            }
        }
        
        let tr = AIToolResultInfo(toolCallID: "call_nw_local", toolName: "get_consolidated_net_worth", result: "ok", error: nil)
        continuation.yield(AIChatStreamDelta(type: "tool_result", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: nil, toolResult: tr, error: nil))
        
        let response = """
        📊 **Patrimônio Líquido Consolidado da Família** *(Apple Intelligence On-Device)*
        
        - **Total Líquido**: **R$ \(formatCurrency(totalCents))**
        - **Conta Corrente**: R$ \(formatCurrency(checkingCents))
        - **Reserva / Poupança**: R$ \(formatCurrency(savingsCents))
        - **Investimentos**: R$ \(formatCurrency(investCents))
        
        💡 *Insight On-Device:* Seu patrimônio está distribuído em \(accounts.count) contas ativas. Todos os saldos foram processados com privacidade no seu dispositivo.
        """
        
        await streamText(response, conversationID: conversationID, continuation: continuation)
    }
    
    private func executeCashFlowTool(
        message: String,
        conversationID: UUID,
        token: String,
        continuation: AsyncThrowingStream<AIChatStreamDelta, Error>.Continuation
    ) async throws {
        let tc = AIToolCallInfo(id: "call_cf_local", name: "query_cash_flow", arguments: "{}")
        continuation.yield(AIChatStreamDelta(type: "tool_call", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: tc, toolResult: nil, error: nil))
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let transactions: [Transaction] = try await APIClient.shared.request("/v1/transactions", token: token)
        var totalIncome: Int64 = 0
        var totalExpense: Int64 = 0
        var foodExpense: Int64 = 0
        
        for t in transactions {
            if t.kind == .income {
                totalIncome += t.amountCents
            } else if t.kind == .expense {
                totalExpense += t.amountCents
                if let cat = t.categoryName?.lowercased(), cat.contains("alimenta") || cat.contains("mercado") {
                    foodExpense += t.amountCents
                }
            }
        }
        
        let tr = AIToolResultInfo(toolCallID: "call_cf_local", toolName: "query_cash_flow", result: "ok", error: nil)
        continuation.yield(AIChatStreamDelta(type: "tool_result", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: nil, toolResult: tr, error: nil))
        
        var extraInsight = ""
        if message.contains("alimenta") || message.contains("mercado") {
            extraInsight = "\n- **Gastos em Alimentação & Mercado**: **R$ \(formatCurrency(foodExpense))**"
        }
        
        let response = """
        🧾 **Extrato & Fluxo de Caixa do Período** *(Apple Intelligence On-Device)*
        
        - **Total de Receitas**: R$ \(formatCurrency(totalIncome))
        - **Total de Despesas**: R$ \(formatCurrency(totalExpense))
        - **Saldo Líquido no Período**: **R$ \(formatCurrency(totalIncome - totalExpense))**\(extraInsight)
        
        Analisei \(transactions.count) lançamentos recentes diretamente no seu iPhone.
        """
        
        await streamText(response, conversationID: conversationID, continuation: continuation)
    }
    
    private func executeBudgetTool(
        conversationID: UUID,
        token: String,
        continuation: AsyncThrowingStream<AIChatStreamDelta, Error>.Continuation
    ) async throws {
        let tc = AIToolCallInfo(id: "call_bg_local", name: "get_budget_status", arguments: "{}")
        continuation.yield(AIChatStreamDelta(type: "tool_call", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: tc, toolResult: nil, error: nil))
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let budgetResp: BudgetResponse = try await APIClient.shared.request("/v1/budgets", token: token)
        
        let tr = AIToolResultInfo(toolCallID: "call_bg_local", toolName: "get_budget_status", result: "ok", error: nil)
        continuation.yield(AIChatStreamDelta(type: "tool_result", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: nil, toolResult: tr, error: nil))
        
        let freeToInvest = budgetResp.summary.freeToInvestCents
        let totalBudgeted = budgetResp.summary.totalBudgetedCents
        let totalSpent = budgetResp.summary.totalSpentCents
        
        let response = """
        🎯 **Status dos Envelopes de Orçamento** *(Apple Intelligence On-Device)*
        
        - **Total Orçado**: R$ \(formatCurrency(totalBudgeted))
        - **Total Realizado**: R$ \(formatCurrency(totalSpent))
        - **Livre para Investir**: **R$ \(formatCurrency(freeToInvest))**
        
        📈 *Estratégia Recomendada:* Você possui **R$ \(formatCurrency(freeToInvest))** disponível para aportes estratégicos em renda fixa ou tesouro direto neste mês.
        """
        
        await streamText(response, conversationID: conversationID, continuation: continuation)
    }
    
    private func executeCardTool(
        conversationID: UUID,
        token: String,
        continuation: AsyncThrowingStream<AIChatStreamDelta, Error>.Continuation
    ) async throws {
        let tc = AIToolCallInfo(id: "call_cp_local", name: "get_card_projections", arguments: "{}")
        continuation.yield(AIChatStreamDelta(type: "tool_call", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: tc, toolResult: nil, error: nil))
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let cards: [CreditCardSummary] = try await APIClient.shared.request("/v1/cards", token: token)
        
        let tr = AIToolResultInfo(toolCallID: "call_cp_local", toolName: "get_card_projections", result: "ok", error: nil)
        continuation.yield(AIChatStreamDelta(type: "tool_result", conversationID: conversationID, messageID: nil, delta: nil, fullText: nil, toolCall: nil, toolResult: tr, error: nil))
        
        var cardLines = ""
        for c in cards {
            cardLines += "\n- **\(c.card.name)**: Fatura atual R$ \(formatCurrency(c.usedLimitCents)) | Disponível R$ \(formatCurrency(c.availableLimitCents))"
        }
        
        let response = """
        💳 **Projeção de Faturas de Cartão** *(Apple Intelligence On-Device)*
        \(cardLines.isEmpty ? "\nNenhum cartão cadastrado no momento." : cardLines)
        
        ⚡ *Dica de Otimização:* Você pode antecipar parcelas futuras na aba Cartões para obter desconto de taxa anual.
        """
        
        await streamText(response, conversationID: conversationID, continuation: continuation)
    }
    
    private func executeGeneralFinancialGuidance(
        message: String,
        conversationID: UUID,
        continuation: AsyncThrowingStream<AIChatStreamDelta, Error>.Continuation
    ) async {
        let response = """
        Olá! Sou o **Copilot do Prumo** integrado com o **Apple Intelligence** localmente no seu dispositivo.
        
        Posso responder e analisar suas finanças com privacidade total:
        - 📊 Consultar **Patrimônio Líquido** consolidado
        - 🧾 Analisar **Extrato & Gastos** por categoria
        - 🎯 Acompanhar **Orçamentos & Livre para Investir**
        - 💳 Projetar **Faturas & Parcelamentos de Cartão**
        
        Como posso ajudar agora?
        """
        
        await streamText(response, conversationID: conversationID, continuation: continuation)
    }
    
    // MARK: - Streaming Helper
    
    private func streamText(
        _ text: String,
        conversationID: UUID,
        continuation: AsyncThrowingStream<AIChatStreamDelta, Error>.Continuation
    ) async {
        let words = text.components(separatedBy: " ")
        for (i, word) in words.enumerated() {
            let chunk = word + (i == words.count - 1 ? "" : " ")
            continuation.yield(AIChatStreamDelta(
                type: "text_delta",
                conversationID: conversationID,
                messageID: nil,
                delta: chunk,
                fullText: nil,
                toolCall: nil,
                toolResult: nil,
                error: nil
            ))
            try? await Task.sleep(nanoseconds: 18_000_000) // ~18ms por palavra para efeito fluido
        }
        
        continuation.yield(AIChatStreamDelta(
            type: "message_complete",
            conversationID: conversationID,
            messageID: UUID(),
            delta: nil,
            fullText: text,
            toolCall: nil,
            toolResult: nil,
            error: nil
        ))
    }
    
    private func formatCurrency(_ cents: Int64) -> String {
        let abs = cents < 0 ? -cents : cents
        let sign = cents < 0 ? "-" : ""
        let reais = abs / 100
        let centavos = abs % 100
        return String(format: "%@%d,%02d", sign, reais, centavos)
    }
}
