import SwiftUI

/// Fecha fácil (PLAN_F12B): Hoy, Ayer, Mañana u Otra fecha (abre un calendario). La hora es opcional,
/// escondida tras "Agregar hora"; si no se toca, se queda la que tenía la fecha.
struct EasyDatePicker: View {
    let title: String
    @Binding var date: Date
    var allowsTime = true

    @Environment(\.calendar) private var calendar
    @State private var showsCalendar = false
    @State private var showsTime = false

    var body: some View {
        let current = DayShortcut.matching(date, now: .now, calendar: calendar)
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(title).appFont(.titulo3).foregroundStyle(Palette.texto1)
            FlowLayout(spacing: Spacing.s2) {
                ForEach(DayShortcut.allCases) { shortcut in
                    Chip(title: shortcut.title, selected: current == shortcut) {
                        date = shortcut.apply(to: date, now: .now, calendar: calendar)
                    }
                }
                Chip(title: current == nil ? DueText.shortDate(date, calendar: calendar) : "Otra fecha",
                     systemImage: "calendar", selected: current == nil) {
                    showsCalendar = true
                }
                .accessibilityHint("Abre un calendario")
            }
            if allowsTime {
                if showsTime {
                    DatePicker(selection: $date, displayedComponents: .hourAndMinute) {
                        Text("Hora").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    }
                    .tint(Palette.brasa)
                    .frame(minHeight: Size.toqueMinimo)
                } else {
                    Button {
                        showsTime = true
                    } label: {
                        Label("Agregar hora", systemImage: "clock")
                            .appFont(.etiqueta)
                            .foregroundStyle(Palette.brasaTinta)
                            .frame(minHeight: Size.toqueMinimo)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showsCalendar) {
            OtherDateSheet(date: $date)
        }
    }
}

/// Calendario de "Otra fecha".
private struct OtherDateSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Palette.brasa)
                    .padding(.horizontal, Spacing.margen)
            }
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Otra fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// "Día del mes" de un pago fijo mensual: cuadrícula de 1 a 31.
struct DayOfMonthGrid: View {
    @Binding var day: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s1), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            LazyVGrid(columns: columns, spacing: Spacing.s1) {
                ForEach(1...31, id: \.self) { number in
                    let selected = number == day
                    Button {
                        day = number
                    } label: {
                        Text("\(number)")
                            .appFont(.cuerpo2)
                            .fontWeight(selected ? .semibold : .regular)
                            .foregroundStyle(selected ? Palette.sobreBrasa : Palette.texto1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Circle().fill(selected ? Palette.brasa : Color.clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Día \(number)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            if day > 28 {
                Text("En los meses que no tienen el \(day), se cobra el último día.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
        }
    }
}

/// "Termina": Nunca, En una fecha o Después de N cuotas (PLAN_F12B "Pagos con fin").
struct EndRuleEditor: View {
    @Binding var choice: RecurringEndChoice
    @Binding var endDate: Date
    @Binding var count: Int
    /// Cuotas ya pagadas: no se puede pedir menos cuotas que estas.
    var paidCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Termina").appFont(.titulo3).foregroundStyle(Palette.texto1)
            SegmentedPill(options: RecurringEndChoice.allCases.map { (value: $0, title: $0.shortTitle) }, selection: $choice)
            switch choice {
            case .nunca:
                Text("Se repite hasta que lo pauses o lo borres.").appFont(.leyenda).foregroundStyle(Palette.texto2)
            case .fecha:
                DatePicker(selection: $endDate, displayedComponents: .date) {
                    Text("Último cobro").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                }
                .tint(Palette.brasa)
                .frame(minHeight: Size.toqueMinimo)
                Text("No hay cobros después de esa fecha.").appFont(.leyenda).foregroundStyle(Palette.texto2)
            case .cuotas:
                Stepper(value: $count, in: max(1, paidCount)...360) {
                    Text("\(count) \(count == 1 ? "cuota" : "cuotas")").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                }
                .frame(minHeight: Size.toqueMinimo)
                if paidCount > 0 {
                    Text("Ya \(paidCount == 1 ? "va 1 pagada" : "van \(paidCount) pagadas").").appFont(.leyenda).foregroundStyle(Palette.texto2)
                }
            }
        }
    }
}
