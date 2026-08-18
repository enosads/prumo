import Foundation
import SwiftUI

@MainActor
@Observable
public final class AuthSession {
    public static let shared = AuthSession()
    
    public var currentUser: AuthUser?
    public var accessToken: String?
    public var refreshToken: String?
    public var isAuthenticated: Bool { accessToken != nil && currentUser != nil }
    public var isLoading = false
    public var activeFamilyID: UUID?
    
    private let tokenKey = "prumo_access_token"
    private let refreshKey = "prumo_refresh_token"
    
    public init() {
        self.accessToken = UserDefaults.standard.string(forKey: tokenKey)
        self.refreshToken = UserDefaults.standard.string(forKey: refreshKey)
    }
    
    public func setSession(authResponse: AuthResponse) {
        self.currentUser = authResponse.user
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        self.activeFamilyID = authResponse.user.familyID
        
        UserDefaults.standard.setValue(authResponse.accessToken, forKey: tokenKey)
        UserDefaults.standard.setValue(authResponse.refreshToken, forKey: refreshKey)
    }
    
    public func logout() {
        self.currentUser = nil
        self.accessToken = nil
        self.refreshToken = nil
        self.activeFamilyID = nil
        
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
    }
    
    public func fetchMe() async {
        guard let token = accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let me: MeResponse = try await APIClient.shared.request("/v1/auth/me", token: token)
            self.currentUser = me.user
            self.activeFamilyID = me.user.familyID
        } catch {
            if case .unauthorized = error as? APIError {
                logout()
            }
        }
    }
}
