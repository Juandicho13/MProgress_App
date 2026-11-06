import Foundation
#if canImport(MProgress)
@testable import MProgress
#else
@testable import MPDomain
#endif

/// Calendario fijo para que las pruebas den igual en cualquier máquina.
let bogota: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Bogota")!
    calendar.locale = Locale(identifier: "es_CO")
    return calendar
}()

func fecha(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    return bogota.date(from: parts)!
}

func dia(_ date: Date) -> String {
    let parts = bogota.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
}

func pesos(_ units: Int64) -> Int64 { units * 100 }
