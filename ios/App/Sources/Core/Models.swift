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
        case id
        case name
        case baseCurrency = "base_currency"
        case role
        case nickname
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
        case id
        case familyID = "family_id"
        case userID = "user_id"
        case role
        case nickname
        case email
        case fullName = "full_name"
        case avatarURL = "avatar_url"
    }
}

// MARK: - Contas & Cartões

public enum AccountKind: String, Codable, Sendable {
    case checking
    case savings
    case investment
    case cash
    case creditCard = "credit_card"
    
    public var label: String {
        switch self {
        case .checking: "Conta Corrente"
        case .savings: "Poupança"
        case .investment: "Investimento"
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
        case id
        case familyID = "family_id"
        case ownerUserID = "owner_user_id"
        case name
        case kind
        case visibility
        case currency
        case initialBalanceCents = "initial_balance_cents"
        case currentBalanceCents = "current_balance_cents"
        case color
        case ownerName = "owner_name"
    }
    
    public var currentBalance: Double {
        Double(currentBalanceCents) / 100.0
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
    public let categoryName: String?
    public let categoryIcon: String?
    public let categoryColor: String?
    public let accountName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case familyID = "family_id"
        case accountID = "account_id"
        case categoryID = "category_id"
        case kind
        case amountCents = "amount_cents"
        case description
        case transactedAt = "transacted_at"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categoryColor = "category_color"
        case accountName = "account_name"
    }
    
    public var amount: Double {
        Double(amountCents) / 100.0
    }
}
