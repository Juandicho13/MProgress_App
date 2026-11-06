import SwiftUI

/// Colores de bancos y billeteras. Solo un color de fondo y las iniciales: nada de logos.
enum InstitutionStyle {
    static let suggestions: [(name: String, hex: String)] = [
        ("Bancolombia", "FDDA24"), ("Nu", "A68CFF"), ("Nequi", "F7B6E8"), ("Davivienda", "ED4C5C"),
        ("Daviplata", "FF7A85"), ("BBVA", "4A90D9"), ("Banco de Bogotá", "5B8DEF"), ("Lulo", "D7FF3C"),
        ("Efectivo", "3A3F47"),
    ]

    static let palette = ["FDDA24", "A68CFF", "F7B6E8", "FF7A85", "4A90D9", "6CC4F2", "4ADE80", "FF6B2C", "3A3F47"]

    static func color(_ hex: String?) -> Color {
        guard let hex, let value = UInt32(hex, radix: 16) else { return Palette.superficie3 }
        return Color(hex: value)
    }

    /// Texto oscuro sobre colores claros y claro sobre oscuros.
    static func foreground(_ hex: String?) -> Color {
        guard let hex, let value = UInt32(hex, radix: 16) else { return Palette.texto1 }
        let r = Double((value >> 16) & 0xFF) / 255, g = Double((value >> 8) & 0xFF) / 255, b = Double(value & 0xFF) / 255
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.5 ? Color(hex: 0x14161A) : Color(hex: 0xF3F4F6)
    }

    static func tile(name: String, hex: String?, size: CGFloat = Size.baldosa) -> IconTile {
        IconTile(content: .initials(name), tint: color(hex), foreground: foreground(hex), size: size)
    }

    /// Ícono de cada tipo de producto.
    static func symbol(_ kind: ProductKind) -> String {
        switch kind {
        case .cuenta: "building.columns"
        case .debito, .credito: "creditcard"
        case .bolsillo: "archivebox"
        case .efectivo: "banknote"
        }
    }
}

/// Monto que se esconde con el ojo de Mi dinero.
struct HideableAmount: View {
    let text: String
    let hidden: Bool

    var body: some View {
        Text(hidden ? "••••••" : text)
            .accessibilityLabel(hidden ? "Saldo oculto" : text)
    }
}

/// Campo de monto con teclado numérico y puntos de miles. Guarda el monto en unidades menores.
struct MoneyField: View {
    let title: String
    @Binding var minor: Int64
    var currency: Currency = .cop
    var placeholder = "0"

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            Text(title).appFont(.leyenda).foregroundStyle(Palette.texto2)
            HStack(spacing: Spacing.s1) {
                Text(currency.symbol).appFont(.cifraPequena).foregroundStyle(Palette.texto2)
                TextField(placeholder, text: $text)
                    .keyboardType(.numberPad)
                    .appFont(.cifraPequena)
                    .foregroundStyle(Palette.texto1)
                    .onChange(of: text) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(12))
                        let units = Int64(digits) ?? 0
                        minor = units * currency.minorPerUnit
                        let formatted = digits.isEmpty ? "" : Money.groupThousands(units)
                        if formatted != newValue { text = formatted }
                    }
            }
            .padding(.horizontal, Spacing.s4)
            .frame(minHeight: Size.toqueMinimo)
            .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
        }
        .onAppear {
            let units = minor / currency.minorPerUnit
            text = units == 0 ? "" : Money.groupThousands(units)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Fila de un producto dentro de un banco o en ¿Con qué pagaste?
struct ProductRow: View {
    let product: Product
    let subtitle: String
    let balance: Int64?
    var currency: Currency = .cop
    var hideBalance = false
    var extra: String?
    var extraColor: Color = Palette.exito

    var body: some View {
        ListRow(tile: IconTile(content: .symbol(InstitutionStyle.symbol(product.kind))), title: title, subtitle: subtitle) {
            if let balance {
                VStack(alignment: .trailing, spacing: 2) {
                    HideableAmount(text: amountText(balance), hidden: hideBalance || product.hidden)
                        .appFont(.cifraPequena)
                        .foregroundStyle(product.kind == .credito && balance > 0 ? Palette.brasaTinta : Palette.texto1)
                    if let extra, !(hideBalance || product.hidden) {
                        Text(extra).appFont(.leyenda).foregroundStyle(extraColor)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var title: String {
        if let last4 = product.last4 { return "\(product.name) ·· \(last4)" }
        return product.name
    }

    private func amountText(_ balance: Int64) -> String {
        let shown = product.kind == .credito ? -balance : balance
        return Money(minor: shown, currency: currency).formatted()
    }
}
