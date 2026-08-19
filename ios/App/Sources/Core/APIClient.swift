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
        dec.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let fFrac = ISO8601DateFormatter()
            fFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fFrac.date(from: dateStr) {
                return date
            }
            
            let fStd = ISO8601DateFormatter()
            fStd.formatOptions = [.withInternetDateTime]
            if let date = fStd.date(from: dateStr) {
                return date
            }
            
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            if let date = df.date(from: dateStr) {
                return date
            }
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = df.date(from: dateStr) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data inválida: \(dateStr)")
        }
        self.decoder = dec
        
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
    }
    
    public func send(
        _ path: String,
        method: String = "POST",
        body: (any Encodable)? = nil,
        token: String? = nil
    ) async throws {
        _ = try await rawDataRequest(path, method: method, body: body, token: token)
    }
    
    public func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        token: String? = nil
    ) async throws -> T {
        let data = try await rawDataRequest(path, method: method, body: body, token: token)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let jsonStr = String(data: data, encoding: .utf8) ?? ""
            print("❌ Erro de decodificação em '\(path)': \(error). JSON: \(jsonStr)")
            throw APIError.decoding(error)
        }
    }
    
    private func buildURL(for path: String) -> URL {
        let baseString = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fullString = path.hasPrefix("/") ? "\(baseString)\(path)" : "\(baseString)/\(path)"
        return URL(string: fullString) ?? baseURL.appendingPathComponent(path)
    }
    
    private func rawDataRequest(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        token: String? = nil
    ) async throws -> Data {
        let url = buildURL(for: path)
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
        
        return data
    }
    
    public func streamAIChat(
        conversationID: UUID? = nil,
        message: String,
        token: String
    ) -> AsyncThrowingStream<AIChatStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = buildURL(for: "/v1/ai/chat/stream")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    
                    var bodyDict: [String: Any] = ["message": message]
                    if let convID = conversationID {
                        bodyDict["conversation_id"] = convID.uuidString
                    }
                    req.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
                    
                    let (asyncBytes, response) = try await session.bytes(for: req)
                    
                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.network(URLError(.badServerResponse))
                    }
                    
                    if http.statusCode == 401 {
                        throw APIError.unauthorized(message: "Sessão expirada ou credenciais inválidas.")
                    }
                    
                    if http.statusCode >= 400 {
                        throw APIError.server(code: "\(http.statusCode)", message: "Erro HTTP \(http.statusCode)")
                    }
                    
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled { break }
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("data: ") {
                            let dataStr = String(trimmed.dropFirst(6))
                            if dataStr == "[DONE]" { break }
                            if let data = dataStr.data(using: .utf8) {
                                if let delta = try? self.decoder.decode(AIChatStreamDelta.self, from: data) {
                                    continuation.yield(delta)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

