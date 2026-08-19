import SwiftUI

public struct ChatView: View {
    @State private var messages: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var conversationID: UUID?
    @State private var isStreaming: Bool = false
    @State private var activeToolCall: String?
    @State private var errorMessage: String?
    
    private let suggestions = [
        "📊 Qual é o patrimônio líquido consolidado da família?",
        "🧾 Quanto gastamos com alimentação este mês?",
        "🎯 Como estão os envelopes de orçamento e o Livre para Investir?",
        "💳 Qual a projeção das faturas de cartão de crédito para os próximos meses?"
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyStateView
                } else {
                    messagesScrollView
                }
                
                if let tool = activeToolCall {
                    activeToolIndicator(tool)
                }
                
                if let err = errorMessage {
                    errorBanner(err)
                }
                
                inputBar
            }
            .background(Brand.background)
            .navigationTitle("Copilot de IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: resetConversation) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Brand.primary)
                    }
                    .disabled(isStreaming)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                
                ZStack {
                    Circle()
                        .fill(Brand.primary.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                }
                
                VStack(spacing: 8) {
                    Text("Copilot Financeiro Familiar")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.primary)
                    
                    Text("Faça perguntas sobre suas contas, extratos, orçamentos e cartões em linguagem natural.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sugestões rápidas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                    
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            sendMessage(suggestion)
                        }) {
                            HStack {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Brand.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Brand.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(uiColor: .separator), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Messages ScrollView
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.last?.content) {
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // MARK: - Message Bubble
    
    private func messageBubble(_ msg: AIChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if msg.role == .assistant {
                ZStack {
                    Circle()
                        .fill(Brand.primary.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                }
            } else {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 6) {
                if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                    ForEach(toolCalls) { tc in
                        toolCallBadge(tc.name)
                    }
                }
                
                if !msg.content.isEmpty {
                    Text(LocalizedStringKey(msg.content))
                        .font(.body)
                        .foregroundStyle(msg.role == .user ? Color.white : Color.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            msg.role == .user
                                ? Brand.primary
                                : Brand.surface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(msg.role == .user ? Color.clear : Color(uiColor: .separator), lineWidth: 1)
                        )
                }
                
                Text(msg.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 4)
            }
            
            if msg.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Tool Badge
    
    private func toolCallBadge(_ toolName: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: toolIcon(for: toolName))
                .font(.caption)
            Text(toolDisplayName(for: toolName))
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Brand.primary.opacity(0.1))
        .foregroundStyle(Brand.primary)
        .clipShape(Capsule())
    }
    
    private func activeToolIndicator(_ toolName: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(Brand.primary)
                .controlSize(.small)
            Text(toolActiveName(for: toolName))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Brand.surface)
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.primary)
            Spacer()
            Button("Dispensar") {
                errorMessage = nil
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Brand.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary)
                }
                
                TextField("Mensagem ou comando financeiro...", text: $inputText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(uiColor: .separator), lineWidth: 1)
                    )
                
                Button(action: {
                    let text = inputText
                    inputText = ""
                    sendMessage(text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming ? Color.secondary.opacity(0.4) : Brand.primary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Brand.background)
        }
    }
    
    // MARK: - Actions & Streaming
    
    private func sendMessage(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        
        errorMessage = nil
        let session = AuthSession.shared
        guard let token = session.accessToken else {
            errorMessage = "Autenticação necessária para usar o Copilot."
            return
        }
        
        let userMsg = AIChatMessage(
            conversationID: conversationID ?? UUID(),
            role: .user,
            content: text
        )
        messages.append(userMsg)
        
        let assistantMsgID = UUID()
        let assistantMsg = AIChatMessage(
            id: assistantMsgID,
            conversationID: conversationID ?? UUID(),
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMsg)
        
        isStreaming = true
        activeToolCall = nil
        
        Task {
            do {
                let stream = APIClient.shared.streamAIChat(
                    conversationID: conversationID,
                    message: text,
                    token: token
                )
                
                for try await delta in stream {
                    await MainActor.run {
                        if let convID = delta.conversationID {
                            self.conversationID = convID
                        }
                        
                        if let lastIdx = messages.firstIndex(where: { $0.id == assistantMsgID }) {
                            switch delta.type {
                            case "tool_call":
                                if let tc = delta.toolCall {
                                    self.activeToolCall = tc.name
                                    var currentCalls = messages[lastIdx].toolCalls ?? []
                                    currentCalls.append(tc)
                                    messages[lastIdx].toolCalls = currentCalls
                                }
                            case "tool_result":
                                self.activeToolCall = nil
                            case "text_delta":
                                if let chunk = delta.delta {
                                    messages[lastIdx].content += chunk
                                }
                            case "message_complete":
                                if let full = delta.fullText {
                                    messages[lastIdx].content = full
                                }
                                messages[lastIdx].isStreaming = false
                                self.activeToolCall = nil
                            case "error":
                                if let err = delta.error {
                                    self.errorMessage = err
                                }
                            default:
                                break
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    self.isStreaming = false
                    self.activeToolCall = nil
                    if let lastIdx = messages.firstIndex(where: { $0.id == assistantMsgID }) {
                        messages[lastIdx].isStreaming = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isStreaming = false
                    self.activeToolCall = nil
                    self.errorMessage = error.localizedDescription
                    if let lastIdx = messages.firstIndex(where: { $0.id == assistantMsgID }) {
                        messages[lastIdx].isStreaming = false
                        if messages[lastIdx].content.isEmpty {
                            messages.remove(at: lastIdx)
                        }
                    }
                }
            }
        }
    }
    
    private func resetConversation() {
        messages = []
        conversationID = nil
        errorMessage = nil
        activeToolCall = nil
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    
    private func toolIcon(for name: String) -> String {
        switch name {
        case "get_consolidated_net_worth": "chart.pie.fill"
        case "query_cash_flow": "list.bullet.rectangle.fill"
        case "get_budget_status": "envelope.badge.fill"
        case "get_card_projections": "creditcard.fill"
        default: "wrench.and.screwdriver.fill"
        }
    }
    
    private func toolDisplayName(for name: String) -> String {
        switch name {
        case "get_consolidated_net_worth": "Consulta de Patrimônio Líquido"
        case "query_cash_flow": "Extrato & Fluxo de Caixa"
        case "get_budget_status": "Status dos Envelopes"
        case "get_card_projections": "Projeção de Cartões"
        default: "Ferramenta Financeira"
        }
    }
    
    private func toolActiveName(for name: String) -> String {
        switch name {
        case "get_consolidated_net_worth": "Consultando patrimônio consolidado..."
        case "query_cash_flow": "Filtrando lançamentos e extrato..."
        case "get_budget_status": "Calculando envelopes e Livre para Investir..."
        case "get_card_projections": "Projetando parcelas e faturas..."
        default: "Executando ferramenta..."
        }
    }
}
