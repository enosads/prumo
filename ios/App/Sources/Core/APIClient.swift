import Foundation

public enum APIError: LocalizedError, Sendable {
    case server(code: String, message: String)
    case unauthorized(message: String)
    case notFound(message: String)
    case network(Error)
    case decoding(Error)
    
    public var errorDescription: String? {
        switch self {
        case let .server(_, message): message
        case let .unauthorized(message): message
        case let .notFound(message): message
        case .network: "Não foi possível conectar ao servidor. Verifique sua conexão."
        case .decoding: "Erro ao processar os dados do servidor."
        }
    }
}

public actor APIClient {
    public static let shared = APIClient()
    
    #if DEBUG
    public var baseURL = URL(string: "http://localhost:8085")!
    #else
    public var baseURL = URL(string: "https://prumo-backend.fly.dev")!
    #endif
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        let dec = JSONDecoder()
        let formatterWithFrac = ISO8601DateFormatter()
        formatterWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterWithoutFrac = ISO8601DateFormatter()
        formatterWithoutFrac.formatOptions = [.withInternetDateTime]
        
        dec.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            if let date = formatterWithFrac.date(from: dateStr) ?? formatterWithoutFrac.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data inválida: \(dateStr)")
        }
        self.decoder = dec
        
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
    }
    
    public func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        token: String? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            req.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: req)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        
        if http.statusCode == 401 {
            throw APIError.unauthorized(message: "Sessão expirada ou credenciais inválidas.")
        }
        
        if http.statusCode >= 400 {
            if let errObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errObj["detail"] as? String ?? errObj["message"] as? String {
                throw APIError.server(code: "\(http.statusCode)", message: msg)
            }
            throw APIError.server(code: "\(http.statusCode)", message: "Erro HTTP \(http.statusCode)")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
