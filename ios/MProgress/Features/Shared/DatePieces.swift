import SwiftUI

/// Fecha (PLAN_F12B y pedido de Juan): una fila con los 7 días de la semana (de lunes a domingo) con hoy marcado en brasa.
/// Se toca un día para elegirlo, se desliza o se usan las flechas para ir a otras semanas (hasta dos años atrás o adelante).
/// El título "noviembre 2026" abre el mes completo, que también se mueve por meses y se cierra al elegir.
/// "Hoy" sale solo si la fecha elegida no es hoy. La hora es opcional, escondida tras "Agregar hora"; si no se toca,
/// se queda la que tenía la fecha.
struct EasyDatePicker: View {
    let title: String
    @Binding var date: Date
    var allowsTime = true

    @Environment(\.calendar) private var calendar
    @State private var visible: Date
    @State private var showsMonth: Bool
    @State private var showsTime = false

    init(title: String, date: Binding<Date>, allowsTime: Bool = true, startsExpanded: Bool = false) {
        self.title = title
        _date = date
        self.allowsTime = allowsTime
        _visible = State(initialValue: date.wrappedValue)
        _showsMonth = State(initialValue: startsExpanded)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let now = Date.now
        VStack(alignment: .leading, spacing: Spacing.s1) {
            header(now: now)
            Group {
                if showsMonth {
                    monthGrid(now: now)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(Array(DateStrip.week(of: visible, calendar: calendar).enumerated()), id: \.offset) { item in
                            dayCell(item.element, initial: DateStrip.weekdayInitials[item.offset], now: now)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 24).onEnded { value in
                    let width = value.translation.width
                    guard abs(width) > abs(value.translation.height), abs(width) > 40 else { return }
                    shift(width < 0 ? 1 : -1, now: now)
                }
            )
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
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: date) { _, newValue in visible = newValue }
    }

    /// Título pequeño, "noviembre 2026" (abre o cierra el mes), "Hoy" y las flechas.
    private func header(now: Date) -> some View {
        HStack(spacing: Spacing.s1) {
            Button {
                withAnimation(.snappy) { showsMonth.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).appFont(.leyenda).foregroundStyle(Palette.texto2)
                    HStack(spacing: Spacing.s1) {
                        Text(DateStrip.monthLabel(visible, calendar: calendar)).appFont(.titulo3).foregroundStyle(Palette.texto1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.texto2)
                            .rotationEffect(.degrees(showsMonth ? 180 : 0))
                    }
                }
                .frame(minHeight: Size.toqueMinimo, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(DateStrip.spokenDate(date, calendar: calendar))")
            .accessibilityHint(showsMonth ? "Cierra el mes" : "Abre el mes completo")
            Spacer(minLength: Spacing.s1)
            if !calendar.isDate(date, inSameDayAs: now) {
                Button("Hoy") { pick(now, now: now) }
                    .appFont(.etiqueta)
                    .foregroundStyle(Palette.brasaTinta)
                    .frame(minWidth: Size.toqueMinimo, minHeight: Size.toqueMinimo)
                    .buttonStyle(.plain)
            }
            arrow(-1, now: now)
            arrow(1, now: now)
        }
    }

    private func arrow(_ step: Int, now: Date) -> some View {
        let enabled = showsMonth
            ? DateStrip.canShiftMonth(from: visible, by: step, now: now, calendar: calendar)
            : DateStrip.canShiftWeek(from: visible, by: step, now: now, calendar: calendar)
        let unit = showsMonth ? "mes" : "semana"
        return Button {
            shift(step, now: now)
        } label: {
            Image(systemName: step < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.texto1)
                .frame(width: 40, height: Size.toqueMinimo)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(step < 0 ? "\(unit.capitalized) anterior" : "\(unit.capitalized) siguiente")
    }

    /// El mes completo, de lunes a domingo, con los días de los meses vecinos en gris.
    private func monthGrid(now: Date) -> some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(DateStrip.weekdayInitials.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .accessibilityHidden(true)
                }
            }
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(DateStrip.monthGrid(of: visible, calendar: calendar), id: \.date) { day in
                    dayCell(day.date, initial: nil, inMonth: day.inMonth, now: now)
                }
            }
        }
    }

    /// Un día: inicial del día (solo en la semana) y número; elegido en brasa, hoy con borde brasa.
    private func dayCell(_ day: Date, initial: String?, inMonth: Bool = true, now: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: date)
        let today = calendar.isDate(day, inSameDayAs: now)
        let enabled = DateStrip.isSelectable(day, now: now, calendar: calendar)
        let number = calendar.component(.day, from: day)
        return Button {
            pick(day, now: now)
        } label: {
            VStack(spacing: 2) {
                if let initial {
                    Text(initial).appFont(.leyenda).foregroundStyle(Palette.texto2)
                }
                Text("\(number)")
                    .appFont(.cuerpo2)
                    .fontWeight(selected || today ? .semibold : .regular)
                    .foregroundStyle(selected ? Palette.sobreBrasa : today ? Palette.brasaTinta : inMonth ? Palette.texto1 : Palette.texto2)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(selected ? Palette.brasa : Color.clear))
                    .overlay {
                        if today && !selected { Circle().stroke(Palette.brasa, lineWidth: 1.5) }
                    }
            }
            .frame(maxWidth: .infinity, minHeight: Size.toqueMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? (inMonth ? 1 : 0.55) : 0.25)
        .accessibilityLabel(today ? "Hoy, \(DateStrip.spokenDate(day, calendar: calendar))" : DateStrip.spokenDate(day, calendar: calendar))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func pick(_ day: Date, now: Date) {
        date = DateStrip.clamp(DayShortcut.combine(day: day, time: date, calendar: calendar), now: now, calendar: calendar)
        visible = date
        if showsMonth { withAnimation(.snappy) { showsMonth = false } }
    }

    private func shift(_ step: Int, now: Date) {
        if showsMonth {
            guard DateStrip.canShiftMonth(from: visible, by: step, now: now, calendar: calendar) else { return }
            withAnimation(.snappy) { visible = DateStrip.shiftMonth(visible, by: step, calendar: calendar) }
        } else {
            guard DateStrip.canShiftWeek(from: visible, by: step, now: now, calendar: calendar) else { return }
            withAnimation(.snappy) { visible = DateStrip.shiftWeek(visible, by: step, calendar: calendar) }
        }
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
    /// Agregar lo muestra dentro de la fila "Termina", que ya lleva el título.
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            if showsTitle {
                Text("Termina").appFont(.titulo3).foregroundStyle(Palette.texto1)
            }
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
