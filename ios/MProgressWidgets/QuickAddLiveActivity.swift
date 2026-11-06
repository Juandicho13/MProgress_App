import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Colores de la isla (los mismos de la app, sin depender de su código).
private enum Isla {
    static let texto1 = Color(red: 0.953, green: 0.957, blue: 0.965)
    static let texto2 = Color(red: 0.62, green: 0.64, blue: 0.67)
    static let brasa = Color(red: 0.961, green: 0.373, blue: 0.122)
    static let hielo = Color(red: 0.424, green: 0.769, blue: 0.949)
    static let peligro = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let fondo = Color(red: 0.039, green: 0.043, blue: 0.051)

    static func cifra(_ size: CGFloat) -> Font { .system(size: size, weight: .bold).width(.expanded) }
    static func texto(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
}

/// Registro rápido en la isla dinámica y en la pantalla bloqueada: "− $ 84.300 · te quedan $ 1.901.100" con Deshacer.
struct QuickAddLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickAddAttributes.self) { context in
            QuickAddLockScreenView(state: context.state)
                .activityBackgroundTint(Isla.fondo)
                .activitySystemActionForegroundColor(Isla.texto1)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: state.undone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(state.undone ? Isla.texto2 : Isla.brasa)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(state.undone ? "Deshecho" : state.amountText)
                            .font(Isla.cifra(22))
                            .foregroundStyle(amountColor(state))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(state.undone ? "No quedó anotado" : state.remainingText)
                            .font(Isla.texto(13))
                            .foregroundStyle(state.remainingIsNegative && !state.undone ? Isla.peligro : Isla.texto2)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !state.undone {
                        UndoButton(entryId: state.entryId)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(state.name)
                        .font(Isla.texto(12))
                        .foregroundStyle(Isla.texto2)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: state.undone ? "arrow.uturn.backward" : "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Isla.brasa)
            } compactTrailing: {
                Text(state.undone ? "Deshecho" : state.amountText)
                    .font(Isla.texto(13, .bold))
                    .foregroundStyle(amountColor(state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } minimal: {
                Image(systemName: state.undone ? "arrow.uturn.backward" : "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Isla.brasa)
            }
        }
    }
}

private func amountColor(_ state: QuickAddAttributes.ContentState) -> Color {
    if state.undone { return Isla.texto2 }
    return state.isIncome ? Isla.hielo : Isla.texto1
}

/// Botón Deshacer: corre UndoQuickAddIntent en el proceso de la app.
private struct UndoButton: View {
    let entryId: String

    var body: some View {
        Button(intent: UndoQuickAddIntent(entryId: entryId)) {
            Text("Deshacer")
                .font(Isla.texto(13, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(Capsule().fill(Isla.brasa))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Deshacer el registro")
    }
}

/// Pantalla bloqueada: el monto, lo que queda y Deshacer.
private struct QuickAddLockScreenView: View {
    let state: QuickAddAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.undone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(state.undone ? Isla.texto2 : Isla.brasa)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.undone ? "Deshecho" : "\(state.name) · \(state.amountText)")
                    .font(Isla.texto(16, .bold))
                    .foregroundStyle(amountColor(state))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(state.undone ? "No quedó anotado" : state.remainingText)
                    .font(Isla.texto(13))
                    .foregroundStyle(state.remainingIsNegative && !state.undone ? Isla.peligro : Isla.texto2)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !state.undone {
                UndoButton(entryId: state.entryId)
            }
        }
        .padding(16)
    }
}
