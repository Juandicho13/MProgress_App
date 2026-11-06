import Foundation
import SwiftData
import UserNotifications

/// Borrar cuenta y datos (requisito de Apple para publicar): borra todo lo de este iPhone. La cuenta en la nube
/// se borra antes con `CloudAccount.deleteRemoteAccount()` (Ajustes lo hace en ese orden).
enum AccountEraser {
    @MainActor
    static func eraseAll(context: ModelContext) throws {
        // 1. Datos de la base local, sin dejar papelera.
        try context.delete(model: Entry.self)
        try context.delete(model: Split.self)
        try context.delete(model: Transfer.self)
        try context.delete(model: Recurring.self)
        try context.delete(model: Reminder.self)
        try context.delete(model: Budget.self)
        try context.delete(model: GoalContribution.self)
        try context.delete(model: SavingsGoal.self)
        try context.delete(model: RewardProgram.self)
        try context.delete(model: Product.self)
        try context.delete(model: Institution.self)
        try context.delete(model: SpendCategory.self)
        try context.delete(model: Space.self)
        try context.save()

        // 2. Respaldos cifrados y su llave.
        try? FileManager.default.removeItem(at: BackupService.folder)
        BackupCrypto.deleteKey()

        // 3. Avisos programados y ya mostrados.
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        // 4. Sesión, llaves de cifrado e identidad del dispositivo en el llavero.
        CloudAccount.shared.forgetEverything()

        // 5. Preferencias (tema, accesos rápidos, onboarding) y datos de los widgets.
        if let bundle = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundle)
        }
        if let url = WidgetSnapshot.fileURL { try? FileManager.default.removeItem(at: url) }

        // 6. La base queda lista para empezar de cero con el onboarding.
        _ = try Seed.runIfNeeded(context: context, localUser: LocalIdentity.userId)
        WidgetPublisher.publish(context: context)
    }
}
