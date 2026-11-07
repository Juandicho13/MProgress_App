import SwiftUI

/// Cada cuánto se repite un pago mensual: Mensual, Cada 2 meses, Trimestral, Semestral, Anual o
/// Cada N meses con un contador de 1 a 24. Lo usan Agregar y editar pago fijo.
struct MonthIntervalPicker: View {
    @Binding var interval: MonthInterval
    @Binding var months: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack {
                Text("Cada cuánto").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                Spacer()
                Picker("Cada cuánto", selection: $interval) {
                    ForEach(MonthInterval.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .tint(Palette.texto2)
            }
            .frame(minHeight: Size.toqueMinimo)
            if interval == .otro {
                Stepper("Cada \(months) \(months == 1 ? "mes" : "meses")", value: $months, in: MonthInterval.range)
                    .appFont(.cuerpo)
                    .foregroundStyle(Palette.texto1)
                    .frame(minHeight: Size.toqueMinimo)
            }
        }
    }
}
