import Foundation

/// Cómo termina un pago fijo (PLAN_F12B Paso 2): nunca, en una fecha (incluida) o después de N cuotas.
enum RecurringEndChoice: String, CaseIterable, Identifiable, Sendable {
    case nunca, fecha, cuotas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nunca: "Nunca"
        case .fecha: "En una fecha"
        case .cuotas: "Después de N cuotas"
        }
    }

    /// Título corto para el control segmentado.
    var shortTitle: String {
        switch self {
        case .nunca: "Nunca"
        case .fecha: "Fecha"
        case .cuotas: "Cuotas"
        }
    }

    static func of(endDate: Date?, totalCount: Int?) -> RecurringEndChoice {
        if totalCount != nil { return .cuotas }
        if endDate != nil { return .fecha }
        return .nunca
    }
}

/// Reglas de los pagos con fin: no hay cobros después de `endDate` ni más de `totalCount - paidCount`.
enum RecurringEnd {
    /// Cobros que faltan por cuotas. Nil si no tiene cuotas.
    static func remainingCount(totalCount: Int?, paidCount: Int) -> Int? {
        guard let totalCount else { return nil }
        return max(0, totalCount - max(0, paidCount))
    }

    /// Una fecha está dentro del fin si cae el mismo día de `endDate` o antes.
    static func isWithin(_ date: Date, endDate: Date?, calendar: Calendar) -> Bool {
        guard let endDate else { return true }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: endDate)
    }

    /// Último instante del día de `endDate`.
    static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return (calendar.date(byAdding: .day, value: 1, to: start) ?? start).addingTimeInterval(-1)
    }

    /// Fechas de cobro desde `nextDate` (incluida) hasta `end` (incluida), sin pasar de `endDate`
    /// ni de las cuotas que faltan. Es la única fuente de fechas de un pago fijo: la usan el mes,
    /// el calendario, los avisos y las predicciones.
    static func dates(of item: RecurringRecord, through end: Date, calendar: Calendar, limit: Int = 400) -> [Date] {
        var cap = limit
        if let remaining = remainingCount(totalCount: item.totalCount, paidCount: item.paidCount) { cap = min(cap, remaining) }
        guard cap > 0 else { return [] }
        var last = end
        if let endDate = item.endDate { last = min(end, endOfDay(endDate, calendar: calendar)) }
        guard item.nextDate <= last else { return [] }
        return CycleMath.occurrences(from: item.nextDate, through: last, cycle: item.cycle, anchor: item.anchor, calendar: calendar, limit: cap)
    }

    /// Ya no le quedan cobros: se acabaron las cuotas o la próxima fecha pasa del fin.
    static func isFinished(nextDate: Date, endDate: Date?, totalCount: Int?, paidCount: Int, calendar: Calendar) -> Bool {
        if let remaining = remainingCount(totalCount: totalCount, paidCount: paidCount), remaining == 0 { return true }
        return !isWithin(nextDate, endDate: endDate, calendar: calendar)
    }

    static func isFinished(_ item: RecurringRecord, calendar: Calendar) -> Bool {
        isFinished(nextDate: item.nextDate, endDate: item.endDate, totalCount: item.totalCount, paidCount: item.paidCount, calendar: calendar)
    }

    /// Lo que queda después de marcar pagado.
    struct Payment: Equatable, Sendable {
        /// Próxima fecha. Nil si el ciclo no se repite (puntual).
        var nextDate: Date?
        var paidCount: Int
        /// Ya no quedan cobros: el pago queda inactivo y se avisa "Terminaste de pagar X".
        var finished: Bool
    }

    /// Marcar pagado suma 1 a `paidCount` y mueve la fecha. Termina al llegar a `totalCount`
    /// o si la siguiente fecha pasa `endDate`.
    static func afterPayment(nextDate: Date, cycle: Cycle, anchor: CycleAnchor, endDate: Date?, totalCount: Int?,
                             paidCount: Int, calendar: Calendar) -> Payment {
        let paid = max(0, paidCount) + 1
        let next = CycleMath.next(after: nextDate, cycle: cycle, anchor: anchor, calendar: calendar)
        guard let next else { return Payment(nextDate: nil, paidCount: paid, finished: true) }
        let finished = isFinished(nextDate: next, endDate: endDate, totalCount: totalCount, paidCount: paid, calendar: calendar)
        return Payment(nextDate: next, paidCount: paid, finished: finished)
    }

    /// "Cuota 3 de 12" (la próxima es `paidCount + 1`), "Hasta 15 mar 2027" o "Terminado". Nil si no tiene fin.
    static func progressText(endDate: Date?, totalCount: Int?, paidCount: Int, finished: Bool, calendar: Calendar) -> String? {
        if finished && (endDate != nil || totalCount != nil) { return "Terminado" }
        if let totalCount, totalCount > 0 {
            return "Cuota \(min(totalCount, max(0, paidCount) + 1)) de \(totalCount)"
        }
        if let endDate { return "Hasta \(fullDate(endDate, calendar: calendar))" }
        return nil
    }

    /// "15 mar 2027": siempre con el año, para que el fin no se confunda.
    static func fullDate(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        let month = DueText.months[max(0, min(11, (parts.month ?? 1) - 1))]
        return "\(parts.day ?? 1) \(month) \(parts.year ?? 0)"
    }

    /// "Terminaste de pagar Celular".
    static func finishedMessage(name: String, kind: EntryKind) -> String {
        kind == .ingreso ? "Ya no quedan pagos de \(name)" : "Terminaste de pagar \(name)"
    }
}
