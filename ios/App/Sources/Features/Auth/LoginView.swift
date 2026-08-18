import SwiftUI

public struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    
    private struct LoginPayload: Encodable {
        let email: String
        let password: String
    }
    
    private struct RegisterPayload: Encodable {
        let email: String
        let fullName: String
        let password: String
        
        enum CodingKeys: String, CodingKey {
            case email
            case fullName = "full_name"
            case password
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Cabeçalho da Marca
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Brand.primary)
                    
                    Text("Prumo")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(Brand.primary)
                    
                    Text("Gestão Financeira Familiar com IA")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 16)
                
                // Formulário
                VStack(spacing: 16) {
                    if isRegistering {
                        TextField("Seu nome completo", text: $fullName)
                            .textContentType(.name)
                            .padding()
                            .background(Brand.surface)
                            .cornerRadius(12)
                    }
                    
                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .padding()
                        .background(Brand.surface)
                        .cornerRadius(12)
                    
                    SecureField("Senha", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .padding()
                        .background(Brand.surface)
                        .cornerRadius(12)
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundColor(Brand.expense)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        Task { await handleAuth() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegistering ? "Criar Conta Familiar" : "Entrar")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Brand.primary)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 24)
                
                // Alternador de Modo
                Button {
                    withAnimation {
                        isRegistering.toggle()
                        errorMessage = nil
                    }
                } label: {
                    Text(isRegistering ? "Já possui uma conta? Entrar" : "Novo no Prumo? Cadastre sua família")
                        .font(.footnote)
                        .foregroundColor(Brand.primary)
                }
                
                Spacer()
            }
            .background(Brand.background.ignoresSafeArea())
        }
    }
    
    private func handleAuth() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        
        do {
            let res: AuthResponse
            if isRegistering {
                let payload = RegisterPayload(email: email.trimmingCharacters(in: .whitespaces), fullName: fullName, password: password)
                res = try await APIClient.shared.request("/v1/auth/register", method: "POST", body: payload)
            } else {
                let payload = LoginPayload(email: email.trimmingCharacters(in: .whitespaces), password: password)
                res = try await APIClient.shared.request("/v1/auth/login", method: "POST", body: payload)
            }
            AuthSession.shared.setSession(authResponse: res)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
