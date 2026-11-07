import Foundation

/// Los dos días de un pago quincenal. Por defecto el 15 y el último día del mes (la nómina de Colombia).
/// 31 quiere decir "último día": en cada mes cae en su último día (30, 31, 28 o 29).
struct QuincenaDays: Hashable, Codable, Sendable {
    static let lastDay = 31
    /// Entre los dos días hay por lo menos 13 días, así son dos pagos de verdad y no dos seguidos.
    static let minGap = 13
    /// El primer día se elige de 1 a 28.
    static let firstChoices = 1...28
    static let standard = QuincenaDays(first: 15, second: 31)

    var first: Int
    var second: Int

    init(first: Int, second: Int) {
        self.first = min(QuincenaDays.lastDay, max(1, first))
        self.second = min(QuincenaDays.lastDay, max(1, second))
    }

    /// El día que va primero en el mes.
    var low: Int { min(first, second) }
    /// El día que va después en el mes.
    var high: Int { max(first, second) }

    var isValid: Bool { abs(first - second) >= QuincenaDays.minGap }

    /// "15" o "último día".
    static func dayTitle(_ day: Int) -> String { day >= lastDay ? "último día" : "\(day)" }

    /// "15 y último día", "15 y 30", "5 y 20".
    var title: String { "\(QuincenaDays.dayTitle(low)) y \(QuincenaDays.dayTitle(high))" }

    /// Días que sirven de segundo día: a 13 días o más del primero. 31 es "Último día".
    static func secondChoices(first: Int) -> [Int] {
        (1...lastDay).filter { abs($0 - first) >= minGap }
    }

    /// El segundo día que se pone al cambiar el primero: quince días después, el último día o quince días antes.
    static func suggestedSecond(first: Int) -> Int {
        if first <= 14 { return first + 15 }
        if first <= 18 { return lastDay }
        return first - 15
    }

    /// Cambia el primer día (1 a 28) y deja el segundo si sigue sirviendo; si no, pone el sugerido.
    func withFirst(_ day: Int) -> QuincenaDays {
        let first = min(QuincenaDays.firstChoices.upperBound, max(QuincenaDays.firstChoices.lowerBound, day))
        let keeps = QuincenaDays.secondChoices(first: first).contains(second)
        return QuincenaDays(first: first, second: keeps ? second : QuincenaDays.suggestedSecond(first: first))
    }

    /// Cambia el segundo día si sirve con el primero.
    func withSecond(_ day: Int) -> QuincenaDays {
        QuincenaDays.secondChoices(first: first).contains(day) ? QuincenaDays(first: first, second: day) : self
    }
}

enum QuincenaMath {
    /// El día de quincena de `date` si lo es; si no, el siguiente. Conserva la hora de `date`.
    static func onOrAfter(_ date: Date, days: QuincenaDays, calendar: Calendar) -> Date {
        let day = calendar.component(.day, from: date)
        let last = CycleMath.daysInMonth(date, calendar)
        if day == min(days.low, last) || day == min(days.high, last) { return date }
        return CycleMath.nextQuincena(after: date, days: days, calendar: calendar) ?? date
    }
}

/// "¿Se repite?" en Agregar y en editar pago fijo: Una vez, Semanal, Quincenal, Mensual u Otra.
enum RepeatChoice: String, CaseIterable, Identifiable, Sendable {
    case unaVez, semanal, quincenal, mensual, otra

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unaVez: "Una vez"
        case .semanal: "Semanal"
        case .quincenal: "Quincenal"
        case .mensual: "Mensual"
        case .otra: "Otra"
        }
    }
}

/// Unidad de "Cada N" en Otra.
enum RepeatUnit: String, CaseIterable, Identifiable, Sendable {
    case dias, semanas, meses, anios

    var id: String { rawValue }

    /// Lo que se puede escribir en cada unidad.
    var range: ClosedRange<Int> {
        switch self {
        case .dias: 1...365
        case .semanas: 1...52
        case .meses: 1...24
        case .anios: 1...2
        }
    }

    /// "días" o "día" según el número.
    func title(count: Int) -> String {
        let one = count == 1
        switch self {
        case .dias: return one ? "día" : "días"
        case .semanas: return one ? "semana" : "semanas"
        case .meses: return one ? "mes" : "meses"
        case .anios: return one ? "año" : "años"
        }
    }

    /// Título del selector: siempre en plural.
    var title: String { title(count: 2) }
}

/// Atajos de Otra: Cada 2 meses, Trimestral, Semestral y Anual.
enum RepeatPreset: String, CaseIterable, Identifiable, Sendable {
    case bimestral, trimestral, semestral, anual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bimestral: "Cada 2 meses"
        case .trimestral: "Trimestral"
        case .semestral: "Semestral"
        case .anual: "Anual"
        }
    }

    var unit: RepeatUnit { self == .anual ? .anios : .meses }

    var count: Int {
        switch self {
        case .bimestral: 2
        case .trimestral: 3
        case .semestral: 6
        case .anual: 1
        }
    }
}

/// Lo que la persona eligió en "¿Se repite?" y el ciclo que resulta. Una sola fuente para Agregar y editar pago fijo.
struct RepeatDraft: Equatable, Sendable {
    var choice: RepeatChoice = .unaVez
    var quincena: QuincenaDays = .standard
    /// Otra: "Cada [N] [unidad]". El número va como texto porque se escribe con el teclado.
    var unit: RepeatUnit = .meses
    var countText = "2"

    init(choice: RepeatChoice = .unaVez) {
        self.choice = choice
    }

    /// El borrador que corresponde a un ciclo guardado (para editar).
    init(cycle: Cycle) {
        switch cycle {
        case .puntual: choice = .unaVez
        case .semanal: choice = .semanal
        case .mensual: choice = .mensual
        case .quincenal(let days):
            choice = .quincenal
            quincena = days
        case .anual:
            choice = .otra
            unit = .anios
            countText = "1"
        case .cadaMeses(let months):
            choice = .otra
            unit = months == 24 ? .anios : .meses
            countText = months == 24 ? "2" : "\(months)"
        case .cadaDias(let days):
            choice = .otra
            if days % 7 == 0, RepeatUnit.semanas.range.contains(days / 7), days >= 14 {
                unit = .semanas
                countText = "\(days / 7)"
            } else {
                unit = .dias
                countText = "\(days)"
            }
        }
    }

    /// El número escrito en Otra. Nil si está vacío.
    var count: Int? { Int(countText.filter(\.isNumber).prefix(4)) }

    /// Otra con un número dentro del rango de su unidad (lo demás siempre sirve).
    var isValid: Bool {
        guard choice == .otra else { return true }
        guard let count else { return false }
        return unit.range.contains(count)
    }

    /// "Escribe de 1 a 24 meses" cuando el número no sirve.
    var hint: String? {
        guard choice == .otra, !isValid else { return nil }
        return "Escribe de \(unit.range.lowerBound) a \(unit.range.upperBound) \(unit.title)"
    }

    /// Quien escribe cada 15 días casi siempre quiere la quincena.
    var tip: String? {
        choice == .otra && unit == .dias && count == 15 ? "¿Quincenal? Usa Quincenal para 15 y 30" : nil
    }

    /// El ciclo que se guarda. Con un número fuera de rango usa el más cercano (Guardar espera a que sea válido).
    var cycle: Cycle {
        switch choice {
        case .unaVez: return .puntual
        case .semanal: return .semanal
        case .quincenal: return .quincenal(quincena)
        case .mensual: return .mensual
        case .otra:
            let n = min(unit.range.upperBound, max(unit.range.lowerBound, count ?? unit.range.lowerBound))
            switch unit {
            case .dias: return n == 7 ? .semanal : .cadaDias(n)
            case .semanas: return n == 1 ? .semanal : .cadaDias(7 * n)
            case .meses: return Cycle.months(n)
            case .anios: return n == 1 ? .anual : .cadaMeses(24)
            }
        }
    }

    /// El atajo que corresponde a lo escrito, si hay.
    var preset: RepeatPreset? {
        guard choice == .otra else { return nil }
        return RepeatPreset.allCases.first { $0.unit == unit && $0.count == count }
    }

    mutating func apply(_ preset: RepeatPreset) {
        choice = .otra
        unit = preset.unit
        countText = "\(preset.count)"
    }

    /// Lo que dice la fila plegada: "Mensual", "Quincenal", "Trimestral", "Cada 10 días", "Cada 2 años".
    var title: String {
        switch choice {
        case .otra: isValid ? cycle.title : "Cada \(countText.isEmpty ? "N" : countText) \(unit.title)"
        default: choice.title
        }
    }

    /// "cada 3 meses", "cada semana", "cada 2 años".
    var everyText: String? {
        guard choice == .otra, isValid, let count else { return nil }
        let noun = unit.title(count: count)
        return count == 1 ? "cada \(noun)" : "cada \(count) \(noun)"
    }

    /// "Se repite cada 3 meses, el próximo es el 7 feb". Nil si no es Otra o el número no sirve.
    func summary(next: Date?, calendar: Calendar, now: Date) -> String? {
        guard let every = everyText else { return nil }
        guard let next else { return "Se repite \(every)" }
        return "Se repite \(every), el próximo es el \(DueText.shortDate(next, calendar: calendar, now: now))"
    }
}
