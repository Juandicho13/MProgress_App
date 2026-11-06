import WidgetKit
import SwiftUI
import AppIntents

// MARK: Colores Forja (los mismos de la app, sin depender de su código)

private enum Forja {
    static let fondo = Color(red: 0.039, green: 0.043, blue: 0.051)
    static let superficie = Color(red: 0.102, green: 0.110, blue: 0.125)
    static let texto1 = Color(red: 0.953, green: 0.957, blue: 0.965)
    static let texto2 = Color(red: 0.62, green: 0.64, blue: 0.67)
    static let brasa = Color(red: 0.961, green: 0.373, blue: 0.122)
    static let oro = Color(red: 0.961, green: 0.769, blue: 0.318)
    static let hielo = Color(red: 0.424, green: 0.769, blue: 0.949)
    static let peligro = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let sobreBrasa = Color.white
    static let sobreOro = Color(red: 0.08, green: 0.04, blue: 0.02)

    static func cifra(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .default).width(.expanded) }
    static func texto(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
}

// MARK: Datos

struct MProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    /// Sin App Group (cuenta gratuita) no hay datos: se invita a abrir la app.
    let canShare: Bool
}

struct MProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> MProgressEntry {
        MProgressEntry(date: .now, snapshot: .sample, canShare: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (MProgressEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MProgressEntry>) -> Void) {
        // Se redibuja al cambiar de día (los "faltan N días") y cuando la app avisa que cambió algo.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [current()], policy: .after(tomorrow)))
    }

    private func current() -> MProgressEntry {
        MProgressEntry(date: .now, snapshot: WidgetSnapshot.load(), canShare: WidgetSnapshot.canShare)
    }
}

// MARK: Pequeño · próximo cargo

struct NextChargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "proximo-cargo", provider: MProgressProvider()) { entry in
            NextChargeView(entry: entry)
                .containerBackground(Forja.fondo, for: .widget)
                .widgetURL(WidgetSnapshot.Link.fixed)
        }
        .configurationDisplayName("Próximo cargo")
        .description("Lo próximo que se cobra y cuándo.")
        .supportedFamilies([.systemSmall])
    }
}

struct NextChargeView: View {
    let entry: MProgressEntry

    var body: some View {
        if let charge = entry.snapshot?.charges.first {
            VStack(alignment: .leading, spacing: 4) {
                UrgencyBadge(daysLeft: charge.daysLeft)
                Spacer()
                Text(charge.name).font(Forja.texto(14, .semibold)).foregroundStyle(Forja.texto1).lineLimit(1)
                Text(charge.amountText).font(Forja.cifra(18)).foregroundStyle(Forja.texto1).minimumScaleFactor(0.6).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            EmptyWidgetView(entry: entry, message: "Sin cobros próximos")
        }
    }
}

// MARK: Mediano · te quedan, + Gasto y 4 cargos

struct RemainingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "te-quedan", provider: MProgressProvider()) { entry in
            RemainingView(entry: entry)
                .containerBackground(Forja.fondo, for: .widget)
                .widgetURL(WidgetSnapshot.Link.home)
        }
        .configurationDisplayName("Te quedan")
        .description("Cuánto te queda este mes, tus próximos cobros y un botón para anotar.")
        .supportedFamilies([.systemMedium])
    }
}

struct RemainingView: View {
    let entry: MProgressEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Te quedan").font(Forja.texto(12)).foregroundStyle(Forja.texto2)
                if let snapshot = entry.snapshot {
                    Text(snapshot.remainingText)
                        .font(Forja.cifra(22))
                        .foregroundStyle(snapshot.remainingIsNegative ? Forja.peligro : Forja.texto1)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                } else {
                    Text("Abre la app").font(Forja.texto(15, .semibold)).foregroundStyle(Forja.texto1)
                }
                Spacer(minLength: 0)
                QuickAddButton()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array((entry.snapshot?.charges ?? []).prefix(4).enumerated()), id: \.offset) { item in
                    HStack {
                        Text(item.element.name).font(Forja.texto(12)).foregroundStyle(Forja.texto1).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.element.dueText)
                            .font(Forja.texto(12, .semibold))
                            .foregroundStyle(item.element.daysLeft <= 1 ? Forja.oro : Forja.texto2)
                    }
                }
                if entry.snapshot?.charges.isEmpty ?? true {
                    Text(entry.canShare ? "Sin cobros próximos" : "Los cobros aparecen con la cuenta de desarrollador")
                        .font(Forja.texto(11)).foregroundStyle(Forja.texto2)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: Grande · calendario del mes

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "calendario", provider: MProgressProvider()) { entry in
            CalendarWidgetView(entry: entry)
                .containerBackground(Forja.fondo, for: .widget)
                .widgetURL(WidgetSnapshot.Link.calendar)
        }
        .configurationDisplayName("Calendario de cobros")
        .description("El mes con los días en que se cobra algo.")
        .supportedFamilies([.systemLarge])
    }
}

struct CalendarWidgetView: View {
    let entry: MProgressEntry

    var body: some View {
        let snapshot = entry.snapshot ?? .sample
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.monthTitle).font(Forja.texto(16, .bold)).foregroundStyle(Forja.texto1)
                Spacer()
                Text("\(snapshot.chargesThisMonth) cargos").font(Forja.texto(12)).foregroundStyle(Forja.texto2)
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(snapshot.weekdaySymbols.enumerated()), id: \.offset) { item in
                    Text(item.element).font(Forja.texto(11)).foregroundStyle(Forja.texto2)
                }
                ForEach(0..<snapshot.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 22) }
                ForEach(1...max(1, snapshot.daysInMonth), id: \.self) { day in
                    DayCell(day: day, today: day == snapshot.today, urgency: snapshot.chargeDays[String(day)])
                }
            }
            Spacer(minLength: 0)
            if let next = snapshot.charges.first {
                HStack {
                    Text("Próximo · \(next.name)").font(Forja.texto(12)).foregroundStyle(Forja.texto2).lineLimit(1)
                    Spacer()
                    Text(next.amountText).font(Forja.texto(13, .bold)).foregroundStyle(Forja.texto1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(Forja.superficie))
            }
        }
        .redacted(reason: entry.snapshot == nil ? .placeholder : [])
    }
}

private struct DayCell: View {
    let day: Int
    let today: Bool
    let urgency: Int?

    var body: some View {
        Text("\(day)")
            .font(Forja.texto(12, urgency == nil ? .medium : .bold))
            .foregroundStyle(urgency == nil ? (today ? Forja.brasa : Forja.texto1) : (urgency == 0 ? Forja.sobreBrasa : Forja.sobreOro))
            .frame(maxWidth: .infinity, minHeight: 22)
            .background(
                Capsule().fill(color).padding(.horizontal, 3)
            )
            .overlay(
                Capsule().stroke(today && urgency == nil ? Forja.brasa : .clear, lineWidth: 1.2).padding(.horizontal, 3)
            )
    }

    private var color: Color {
        switch urgency {
        case 0: Forja.brasa
        case 1: Forja.oro
        case 2: Forja.texto1.opacity(0.85)
        default: .clear
        }
    }
}

// MARK: Pantalla bloqueada · anillo y próximo cargo

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "bloqueo", provider: MProgressProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(WidgetSnapshot.Link.fixed)
        }
        .configurationDisplayName("MProgress")
        .description("Cuánto llevas del mes y lo próximo que se cobra.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MProgressEntry

    var body: some View {
        let ratio = entry.snapshot?.spentRatio ?? 0
        let next = entry.snapshot?.charges.first
        switch family {
        case .accessoryCircular:
            Gauge(value: min(1, max(0, ratio))) {
                Image(systemName: "creditcard")
            } currentValueLabel: {
                Text("\(Int((ratio * 100).rounded()))%").font(.system(size: 12, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Gauge(value: min(1, max(0, ratio))) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(next.map { "\($0.name) \($0.dueText.lowercased())" } ?? "Sin cobros").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(next?.amountText ?? (entry.snapshot?.remainingText ?? "MProgress")).font(.system(size: 13, weight: .bold)).lineLimit(1)
                }
            }
        default:
            Text(next.map { "\($0.name) · \($0.dueText.lowercased())" } ?? "Sin cobros próximos")
        }
    }
}

// MARK: Centro de control · Registro rápido

struct QuickAddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.olarte.mprogress.registro-rapido") {
            ControlWidgetButton(action: OpenURLIntent(WidgetSnapshot.Link.quickAdd)) {
                Label("Anotar gasto", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Registro rápido")
        .description("Abre MProgress listo para anotar un gasto o un ingreso.")
    }
}

// MARK: Piezas

private struct QuickAddButton: View {
    var body: some View {
        Link(destination: WidgetSnapshot.Link.quickAdd) {
            Text("+ Gasto")
                .font(Forja.texto(14, .bold))
                .foregroundStyle(Forja.sobreBrasa)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(Forja.brasa))
        }
    }
}

private struct UrgencyBadge: View {
    let daysLeft: Int

    var body: some View {
        let label = daysLeft <= 0 ? "HOY" : daysLeft == 1 ? "MAÑANA" : "EN \(daysLeft) DÍAS"
        Text(label)
            .font(Forja.texto(10, .heavy))
            .foregroundStyle(daysLeft <= 0 ? Forja.sobreBrasa : Forja.sobreOro)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(daysLeft <= 0 ? Forja.brasa : daysLeft <= 3 ? Forja.oro : Forja.texto2))
    }
}

private struct EmptyWidgetView: View {
    let entry: MProgressEntry
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "circle.circle").font(.system(size: 22, weight: .bold)).foregroundStyle(Forja.brasa)
            Spacer()
            Text(entry.canShare ? message : "Abre MProgress").font(Forja.texto(14, .semibold)).foregroundStyle(Forja.texto1)
            Text(entry.canShare ? "Todo al día" : "Toca para ver tus cobros").font(Forja.texto(11)).foregroundStyle(Forja.texto2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Paquete

@main
struct MProgressWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextChargeWidget()
        RemainingWidget()
        CalendarWidget()
        LockScreenWidget()
        QuickAddControl()
    }
}

#Preview(as: .systemMedium) {
    RemainingWidget()
} timeline: {
    MProgressEntry(date: .now, snapshot: .sample, canShare: true)
}

#Preview(as: .systemLarge) {
    CalendarWidget()
} timeline: {
    MProgressEntry(date: .now, snapshot: .sample, canShare: true)
}
