import SwiftUI
import SwiftData

/// Aviso de pago (pantalla 3, versión personal): cuántos días antes, a qué hora y el mismo día.
/// "¿A quién aviso?" y avisar a la pareja llegan con los espacios compartidos (F11).
struct ReminderEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    let recurring: Recurring
    var currency: Currency = .cop

    @State private var daysBefore = Double(AlertSettings.daysBefore)
    @State private var time = Date.now
    @State private var sameDay = true
    @State private var exists = false
    @State private var denied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Card {
                        ListRow(tile: entryTile(icon: recurring.icon, name: recurring.name, kind: recurring.kind),
                                title: recurring.name,
                                subtitle: "\(Money(minor: recurring.amountMinor, currency: currency).formatted()) · \(recurring.cycle.title)") {
                            EmptyView()
                        }
                    }
                    SectionLabel(text: "¿Cuándo?")
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            HStack {
                                Text("Días antes").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                                Spacer()
                                Text("\(Int(daysBefore))").appFont(.cifra).foregroundStyle(Palette.texto1)
                            }
                            Slider(value: $daysBefore, in: 1...14, step: 1)
                                .tint(Palette.brasa)
                                .accessibilityValue("\(Int(daysBefore)) días antes")
                            HStack {
                                Text("1 día").appFont(.leyenda)
                                Spacer()
                                Text("14 días").appFont(.leyenda)
                            }
                            .foregroundStyle(Palette.texto2)
                            .accessibilityHidden(true)
                        }
                    }
                    SectionLabel(text: "También")
                    Card(padding: Spacing.s2) {
                        VStack(spacing: 0) {
                            DatePicker(selection: $time, displayedComponents: .hourAndMinute) {
                                Text("Hora del aviso").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                            }
                            .tint(Palette.brasa)
                            .padding(.horizontal, Spacing.s2)
                            .frame(minHeight: 56)
                            Divider().overlay(Palette.linea)
                            Toggle(isOn: $sameDay) {
                                Text("Recordar el mismo día").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                            }
                            .tint(Palette.brasa)
                            .padding(.horizontal, Spacing.s2)
                            .frame(minHeight: 56)
                        }
                    }
                    preview
                    if denied {
                        Text("Las notificaciones están apagadas para MProgress. Actívalas en Ajustes del iPhone para recibir este aviso.")
                            .appFont(.cuerpo2)
                            .foregroundStyle(Palette.peligro)
                    }
                    if exists {
                        Button("Quitar aviso") { remove() }.buttonStyle(.destructive)
                    }
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Aviso de pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() } }
            }
        }
        .onAppear(perform: load)
    }

    private var preview: some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            IconTile(content: .symbol("bell.fill"), tint: Palette.brasa, foreground: Palette.sobreBrasa, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vista previa").appFont(.etiqueta).foregroundStyle(Palette.texto1)
                Text(ReminderPlanner.body(name: recurring.name, kind: recurring.kind,
                                          amount: Money(minor: recurring.amountMinor, currency: currency).formatted(), days: Int(daysBefore)))
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
            }
        }
        .padding(Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(RoundedRectangle(cornerRadius: Radius.boton, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var minutes: Int {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
    }

    private func load() {
        let store = PlanningStore(context: context)
        let existing = try? store.reminder(for: recurring.id)
        exists = existing != nil
        let atMinutes = existing?.atMinutes ?? AlertSettings.atMinutes
        daysBefore = Double(max(1, existing?.daysBefore ?? AlertSettings.daysBefore))
        sameDay = existing?.sameDay ?? true
        time = calendar.date(bySettingHour: atMinutes / 60, minute: atMinutes % 60, second: 0, of: .now) ?? .now
    }

    private func save() {
        let store = PlanningStore(context: context)
        _ = try? store.setReminder(spaceId: recurring.spaceId, recurringId: recurring.id, daysBefore: Int(daysBefore), atMinutes: minutes, sameDay: sameDay)
        Task {
            let allowed = await NotificationScheduler.requestIfNeeded()
            await NotificationScheduler.reschedule(context: context)
            if allowed { dismiss() } else { denied = true }
        }
    }

    private func remove() {
        try? PlanningStore(context: context).removeReminder(for: recurring.id)
        Task {
            await NotificationScheduler.reschedule(context: context)
            dismiss()
        }
    }
}
