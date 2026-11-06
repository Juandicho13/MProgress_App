import Foundation

/// Un mes del historial con sus movimientos y totales (F04-01).
struct HistoryMonth: Hashable, Sendable, Identifiable {
    var start: Date
    var entries: [EntryRecord]
    var incomeMinor: Int64
    var spentMinor: Int64

    var id: Date { start }
    /// Lo que entró menos lo que salió.
    var netMinor: Int64 { incomeMinor - spentMinor }
}

/// Un día del historial dentro de un mes, con su total neto.
struct HistoryDay: Hashable, Sendable, Identifiable {
    var day: Date
    var entries: [EntryRecord]
    var netMinor: Int64

    var id: Date { day }
}

enum HistoryMath {
    /// Agrupa por mes, del más nuevo al más viejo. Dentro de cada mes, del más nuevo al más viejo.
    static func months(_ entries: [EntryRecord], calendar: Calendar) -> [HistoryMonth] {
        let grouped = Dictionary(grouping: entries) { CycleMath.startOfMonth($0.occurredAt, calendar) }
        return grouped
            .map { start, items in
                HistoryMonth(
                    start: start,
                    entries: items.sorted(by: newestFirst),
                    incomeMinor: items.filter { $0.kind == .ingreso }.reduce(0) { $0 + $1.amountMinor },
                    spentMinor: items.filter { $0.kind == .gasto }.reduce(0) { $0 + $1.amountMinor }
                )
            }
            .sorted { $0.start > $1.start }
    }

    /// Agrupa por día, del más nuevo al más viejo.
    static func days(_ entries: [EntryRecord], calendar: Calendar) -> [HistoryDay] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.occurredAt) }
        return grouped
            .map { day, items in
                HistoryDay(day: day, entries: items.sorted(by: newestFirst), netMinor: items.reduce(0) { $0 + $1.signedMinor })
            }
            .sorted { $0.day > $1.day }
    }

    /// Busca sin importar mayúsculas ni tildes en el nombre, las notas, la categoría y el monto.
    /// `categoryName` traduce el id de categoría a su nombre.
    static func filter(_ entries: [EntryRecord], query: String, notes: [UUID: String] = [:],
                       categoryName: (UUID) -> String? = { _ in nil }) -> [EntryRecord] {
        let words = normalize(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return entries }
        return entries.filter { entry in
            var haystack = normalize(entry.name)
            if let text = notes[entry.id] { haystack += " " + normalize(text) }
            if let id = entry.categoryId, let name = categoryName(id) { haystack += " " + normalize(name) }
            haystack += " " + String(entry.amountMinor / 100)
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    /// Minúsculas, sin tildes y sin puntos de miles, para comparar.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_CO"))
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func newestFirst(_ a: EntryRecord, _ b: EntryRecord) -> Bool {
        a.occurredAt == b.occurredAt ? a.name < b.name : a.occurredAt > b.occurredAt
    }
}

/// Lo que pasa en un día del calendario (F04-04).
struct CalendarDay: Hashable, Sendable {
    var entries: [EntryRecord] = []
    var charges: [UpcomingCharge] = []

    var hasIncome: Bool { entries.contains { $0.kind == .ingreso } || charges.contains { $0.kind == .ingreso } }
    var hasExpense: Bool { entries.contains { $0.kind == .gasto } }
    var hasCharge: Bool { charges.contains { $0.kind == .gasto } }
    var isEmpty: Bool { entries.isEmpty && charges.isEmpty }
}

enum CalendarMath {
    /// Celdas de la cuadrícula del mes: nil para los huecos antes del día 1, según el primer día de la semana.
    static func grid(month: Date, calendar: Calendar) -> [Date?] {
        let start = CycleMath.startOfMonth(month, calendar)
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let days = CycleMath.daysInMonth(start, calendar)
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<days {
            cells.append(calendar.date(byAdding: .day, value: offset, to: start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// Iniciales de los días en el orden del calendario: "L M M J V S D" si la semana empieza el lunes.
    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let base = ["D", "L", "M", "M", "J", "V", "S"]
        return (0..<7).map { base[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    /// Movimientos y cobros pendientes por día del mes. Los cobros salen de cada pago fijo activo
    /// desde su próxima fecha; los que ya vencieron se muestran en su fecha.
    static func days(month: Date, entries: [EntryRecord], recurring: [RecurringRecord], now: Date, calendar: Calendar) -> [Date: CalendarDay] {
        let start = CycleMath.startOfMonth(month, calendar)
        let end = CycleMath.endOfMonth(month, calendar)
        var result: [Date: CalendarDay] = [:]

        for entry in entries where entry.occurredAt >= start && entry.occurredAt <= end {
            result[calendar.startOfDay(for: entry.occurredAt), default: CalendarDay()].entries.append(entry)
        }
        for item in recurring where item.active {
            for date in CycleMath.occurrences(from: item.nextDate, through: end, cycle: item.cycle, anchor: item.anchor, calendar: calendar)
            where date >= start {
                let charge = UpcomingCharge(
                    recurringId: item.id,
                    name: item.name,
                    kind: item.kind,
                    amountMinor: item.amountMinor,
                    date: date,
                    urgency: Urgency.of(due: date, now: now, calendar: calendar),
                    daysLeft: Urgency.dayDifference(from: now, to: date, calendar: calendar)
                )
                result[calendar.startOfDay(for: date), default: CalendarDay()].charges.append(charge)
            }
        }
        for key in result.keys {
            result[key]?.entries.sort { $0.occurredAt > $1.occurredAt }
            result[key]?.charges.sort { $0.name < $1.name }
        }
        return result
    }

    /// Lo que falta por pagar en el mes según el calendario (solo gastos).
    static func pendingMinor(_ days: [Date: CalendarDay]) -> Int64 {
        days.values.flatMap(\.charges).filter { $0.kind == .gasto }.reduce(0) { $0 + $1.amountMinor }
    }

    static func add(months: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: months, to: CycleMath.startOfMonth(date, calendar)) ?? date
    }
}
