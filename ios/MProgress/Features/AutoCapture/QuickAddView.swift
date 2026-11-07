import SwiftUI
import SwiftData
import Observation

/// Abre el registro rápido cuando lo pide el atajo (doble toque atrás) o un widget.
@MainActor
@Observable
final class QuickAddRouter {
    static let shared = QuickAddRouter()
    var pending = false
    /// Pedido desde un widget: abrir Pagos fijos en Inicio.
    var openFixed = false
}

/// Registro rápido en una sola pantalla: Gasto o Ingreso, el monto con el teclado de la app, "¿En qué?" opcional
/// con los nombres que más usas y Guardar. Sin nombre queda "Gasto rápido" o "Ingreso rápido", como siempre.
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo: UndoCenter?
    @Query(filter: #Predicate<Space> { $0.deletedAt == nil }, sort: \Space.createdAt) private var spaces: [Space]
    @Query(filter: #Predicate<Entry> { $0.deletedAt == nil }, sort: \Entry.occurredAt, order: .reverse) private var allEntries: [Entry]

    @State private var kind: EntryKind = .gasto
    @State private var amount = AmountInput()
    @State private var name = ""
    @State private var errorText: String?
    @FocusState private var nameFocused: Bool

    private var space: Space? { spaces.first { $0.kindRaw == "personal" } ?? spaces.first }
    private var currency: Currency { space?.currency ?? .cop }
    /// Los 6 nombres que más usas en tus movimientos recientes de este tipo.
    private var suggestions: [QuickName] {
        let records = allEntries.filter { $0.spaceId == space?.id }.prefix(QuickNames.window * 2).map(\.record)
        return QuickNames.recent(Array(records), kind: kind)
    }
    private var visibleSuggestions: [QuickName] { QuickNames.matching(suggestions, typed: name) }

    var body: some View {
        VStack(spacing: Spacing.s3) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Cerrar") { dismiss() }
                Spacer()
                Text("Registro rápido").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Spacer()
                Color.clear.frame(width: Size.toqueMinimo, height: Size.toqueMinimo)
            }
            .padding(.top, Spacing.s4)

            SegmentedPill(options: [(value: EntryKind.gasto, title: "Gasto"), (value: EntryKind.ingreso, title: "Ingreso")], selection: $kind)
            // El mismo campo de monto de Agregar; el teclado de la app escribe aquí salvo mientras escribes el nombre.
            EditableAmountField(input: amount, editing: !nameFocused, showsCaption: false) { nameFocused = false }
            nameField
            if !visibleSuggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.s2) {
                        ForEach(visibleSuggestions, id: \.name) { item in
                            Chip(title: item.name, selected: false) {
                                name = item.name
                                nameFocused = false
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            Spacer(minLength: 0)
            Button("Guardar") { save() }
                .buttonStyle(.primary)
                .disabled(amount.money.isZero)
            if !nameFocused {
                NumericKeypad(input: $amount)
            }
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s2)
        .background(Palette.superficie2.ignoresSafeArea())
        .onAppear { amount = AmountInput(currency: currency) }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private var nameField: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: "text.cursor").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.texto2)
                .accessibilityHidden(true)
            TextField("¿En qué? Almuerzo, taxi, mercado", text: $name)
                .appFont(.cuerpo)
                .foregroundStyle(Palette.texto1)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit { nameFocused = false }
                .accessibilityLabel("¿En qué?")
            if !name.isEmpty {
                Button { name = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundStyle(Palette.texto2)
                        .frame(width: Size.toqueMinimo, height: Size.toqueMinimo)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrar el nombre")
            }
        }
        .padding(.leading, Spacing.s4)
        .frame(minHeight: Size.toqueMinimo)
        .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
    }

    private func save() {
        guard let space, !amount.money.isZero else { return }
        let finalName = QuickAddMath.name(kind: kind, concept: name)
        let categoryId = kind == .gasto ? QuickNames.categoryId(for: name, in: suggestions) : nil
        do {
            let entry = try LedgerStore(context: context, calendar: calendar).addEntry(
                spaceId: space.id, kind: kind, amountMinor: amount.money.minor, name: finalName, categoryId: categoryId,
                createdBy: LocalIdentity.userId)
            dismiss()
            undo?.show("Anotado: \(finalName) · \(signedAmount(entry.amountMinor, kind, currency))") {
                try? LedgerStore(context: context).softDelete(entry)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Guía del doble toque atrás: Atajos + Accesibilidad.
struct BackTapGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AutoSetup.dobleToque.storageKey) private var configuredAt: Double = 0
    @AppStorage(QuickAddSettings.opensAppKey) private var opensApp = false

    private var steps: [(String, String)] {
        [
            ("Crea el atajo", "Abre Atajos, toca +, busca la acción \"Registro rápido\" de MProgress y guárdalo con ese nombre."),
            ("Abre Tocar atrás", "En Ajustes del iPhone: Accesibilidad › Tocar › Tocar atrás."),
            ("Elige Doble toque", "Baja hasta Atajos y elige \"Registro rápido\"."),
            ("Pruébalo", opensApp
                ? "Toca dos veces la parte de atrás del iPhone: se abre MProgress listo para escribir el monto."
                : "Toca dos veces la parte de atrás del iPhone: te pide el monto, si es gasto o ingreso y de dónde, sin abrir la app. Lo ves en la isla dinámica con Deshacer."),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text("Anota un gasto o un ingreso tocando dos veces la parte de atrás de tu iPhone. Escribes el monto, eliges si entra o sale y de dónde, y listo.")
                        .appFont(.cuerpo)
                        .foregroundStyle(Palette.texto2)
                    Card(padding: Spacing.s2) {
                        Toggle(isOn: $opensApp) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Abrir la app al anotar").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                                Text(opensApp ? "Se abre MProgress, como antes." : "Anota sin abrir la app y te muestra el resultado en la isla dinámica.")
                                    .appFont(.leyenda)
                                    .foregroundStyle(Palette.texto2)
                            }
                        }
                        .tint(Palette.brasa)
                        .padding(.horizontal, Spacing.s2)
                        .frame(minHeight: 56)
                    }
                    Text("Con Siri: \"Oye Siri, anota en MProgress\" o \"Anota un gasto en MProgress\". Siri te pregunta el monto.")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                    ForEach(Array(steps.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: Spacing.s3) {
                            Text("\(item.offset + 1)")
                                .appFont(.titulo3)
                                .foregroundStyle(Palette.sobreBrasa)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Palette.brasa))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.element.0).appFont(.titulo3).foregroundStyle(Palette.texto1)
                                Text(item.element.1).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if let url = URL(string: "shortcuts://") {
                        Link("Abrir Atajos", destination: url).buttonStyle(.primary)
                    }
                    Button("Probar ahora") {
                        dismiss()
                        QuickAddRouter.shared.pending = true
                    }
                    .buttonStyle(.secondary)
                    if configuredAt > 0 {
                        Label("Configurado: ya funciona en este iPhone", systemImage: "checkmark.circle.fill")
                            .appFont(.etiqueta)
                            .foregroundStyle(Palette.exito)
                            .frame(maxWidth: .infinity, minHeight: Size.toqueMinimo)
                        Button("Lo quité, marcar sin configurar") { configuredAt = 0 }
                            .appFont(.etiqueta)
                            .foregroundStyle(Palette.texto2)
                            .frame(maxWidth: .infinity)
                    } else {
                        Button("Ya lo configuré") { AutoSetup.dobleToque.mark(); dismiss() }
                            .buttonStyle(.secondary)
                    }
                    Text("Apple no deja que una app active el doble toque por sí sola; con estos pasos queda listo en un minuto.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Doble toque atrás")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }
}
