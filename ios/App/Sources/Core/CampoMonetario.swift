import SwiftUI

public struct CampoMonetario: View {
    @Binding public var amountCents: Int64
    public var currencySymbol: String = "R$"
    public var fontSize: CGFloat = 36
    
    public init(amountCents: Binding<Int64>, currencySymbol: String = "R$", fontSize: CGFloat = 36) {
        self._amountCents = amountCents
        self.currencySymbol = currencySymbol
        self.fontSize = fontSize
    }
    
    private var formattedValue: String {
        let value = Double(amountCents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencySymbol) 0,00"
    }
    
    public var view: some View {
        VStack(spacing: 8) {
            Text(formattedValue)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(amountCents >= 0 ? Brand.primary : Brand.expense)
                .contentTransition(.numericText())
                .animation(.snappy, value: amountCents)
        }
    }
    
    public var body: some View {
        view
    }
}
