import SwiftUI
import SwiftData

/// Aviso de pago (pantalla 3, versión personal). Cada pago fijo elige: Como el general (Ajustes › Avisos),
/// Personalizado (días antes, hora y el mismo día) o Sin aviso.
/// "¿A quién aviso?" y avisar a la pareja llegan con los espacios compartidos (F11).
struct ReminderEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @AppStorage(AlertSettings.enabledKey) private var generalEnabled = true
    @AppStorage(AlertSettings.daysBeforeKey) private var generalDays = 3
    @AppStorage(AlertSettings.atMinutesKey) private var generalMinutes = 540

    let recurring: Recurring
    var currency: Currency = .cop

    @State private var mode: ReminderMode = .general
    @State private var daysBefore = Double(AlertSettings.daysBefore)
    @State private var time = Date.now
    @State private var sameDay = true
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
                    SegmentedPill(options: [(value: ReminderMode.general, title: "General"),
                                            (value: ReminderMode.personalizado, title: "Propio"),
                                            (value: ReminderMode.ninguno, title: "Sin aviso")],
                                  selection: $mode)
                    switch mode {
                    case .general: generalInfo
                    case .personalizado: customControls
                    case .ninguno:
                        Text("No te avisamos de \(recurring.name). Igual sale en Próximos cargos y en el calendario.")
                            .appFont(.cuerpo2)
                            .foregroundStyle(Palette.texto2)
                    }
                    if mode != .ninguno, let days = previewDays {
                        preview(days: days)
                    }
                    if denied {
                        Text("Las notificaciones están apagadas para MProgress. Actívalas en Ajustes del iPhone › Notificaciones › MProgress para recibir este aviso.")
                            .appFont(.cuerpo2)
                            .foregroundStyle(Palette.peligro)
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

    private var generalInfo: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("Como el general").appFont(.titulo3).foregroundStyle(Palette.texto1)
                Text(generalEnabled
                     ? "Te avisamos con lo que pusiste en Ajustes › Avisos: \(AlertSettings.summary(enabled: true, daysBefore: generalDays, atMinutes: generalMinutes).lowercased())."
                     : "El aviso general está apagado. Actívalo en Ajustes › Avisos o elige un aviso propio.")
                    .appFont(.cuerpo2)
                    .foregroundStyle(Palette.texto2)
            }
        }
    }

    @ViewBuilder
    private var customControls: some View {
        SectionLabel(text: "¿Cuándo?")
        Card {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack {
                    Text("Días antes").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    Spacer()
                    Text(Int(daysBefore) == 0 ? "El mismo día" : "\(Int(daysBefore))").appFont(.cifra).foregroundStyle(Palette.texto1)
                }
                Slider(value: $daysBefore, in: 0...14, step: 1)
                    .tint(Palette.brasa)
                    .accessibilityValue(Int(daysBefore) == 0 ? "El mismo día" : "\(Int(daysBefore)) días antes")
                HStack {
                    Text("El mismo día").appFont(.leyenda)
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
                if Int(daysBefore) > 0 {
                    Divider().overlay(Palette.linea)
                    Toggle(isOn: $sameDay) {
                        Text("Recordar el mismo día").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    }
                    .tint(Palette.brasa)
                    .padding(.horizontal, Spacing.s2)
                    .frame(minHeight: 56)
                }
            }
        }
    }

    /// Días antes que se ven en la vista previa; nil si no habrá aviso.
    private var previewDays: Int? {
        switch mode {
        case .general: return generalEnabled ? generalDays : nil
        case .personalizado: return Int(daysBefore)
        case .ninguno: return nil
        }
    }

    private func preview(days: Int) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            IconTile(content: .symbol("bell.fill"), tint: Palette.brasa, foreground: Palette.sobreBrasa, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vista previa").appFont(.etiqueta).foregroundStyle(Palette.texto1)
                Text(ReminderPlanner.body(name: recurring.name, kind: recurring.kind,
                                          amount: Money(minor: recurring.amountMinor, currency: currency).formatted(), days: days))
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
        let existing = try? PlanningStore(context: context).reminder(for: recurring.id)
        mode = existing?.mode ?? .general
        let atMinutes = existing?.atMinutes ?? AlertSettings.atMinutes
        daysBefore = Double(existing?.daysBefore ?? AlertSettings.daysBefore)
        sameDay = existing?.sameDay ?? true
        time = calendar.date(bySettingHour: atMinutes / 60, minute: atMinutes % 60, second: 0, of: .now) ?? .now
    }

    private func save() {
        let store = PlanningStore(context: context)
        _ = try? store.setReminder(spaceId: recurring.spaceId, recurringId: recurring.id, daysBefore: Int(daysBefore),
                                   atMinutes: minutes, sameDay: sameDay && Int(daysBefore) > 0, mode: mode)
        Task {
            // Guardar un aviso es un momento con contexto para pedir el permiso.
            let allowed = mode == .ninguno ? true : await NotificationScheduler.requestIfNeeded()
            if mode != .ninguno { UserDefaults.standard.set(true, forKey: AlertSettings.askedKey) }
            await NotificationScheduler.reschedule(context: context)
            if allowed { dismiss() } else { denied = true }
        }
    }
}
