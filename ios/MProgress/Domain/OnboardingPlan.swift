import Foundation

/// Reglas del onboarding (F02), puras para poder probarlas.
enum OnboardingPlan {
    /// Próxima fecha con ese día del mes, desde hoy (incluido). Si el mes no tiene ese día, usa el último.
    static func nextDate(day: Int, from now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let thisMonth = date(day: day, inMonthOf: today, calendar: calendar)
        if calendar.startOfDay(for: thisMonth) >= today { return thisMonth }
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: CycleMath.startOfMonth(today, calendar)) ?? today
        return date(day: day, inMonthOf: nextMonth, calendar: calendar)
    }

    /// Sueldo: si el día de pago ya pasó este mes (o es hoy), se registra el ingreso de este mes
    /// y el pago fijo empieza el mes siguiente. Si no, el pago fijo empieza este mes.
    static func salaryPlan(payday: Int, now: Date, calendar: Calendar) -> (registerOn: Date?, nextDate: Date) {
        let today = calendar.startOfDay(for: now)
        let thisMonth = date(day: payday, inMonthOf: today, calendar: calendar)
        if calendar.startOfDay(for: thisMonth) <= today {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: CycleMath.startOfMonth(today, calendar)) ?? today
            return (thisMonth, date(day: payday, inMonthOf: nextMonth, calendar: calendar))
        }
        return (nil, thisMonth)
    }

    private static func date(day: Int, inMonthOf month: Date, calendar: Calendar) -> Date {
        let last = CycleMath.daysInMonth(month, calendar)
        var parts = calendar.dateComponents([.year, .month], from: month)
        parts.day = min(max(1, day), last)
        parts.hour = 9
        return calendar.date(from: parts) ?? month
    }
}

/// Gasto fijo sugerido en el onboarding.
struct FixedSuggestion: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let symbol: String
    let categoryName: String
    let units: Int64
    let day: Int
    let selectedByDefault: Bool

    /// Los mismos del diseño (pantalla 16). Montos de referencia en COP que la persona ajusta.
    static let defaults: [FixedSuggestion] = [
        FixedSuggestion(id: "renta", name: "Renta", symbol: "house", categoryName: "Renta", units: 1_500_000, day: 1, selectedByDefault: false),
        FixedSuggestion(id: "streaming", name: "Streaming", symbol: "play.rectangle", categoryName: "Entretenimiento", units: 45_500, day: 8, selectedByDefault: false),
        FixedSuggestion(id: "musica", name: "Música", symbol: "music.note", categoryName: "Música", units: 16_900, day: 12, selectedByDefault: true),
        FixedSuggestion(id: "nube", name: "Nube", symbol: "icloud", categoryName: "Productividad", units: 10_500, day: 19, selectedByDefault: false),
        FixedSuggestion(id: "gimnasio", name: "Gimnasio", symbol: "dumbbell", categoryName: "Deporte", units: 119_900, day: 6, selectedByDefault: true),
        FixedSuggestion(id: "ia", name: "Suscripción IA", symbol: "sparkles", categoryName: "Productividad", units: 85_000, day: 12, selectedByDefault: true),
    ]
}

/// Intereses del paso 3. Deciden qué funciones se muestran después.
enum Interest: String, CaseIterable, Identifiable, Sendable {
    case applePay, cuentas, pareja, limite, ahorro, avisos, widget, recibos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .applePay: "Registrar al pagar con el iPhone"
        case .cuentas: "Separar trabajo, casa o viaje"
        case .pareja: "Llevar las cuentas en pareja"
        case .limite: "Ponerme un límite al mes"
        case .ahorro: "Ahorrar para algo"
        case .avisos: "Avisarme antes de cada cargo"
        case .widget: "Verlo en la pantalla de inicio"
        case .recibos: "Escanear recibos"
        }
    }

    var symbol: String {
        switch self {
        case .applePay: "wave.3.right"
        case .cuentas: "square.stack"
        case .pareja: "person.2"
        case .limite: "gauge.with.dots.needle.33percent"
        case .ahorro: "building.columns"
        case .avisos: "bell.badge"
        case .widget: "square.grid.2x2"
        case .recibos: "doc.viewfinder"
        }
    }

    var slideTitle: String {
        switch self {
        case .applePay: "Pagas y queda anotado"
        case .cuentas: "Cada gasto en su cuenta"
        case .pareja: "Las cuentas del hogar, sin enredos"
        case .limite: "Un límite que te avisa"
        case .ahorro: "Metas que se llenan solas"
        case .avisos: "Avisos para quien toca"
        case .widget: "Tu mes en la pantalla de inicio"
        case .recibos: "Escanea y listo"
        }
    }

    var slideMessage: String {
        switch self {
        case .applePay: "Con Apple Pay o el SMS del banco, el comercio, el monto y la tarjeta se registran solos."
        case .cuentas: "Personal, trabajo o un viaje, cada uno con sus totales y su límite."
        case .pareja: "Cada uno en su celular, quién pagó qué y cuánto se deben."
        case .limite: "Pon un tope al mes o por categoría y te avisamos antes de pasarte."
        case .ahorro: "Aparta para un viaje o un fondo de emergencia, solo o en pareja."
        case .avisos: "A los dos, solo a ti o solo a tu pareja, de 1 a 14 días antes."
        case .widget: "Lo que te queda y el próximo cobro sin abrir la app."
        case .recibos: "Toma una foto del recibo y el gasto queda listo para revisar."
        }
    }

    static let defaultSelection: Set<Interest> = [.applePay, .cuentas, .pareja, .avisos, .widget]
}
