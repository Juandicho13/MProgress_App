import Foundation
import SwiftData
import UserNotifications

/// Avisos de Quién te debe: el día antes de la fecha límite, a la hora de los avisos. Los programa
/// NotificationScheduler.reschedule después de borrar los suyos (ids "mp.deuda.").
@MainActor
enum DebtNotifications {
    static func schedule(context: ModelContext, now: Date, calendar: Calendar) async {
        let center = UNUserNotificationCenter.current()
        guard let spaces = try? context.fetch(FetchDescriptor<Space>(predicate: #Predicate<Space> { $0.deletedAt == nil })) else { return }
        let store = DebtStore(context: context)
        for space in spaces {
            let debts = ((try? store.debts(spaceId: space.id)) ?? []).map(\.record)
            guard !debts.isEmpty else { continue }
            let payments = ((try? store.payments(spaceId: space.id)) ?? []).map(\.record)
            let plan = DebtMath.reminders(debts, payments: payments, atMinutes: AlertSettings.atMinutes, currency: space.currency,
                                          now: now, calendar: calendar)
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
    }
}
