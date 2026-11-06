import Foundation
import SwiftData
import UserNotifications
import Observation

/// Ajustes de avisos guardados en el teléfono (pantalla 22).
enum AlertSettings {
    /// Aviso general de pagos fijos activado (PLAN_F12B "Avisos en dos niveles").
    static let enabledKey = "avisos.general"
    static let daysBeforeKey = "avisos.diasAntes"
    static let atMinutesKey = "avisos.hora"
    static let budgetsKey = "avisos.limites"
    static let cardsKey = "avisos.tarjetas"
    static let weeklyKey = "avisos.resumenSemanal"
    /// Ya se hizo la pregunta "¿Te aviso antes de cada pago?".
    static let askedKey = "avisos.preguntado"

    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static var daysBefore: Int { UserDefaults.standard.object(forKey: daysBeforeKey) as? Int ?? 3 }
    static var atMinutes: Int { UserDefaults.standard.object(forKey: atMinutesKey) as? Int ?? 540 }
    static var general: GeneralReminder { GeneralReminder(enabled: enabled, daysBefore: daysBefore, atMinutes: atMinutes) }

    /// "3 días antes · 9:00 a. m.", "El mismo día · 9:00 a. m." o "Apagado".
    static func summary(enabled: Bool, daysBefore: Int, atMinutes: Int) -> String {
        guard enabled else { return "Apagado" }
        let days = daysBefore == 0 ? "El mismo día" : "\(daysBefore) \(daysBefore == 1 ? "día" : "días") antes"
        return "\(days) · \(ReminderPlanner.timeText(atMinutes))"
    }
    static var budgets: Bool { UserDefaults.standard.object(forKey: budgetsKey) as? Bool ?? true }
    static var cards: Bool { UserDefaults.standard.object(forKey: cardsKey) as? Bool ?? true }
    static var weekly: Bool { UserDefaults.standard.object(forKey: weeklyKey) as? Bool ?? false }
}

/// Programa las notificaciones locales. Siempre borra las suyas ("mp.") y las vuelve a crear desde los datos,
/// así nunca quedan avisos viejos de un pago que cambió o se borró.
@MainActor
enum NotificationScheduler {
    static let prefix = "mp."

    /// Pide permiso solo cuando hace falta: al crear el primer aviso (F07-01). Devuelve si hay permiso.
    @discardableResult
    static func requestIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    /// La persona dijo que no: solo se puede activar desde Ajustes del iPhone.
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// Todavía no se ha pedido el permiso.
    static func isUndetermined() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    /// Reprograma todo a partir de la base. No pide permiso: si no lo hay, no hace nada.
    static func reschedule(context: ModelContext, now: Date = .now, calendar: Calendar = .current) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard let spaces = try? context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.deletedAt == nil })) else { return }
        for space in spaces {
            let id = space.id
            let recurring = (try? context.fetch(FetchDescriptor<Recurring>(predicate: #Predicate<Recurring> { $0.spaceId == id && $0.deletedAt == nil }))) ?? []
            let rules = ((try? PlanningStore(context: context).reminders(spaceId: id)) ?? []).map(\.rule)
            let cards = AlertSettings.cards ? ((try? MoneyStore(context: context).products(spaceId: id)) ?? []).map(\.record) : []
            let plan = ReminderPlanner.plan(recurring: recurring.map(\.record), rules: rules, general: AlertSettings.general, cards: cards,
                                            cardRule: (daysBefore: AlertSettings.daysBefore, atMinutes: AlertSettings.atMinutes),
                                            currency: space.currency, now: now, calendar: calendar)
            for item in plan {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
                let request = UNNotificationRequest(identifier: item.id, content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
                try? await center.add(request)
            }
        }

        if AlertSettings.weekly {
            let content = UNMutableNotificationContent()
            content.title = "Tu semana"
            content.body = "Mira en qué se fue la plata esta semana y lo que viene."
            var parts = DateComponents()
            parts.weekday = 1
            parts.hour = 19
            let request = UNNotificationRequest(identifier: "\(prefix)semanal", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
            try? await center.add(request)
        }
    }
}

/// Pide el permiso de notificaciones en el momento justo (PLAN_F12B): al crear el primer pago fijo o al terminar
/// el onboarding si hay fijos, con la pregunta "¿Te aviso antes de cada pago?". Nunca al abrir la app sin contexto.
/// RootView muestra la pregunta cuando `pending` es true.
@MainActor
@Observable
final class NotificationAsk {
    static let shared = NotificationAsk()
    var pending = false

    /// Deja la pregunta lista si nunca se hizo y el permiso no se ha pedido.
    func offerIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: AlertSettings.askedKey) else { return }
        guard await NotificationScheduler.isUndetermined() else {
            UserDefaults.standard.set(true, forKey: AlertSettings.askedKey)
            return
        }
        // Espera a que se cierre la hoja que acaba de guardar, para que la pregunta no choque con ella.
        try? await Task.sleep(for: .milliseconds(700))
        pending = true
    }

    /// "Sí, avísame": pide el permiso del sistema y programa los avisos.
    func accept(context: ModelContext) async {
        UserDefaults.standard.set(true, forKey: AlertSettings.askedKey)
        pending = false
        _ = await NotificationScheduler.requestIfNeeded()
        await NotificationScheduler.reschedule(context: context)
    }

    /// "Ahora no": no se vuelve a preguntar; queda en Ajustes › Avisos.
    func decline() {
        UserDefaults.standard.set(true, forKey: AlertSettings.askedKey)
        pending = false
    }
}
