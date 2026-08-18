import SwiftUI

public enum Brand {
    // Cores Primárias do Prumo
    public static let primary = Color(red: 0.08, green: 0.45, blue: 0.38)     // Verde Floresta/Esmeralda escuro
    public static let secondary = Color(red: 0.12, green: 0.23, blue: 0.35)   // Azul Petróleo
    public static let accent = Color(red: 0.18, green: 0.80, blue: 0.56)      // Verde Menta vibrante
    
    // Cores Semânticas Financeiras
    public static let income = Color(red: 0.13, green: 0.69, blue: 0.45)      // Verde Receita
    public static let expense = Color(red: 0.88, green: 0.28, blue: 0.28)     // Vermelho Despesa
    public static let investment = Color(red: 0.36, green: 0.42, blue: 0.90)  // Roxo/Azul Investimentos
    public static let warning = Color(red: 0.95, green: 0.65, blue: 0.15)     // Âmbar Alerta
    
    // Superfícies e Cards
    public static let background = Color(uiColor: .systemGroupedBackground)
    public static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Tipografia Customizada / Estilos
    public static func currencyFont(size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
