import SwiftUI

/// Fila plegable de Agregar: título a la izquierda, lo elegido a la derecha y una flecha. Al tocarla se abre debajo
/// lo que la cambia. Quien la usa decide cuál está abierta (una a la vez) y anima con `withAnimation(.snappy)`.
struct DisclosureRow<Content: View>: View {
    let title: String
    let value: String
    let expanded: Bool
    let onTap: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: Spacing.s2) {
                    Text(title).appFont(.cuerpo).foregroundStyle(Palette.texto1)
                    Spacer(minLength: Spacing.s2)
                    Text(value)
                        .appFont(.cuerpo2)
                        .foregroundStyle(expanded ? Palette.brasaTinta : Palette.texto2)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.texto2)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, Spacing.s2)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(value)
            .accessibilityHint(expanded ? "Toca para cerrar" : "Toca para cambiar")
            if expanded {
                content
                    .padding(.horizontal, Spacing.s2)
                    .padding(.bottom, Spacing.s3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Otra en "¿Se repite?": atajos (Cada 2 meses, Trimestral, Semestral, Anual) y "Cada [N] [días, semanas, meses o años]"
/// con el número escrito con el teclado numérico. Avisa si el número no sirve y muestra el resumen debajo.
struct RepeatOtherEditor: View {
    @Binding var draft: RepeatDraft
    /// "Se repite cada 3 meses, el próximo es el 7 feb".
    let summary: String?
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            FlowLayout(spacing: Spacing.s2) {
                ForEach(RepeatPreset.allCases) { preset in
                    Chip(title: preset.title, selected: draft.preset == preset) {
                        focused.wrappedValue = false
                        draft.apply(preset)
                    }
                }
            }
            HStack(spacing: Spacing.s2) {
                Text("Cada").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                TextField("N", text: $draft.countText)
                    .keyboardType(.numberPad)
                    .focused(focused)
                    .appFont(.cifra)
                    .foregroundStyle(Palette.texto1)
                    .multilineTextAlignment(.center)
                    .frame(width: 64, height: 44)
                    .background(RoundedRectangle(cornerRadius: Radius.campo, style: .continuous).fill(Palette.superficie3))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.campo, style: .continuous)
                            .stroke(draft.isValid ? Palette.brasa.opacity(focused.wrappedValue ? 1 : 0) : Palette.peligro, lineWidth: 1.5)
                    )
                    .accessibilityLabel("Cada cuántos \(draft.unit.title)")
                    .onChange(of: draft.countText) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(3))
                        if digits != newValue { draft.countText = digits }
                    }
                Picker("Unidad", selection: $draft.unit) {
                    ForEach(RepeatUnit.allCases) { unit in
                        Text(unit.title(count: draft.count ?? 2)).tag(unit)
                    }
                }
                .labelsHidden()
                .tint(Palette.texto1)
                Spacer(minLength: 0)
                if focused.wrappedValue {
                    Button("Listo") { focused.wrappedValue = false }
                        .appFont(.etiqueta)
                        .foregroundStyle(Palette.brasaTinta)
                        .frame(minHeight: Size.toqueMinimo)
                        .buttonStyle(.plain)
                }
            }
            .frame(minHeight: Size.toqueMinimo)
            if let hint = draft.hint {
                Text(hint).appFont(.leyenda).foregroundStyle(Palette.peligro)
            } else if let tip = draft.tip {
                Text(tip).appFont(.leyenda).foregroundStyle(Palette.brasaTinta)
            }
            if let summary {
                Text(summary).appFont(.leyenda).foregroundStyle(Palette.texto2)
            }
        }
    }
}

/// Días de Quincenal: primer día de 1 a 28 y segundo día a 13 días o más (o "Último día").
struct QuincenaDaysEditor: View {
    @Binding var days: QuincenaDays

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Primer día").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                Spacer()
                Picker("Primer día", selection: Binding(get: { days.first }, set: { days = days.withFirst($0) })) {
                    ForEach(Array(QuincenaDays.firstChoices), id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .labelsHidden()
                .tint(Palette.texto2)
            }
            .frame(minHeight: Size.toqueMinimo)
            HStack {
                Text("Segundo día").appFont(.cuerpo).foregroundStyle(Palette.texto1)
                Spacer()
                Picker("Segundo día", selection: Binding(get: { days.second }, set: { days = days.withSecond($0) })) {
                    ForEach(QuincenaDays.secondChoices(first: days.first), id: \.self) { day in
                        Text(day >= QuincenaDays.lastDay ? "Último día" : "\(day)").tag(day)
                    }
                }
                .labelsHidden()
                .tint(Palette.texto2)
            }
            .frame(minHeight: Size.toqueMinimo)
            if days.high > 28 {
                Text("En los meses que no tienen ese día, se paga el último.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
            }
        }
    }
}
