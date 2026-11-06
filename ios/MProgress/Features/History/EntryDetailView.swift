import SwiftUI
import SwiftData

/// Detalle de movimiento (pantalla 23): editar, duplicar y borrar con deshacer.
struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(UndoCenter.self) private var undo
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }) private var categories: [SpendCategory]
    @Query(filter: #Predicate<Recurring> { $0.deletedAt == nil }) private var recurring: [Recurring]

    let entry: Entry
    var currency: Currency = .cop

    @State private var editing = false
    @State private var confirmsDelete = false
    @State private var errorText: String?

    private var category: SpendCategory? { categories.first { $0.id == entry.categoryId } }
    private var origin: Recurring? { recurring.first { $0.id == entry.recurringId } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Cerrar") { dismiss() }
                Spacer()
                Text("Detalle").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Spacer()
                CircleIconButton(systemImage: "pencil", label: "Editar") { editing = true }
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s4)

            ScrollView {
                VStack(spacing: Spacing.s6) {
                    VStack(spacing: Spacing.s3) {
                        entryTile(icon: entry.icon, name: entry.name, kind: entry.kind, size: 72)
                        Text(entry.name).appFont(.titulo2).foregroundStyle(Palette.texto1).multilineTextAlignment(.center)
                        Text(signedAmount(entry.amountMinor, entry.kind, currency))
                            .appFont(.cifraGrande)
                            .foregroundStyle(entry.kind == .ingreso ? Palette.hielo : Palette.texto1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Badge(text: entry.kind == .ingreso ? "Ingreso" : "Gasto", tone: entry.kind == .ingreso ? .hielo : .neutral)
                    }
                    .accessibilityElement(children: .combine)
                    .padding(.top, Spacing.s4)

                    Card(padding: Spacing.s2) {
                        VStack(spacing: 0) {
                            row("Fecha", longDate(entry.occurredAt))
                            Divider().overlay(Palette.linea)
                            row("Categoría", category?.name ?? "Sin categoría")
                            Divider().overlay(Palette.linea)
                            row("Cuenta", "Personal")
                            if let origin {
                                Divider().overlay(Palette.linea)
                                row("Pago fijo", "\(origin.name) · \(origin.cycle.title)")
                            }
                            if let notes = entry.notes, !notes.isEmpty {
                                Divider().overlay(Palette.linea)
                                row("Notas", notes)
                            }
                        }
                    }

                    VStack(spacing: Spacing.s3) {
                        Button("Duplicar hoy") { duplicate() }.buttonStyle(.secondary)
                        Button("Borrar movimiento") { confirmsDelete = true }.buttonStyle(.destructive)
                    }
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.bottom, Spacing.s8)
            }
        }
        .background(Palette.superficie2.ignoresSafeArea())
        .sheet(isPresented: $editing) {
            AddEntryView(editing: entry, currency: currency)
        }
        .confirmationDialog("¿Borrar \(entry.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { delete() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Podrás deshacerlo unos segundos.")
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
            Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
            Spacer()
            Text(value).appFont(.cuerpo2).foregroundStyle(Palette.texto2).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Spacing.s2)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private func longDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.day, .year], from: date)
        return "\(parts.day ?? 1) de \(DueText.monthName(date, calendar: calendar)) de \(parts.year ?? 0)"
    }

    private func duplicate() {
        let ledger = LedgerStore(context: context, calendar: calendar)
        do {
            let copy = try ledger.duplicate(entry, by: LocalIdentity.userId)
            dismiss()
            undo.show("Duplicaste \(entry.name)") {
                try? ledger.softDelete(copy)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete() {
        let ledger = LedgerStore(context: context, calendar: calendar)
        let target = entry
        do {
            try ledger.softDelete(target)
            dismiss()
            undo.show("Borraste \(target.name)") {
                try? ledger.restore(target)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    let container = try! Persistence.makeContainer(inMemory: true)
    let space = try! Seed.runIfNeeded(context: container.mainContext, localUser: UUID())
    let entry = try! LedgerStore(context: container.mainContext).addEntry(spaceId: space.id, kind: .gasto, amountMinor: 8_430_000, name: "Mercado", notes: "Compra de la semana")
    return EntryDetailView(entry: entry)
        .modelContainer(container)
        .environment(UndoCenter())
        .preferredColorScheme(.dark)
}
