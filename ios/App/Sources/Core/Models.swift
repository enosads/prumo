import Foundation

// MARK: - Autenticação & Usuário

public struct AuthUser: Codable, Identifiable, Sendable {
    public let id: UUID
    public let email: String
    public let fullName: String
    public let avatarURL: String?
    public let familyID: UUID?
    public let role: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case familyID = "family_id"
        case role
    }
}

public struct AuthResponse: Codable, Sendable {
    public let user: AuthUser
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

public struct MeResponse: Codable, Sendable {
    public let user: AuthUser
    public let families: [FamilySummary]
}

// MARK: - Núcleo Familiar

public struct FamilySummary: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let baseCurrency: String
    public let role: String
    public let nickname: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "Name"
        case baseCurrency = "BaseCurrency"
        case role = "Role"
        case nickname = "Nickname"
    }
}

public struct FamilyMember: Codable, Identifiable, Sendable {
    public let id: UUID
    public let familyID: UUID
    public let userID: UUID
    public let role: String
    public let nickname: String?
    public let email: String
    public let fullName: String
    public let avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case familyID = "FamilyID"
        case userID = "UserID"
        case role = "Role"
        case nickname = "Nickname"
        case email = "Email"
        case fullName = "FullName"
        case avatarURL = "AvatarUrl"
    }
}

// MARK: - Contas Financeiras

public enum AccountKind: String, Codable, Sendable {
    case checking
    case savings
    case investment
    case cash
    case creditCard = "credit_card"
    
    public var label: String {
        switch self {
        case .checking: "Conta Corrente"
        case .savings: "Poupança / Reserva"
        case .investment: "Investimentos"
        case .cash: "Dinheiro / Carteira"
        case .creditCard: "Cartão de Crédito"
        }
    }
}

public struct Account: Codable, Identifiable, Sendable {
    public let id: UUID
    public let familyID: UUID
    public let ownerUserID: UUID
    public let name: String
    public let kind: AccountKind
    public let visibility: String
    public let currency: String
    public let initialBalanceCents: Int64
    public let currentBalanceCents: Int64
    public let color: String?
    public let ownerName: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case familyID = "FamilyID"
        case ownerUserID = "OwnerUserID"
        case name = "Name"
        case kind = "Kind"
        case visibility = "Visibility"
        case currency = "Currency"
        case initialBalanceCents = "InitialBalanceCents"
        case currentBalanceCents = "CurrentBalanceCents"
        case color = "Color"
        case ownerName = "OwnerName"
    }
    
    public var currentBalance: Double {
        Double(currentBalanceCents) / 100.0
    }
}

// MARK: - Categorias

public enum CategoryKind: String, Codable, Sendable {
    case income
    case expense
    case both
}

public struct Category: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let familyID: UUID
    public let name: String
    public let slug: String?
    public let icon: String?
    public let color: String?
    public let kind: CategoryKind
    public let parentID: UUID?
    public let systemOnly: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case familyID = "FamilyID"
        case name = "Name"
        case slug = "Slug"
        case icon = "Icon"
        case color = "Color"
        case kind = "Kind"
        case parentID = "ParentID"
        case systemOnly = "SystemOnly"
    }
}

// MARK: - Transações & Fluxo de Caixa

public enum TransactionKind: String, Codable, Sendable {
    case income
    case expense
    case transfer
}

public struct Transaction: Codable, Identifiable, Sendable {
    public let id: UUID
    public let familyID: UUID
    public let accountID: UUID
    public let categoryID: UUID?
    public let kind: TransactionKind
    public let amountCents: Int64
    public let description: String
    public let transactedAt: Date
    public let status: String?
    public let categoryName: String?
    public let categoryIcon: String?
    public let categoryColor: String?
    public let accountName: String?
    public let authorName: String?
    public let targetName: String?
    public let installmentNumber: Int16?
    public let installmentTotal: Int16?
    public let tags: [String]?
    public let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case familyID = "FamilyID"
        case accountID = "AccountID"
        case categoryID = "CategoryID"
        case kind = "Kind"
        case amountCents = "AmountCents"
        case description = "Description"
        case transactedAt = "TransactedAt"
        case status = "Status"
        case categoryName = "CategoryName"
        case categoryIcon = "CategoryIcon"
        case categoryColor = "CategoryColor"
        case accountName = "AccountName"
        case authorName = "AuthorName"
        case targetName = "TargetName"
        case installmentNumber = "InstallmentNumber"
        case installmentTotal = "InstallmentTotal"
        case tags = "Tags"
        case notes = "Notes"
    }
    
    public var amount: Double {
        Double(amountCents) / 100.0
    }
}

public struct CashFlowSummary: Codable, Sendable {
    public let totalIncomeCents: Int64
    public let totalExpenseCents: Int64
    public let netCashFlowCents: Int64
    
    enum CodingKeys: String, CodingKey {
        case totalIncomeCents = "total_income_cents"
        case totalExpenseCents = "total_expense_cents"
        case netCashFlowCents = "net_cash_flow_cents"
    }
}

// MARK: - Cartões de Crédito & Faturas

public struct CreditCardData: Codable, Identifiable, Sendable {
    public let id: UUID
    public let accountID: UUID
    public let familyID: UUID
    public let name: String
    public let lastFourDigits: String?
    public let creditLimitCents: Int64
    public let closingDay: Int16
    public let dueDay: Int16
    public let color: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case accountID = "AccountID"
        case familyID = "FamilyID"
        case name = "Name"
        case lastFourDigits = "LastFourDigits"
        case creditLimitCents = "CreditLimitCents"
        case closingDay = "ClosingDay"
        case dueDay = "DueDay"
        case color = "Color"
    }
}

public struct CreditCardInvoice: Codable, Identifiable, Sendable {
    public let id: UUID
    public let creditCardID: UUID
    public let familyID: UUID
    public let periodYear: Int16
    public let periodMonth: Int16
    public let closingDate: Date
    public let dueDate: Date
    public let totalAmountCents: Int64
    public let paidAmountCents: Int64
    public let status: String
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case creditCardID = "CreditCardID"
        case familyID = "FamilyID"
        case periodYear = "PeriodYear"
        case periodMonth = "PeriodMonth"
        case closingDate = "ClosingDate"
        case dueDate = "DueDate"
        case totalAmountCents = "TotalAmountCents"
        case paidAmountCents = "PaidAmountCents"
        case status = "Status"
    }
    
    public var remainingAmountCents: Int64 {
        max(0, totalAmountCents - paidAmountCents)
    }
}

public struct CreditCardSummary: Codable, Identifiable, Sendable {
    public var id: UUID { card.id }
    public let card: CreditCardData
    public let accountName: String
    public let currentInvoice: CreditCardInvoice?
    public let usedLimitCents: Int64
    public let availableLimitCents: Int64
    
    enum CodingKeys: String, CodingKey {
        case card
        case accountName = "account_name"
        case currentInvoice = "current_invoice"
        case usedLimitCents = "used_limit_cents"
        case availableLimitCents = "available_limit_cents"
    }
}

public struct MemberSpendingShare: Codable, Sendable, Identifiable {
    public var id: String { userName }
    public let userName: String
    public let amountCents: Int64
    
    enum CodingKeys: String, CodingKey {
        case userName = "user_name"
        case amountCents = "amount_cents"
    }
}

public struct MonthlyProjectionItem: Codable, Identifiable, Sendable {
    public var id: String { "\(periodYear)-\(periodMonth)" }
    public let periodYear: Int16
    public let periodMonth: Int16
    public let monthLabel: String
    public let dueDate: Date
    public let totalAmountCents: Int64
    public let installmentsCount: Int
    public let memberShares: [MemberSpendingShare]?
    public let transactions: [Transaction]?
    
    enum CodingKeys: String, CodingKey {
        case periodYear = "period_year"
        case periodMonth = "period_month"
        case monthLabel = "month_label"
        case dueDate = "due_date"
        case totalAmountCents = "total_amount_cents"
        case installmentsCount = "installments_count"
        case memberShares = "member_shares"
        case transactions
    }
}

public struct AnticipatedItemDetail: Codable, Identifiable, Sendable {
    public var id: UUID { transactionID }
    public let transactionID: UUID
    public let description: String
    public let originalAmount: Int64
    public let discountCents: Int64
    public let netCalculated: Int64
    public let installmentInfo: String
    public let monthsAhead: Int
    
    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case description
        case originalAmount = "original_amount_cents"
        case discountCents = "discount_cents"
        case netCalculated = "net_amount_cents"
        case installmentInfo = "installment_info"
        case monthsAhead = "months_ahead"
    }
}

public struct SimulateAnticipationResponse: Codable, Sendable {
    public let originalTotalCents: Int64
    public let totalDiscountCents: Int64
    public let anticipatedTotalCents: Int64
    public let items: [AnticipatedItemDetail]
    
    enum CodingKeys: String, CodingKey {
        case originalTotalCents = "original_total_cents"
        case totalDiscountCents = "total_discount_cents"
        case anticipatedTotalCents = "anticipated_total_cents"
        case items
    }
}

// MARK: - Orçamentos por Envelope

public struct BudgetItemDetail: Codable, Identifiable, Sendable {
    public let id: UUID
    public let budgetID: UUID
    public let categoryID: UUID
    public let categoryName: String
    public let categoryIcon: String?
    public let categoryColor: String?
    public let categoryKind: String
    public let allocatedAmountCents: Int64
    public let spentAmountCents: Int64
    public let spentPercentage: Double
    public let remainingCents: Int64
    public let status: String // "normal", "warning", "exceeded"
    public let rolloverEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case budgetID = "budget_id"
        case categoryID = "category_id"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categoryColor = "category_color"
        case categoryKind = "category_kind"
        case allocatedAmountCents = "allocated_amount_cents"
        case spentAmountCents = "spent_amount_cents"
        case spentPercentage = "spent_percentage"
        case remainingCents = "remaining_cents"
        case status
        case rolloverEnabled = "rollover_enabled"
    }
}

public struct BudgetSummaryData: Codable, Sendable {
    public let totalIncomeCents: Int64
    public let totalBudgetedCents: Int64
    public let totalSpentCents: Int64
    public let freeToInvestCents: Int64
    
    enum CodingKeys: String, CodingKey {
        case totalIncomeCents = "total_income_cents"
        case totalBudgetedCents = "total_budgeted_cents"
        case totalSpentCents = "total_spent_cents"
        case freeToInvestCents = "free_to_invest_cents"
    }
}

public struct BudgetData: Codable, Identifiable, Sendable {
    public let id: UUID
    public let familyID: UUID
    public let periodYear: Int16
    public let periodMonth: Int16
    public let totalAllocatedCents: Int64
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case familyID = "FamilyID"
        case periodYear = "PeriodYear"
        case periodMonth = "PeriodMonth"
        case totalAllocatedCents = "TotalAllocatedCents"
    }
}

public struct BudgetResponse: Codable, Sendable {
    public let budget: BudgetData
    public let items: [BudgetItemDetail]
    public let summary: BudgetSummaryData
}

// MARK: - Copilot de IA & Agente Financeiro

public enum AIMessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

public struct AIToolCallInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let arguments: String?
}

public struct AIToolResultInfo: Codable, Sendable, Identifiable {
    public var id: String { toolCallID }
    public let toolCallID: String
    public let toolName: String
    public let result: String?
    public let error: String?
    
    enum CodingKeys: String, CodingKey {
        case toolCallID = "tool_call_id"
        case toolName = "tool_name"
        case result
        case error
    }
}

public struct AIChatMessage: Codable, Identifiable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let role: AIMessageRole
    public var content: String
    public var toolCalls: [AIToolCallInfo]?
    public var toolCallID: String?
    public let createdAt: Date
    public var isStreaming: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case conversationID = "ConversationID"
        case role = "Role"
        case content = "Content"
        case toolCalls = "ToolCalls"
        case toolCallID = "ToolCallID"
        case createdAt = "CreatedAt"
    }
    
    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: AIMessageRole,
        content: String,
        toolCalls: [AIToolCallInfo]? = nil,
        toolCallID: String? = nil,
        createdAt: Date = Date(),
        isStreaming: Bool = false
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
}

public struct AIConversationSummary: Codable, Identifiable, Sendable {
    public let id: UUID
    public let familyID: UUID
    public let userID: UUID
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case familyID = "FamilyID"
        case userID = "UserID"
        case title = "Title"
        case createdAt = "CreatedAt"
        case updatedAt = "UpdatedAt"
    }
}

public struct AIChatStreamDelta: Codable, Sendable {
    public let type: String
    public let conversationID: UUID?
    public let messageID: UUID?
    public let delta: String?
    public let fullText: String?
    public let toolCall: AIToolCallInfo?
    public let toolResult: AIToolResultInfo?
    public let error: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case conversationID = "conversation_id"
        case messageID = "message_id"
        case delta
        case fullText = "full_text"
        case toolCall = "tool_call"
        case toolResult = "tool_result"
        case error
    }
}

