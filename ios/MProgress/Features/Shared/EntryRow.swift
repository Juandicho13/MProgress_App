import SwiftUI

/// Monto con signo para listas: "+ $ 2.200.000" o "− $ 84.300".
func signedAmount(_ minor: Int64, _ kind: EntryKind, _ currency: Currency) -> String {
    Money(minor: kind == .ingreso ? minor : -minor, currency: currency).formatted(sign: true)
}

/// Baldosa de un movimiento o pago fijo: su símbolo o sus iniciales, azul hielo si es ingreso.
func entryTile(icon: String?, name: String, kind: EntryKind, size: CGFloat = Size.baldosa) -> IconTile {
    IconTile(content: icon.map { IconTile.Content.symbol($0) } ?? .initials(name.isEmpty ? "?" : name),
             tint: kind == .ingreso ? Palette.hieloVelo : Palette.superficie3,
             foreground: kind == .ingreso ? Palette.hielo : Palette.texto1,
             size: size)
}

/// Fila de un movimiento en Inicio, Historial y Calendario.
struct EntryRow: View {
    let entry: Entry
    let subtitle: String
    let currency: Currency
    /// Tiene cambios que todavía no suben a la nube (F10-04): reloj pequeño y "Pendiente" bajo el monto.
    var pending: Bool = false

    var body: some View {
        ListRow(tile: entryTile(icon: entry.icon, name: entry.name, kind: entry.kind), title: entry.name, subtitle: subtitle) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmount(entry.amountMinor, entry.kind, currency))
                    .appFont(.cifra)
                    .foregroundStyle(entry.kind == .ingreso ? Palette.hielo : Palette.texto1)
                if pending {
                    Label("Pendiente", systemImage: "clock")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para ver el detalle")
    }
}
