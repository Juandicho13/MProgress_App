import SwiftUI
import SwiftData

/// Bienvenida y onboarding (pantallas 14 a 18).
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var model = OnboardingModel()
    @State private var errorText: String?
    let onFinish: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProgressBar(value: model.progress)
                .padding(.horizontal, Spacing.margen)
                .padding(.top, Spacing.s2)

            Group {
                switch model.step {
                case .bienvenida: WelcomeStep(model: model)
                case .ingreso: IncomeStep(model: model)
                case .fijos: FixedStep(model: model)
                case .intereses: InterestsStep(model: model)
                case .funciones: FeatureStep(model: model, onFinish: finish)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.step)
        }
        .background(Palette.fondo.ignoresSafeArea())
        .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func finish() {
        do {
            try model.finish(context: context)
            onFinish()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: Piezas comunes

private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.superficie3)
                Capsule().fill(Palette.brasa).frame(width: max(8, proxy.size.width * value))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: value)
        .accessibilityElement()
        .accessibilityLabel("Progreso")
        .accessibilityValue("\(Int(value * 100)) %")
    }
}

private struct StepHeader: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(title)
                .appFont(.titulo1)
                .foregroundStyle(Palette.texto1)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .appFont(.cuerpo)
                .foregroundStyle(Palette.texto2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StepFooter: View {
    let back: String
    let next: String
    var nextEnabled = true
    let onBack: @MainActor () -> Void
    let onNext: @MainActor () -> Void

    var body: some View {
        HStack(spacing: Spacing.s3) {
            Button(back, action: onBack)
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 120)
            Button(next, action: onNext)
                .buttonStyle(.primary)
                .disabled(!nextEnabled)
        }
    }
}

// MARK: Paso 0 · Bienvenida

private struct WelcomeStep: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s6) {
            PhonePreview()
                .frame(height: 360)
                .padding(.top, Spacing.s5)
            StepHeader(title: "Sabe cuánto te queda, solo o en pareja",
                       message: "Anota lo que entra y lo que sale, y MProgress te dice cada día cuánto te queda.")
            VStack(spacing: 0) {
                TrustRow(symbol: "building.columns", title: "Sin conectar tu banco", message: "Tus datos se quedan en tu iPhone")
                Divider().overlay(Palette.linea)
                TrustRow(symbol: "icloud.slash", title: "Funciona sin internet", message: "Se sincroniza cuando vuelves")
            }
            Spacer(minLength: 0)
            Button("Empezar") { model.next() }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s4)
    }
}

private struct TrustRow: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: Spacing.s4) {
            IconTile(content: .symbol(symbol), tint: Palette.superficie1, size: 48, circle: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(.titulo3).foregroundStyle(Palette.texto1)
                Text(message).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
            }
            Spacer()
        }
        .padding(.vertical, Spacing.s3)
        .accessibilityElement(children: .combine)
    }
}

/// iPhone de muestra con Inicio dentro (pantalla 14).
private struct PhonePreview: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Radius.hoja, style: .continuous).fill(Palette.superficie1)
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack {
                    Avatar(name: "Tú", size: 22)
                    Text("Personal").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Inicio").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Color.clear.frame(width: 40, height: 1)
                }
                Text("Te quedan en el mes").font(.system(size: 11)).foregroundStyle(Palette.texto2)
                Text(Money(units: 1_901_100).formatted()).appFont(.cifraGrande)
                Text("− $ 81.900 con Apple Pay, anotado solo").font(.system(size: 11)).foregroundStyle(Palette.texto2)
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(index == 0 ? Palette.brasa : Palette.superficie1)
                            .frame(height: 48)
                    }
                }
                Text("Próximos cargos").font(.system(size: 14, weight: .semibold))
                MiniRow(initials: "GY", name: "Gimnasio", amount: 119_900, tint: Palette.superficie3)
                MiniRow(initials: "RN", name: "Renta · Hogar", amount: 1_137_500, tint: Palette.hielo)
            }
            .foregroundStyle(Palette.texto1)
            .padding(.horizontal, Spacing.s4)
            .padding(.top, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .fill(Palette.fondo)
                    .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).stroke(Palette.superficie3, lineWidth: 7))
            )
            .overlay(alignment: .top) {
                Capsule().fill(.black).frame(width: 92, height: 26).padding(.top, 12)
            }
            .padding(.horizontal, 38)
            .padding(.top, 34)
            .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.hoja, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct MiniRow: View {
    let initials: String
    let name: String
    let amount: Int64
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.s2) {
            IconTile(content: .initials(initials), tint: tint, foreground: Palette.texto1, size: 30, circle: true)
            Text(name).font(.system(size: 12))
            Spacer()
            Text(Money(units: amount).formatted()).font(.system(size: 12, weight: .semibold))
        }
    }
}

// MARK: Paso 1 · Ingreso

private struct IncomeStep: View {
    @Bindable var model: OnboardingModel
    private let paydays = [1, 15, 30]
    @State private var showsOtherDay = false

    var body: some View {
        VStack(spacing: Spacing.s5) {
            StepHeader(title: "¿Cuánto entra al mes?",
                       message: "Tu sueldo o lo que ganes en promedio. Con eso te digo cuánto te queda.")
                .padding(.top, Spacing.s6)
            AmountDisplay(input: model.income)
            HStack(spacing: Spacing.s2) {
                Text("Me pagan el día").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                ForEach(paydays, id: \.self) { day in
                    DayChip(title: "\(day)", selected: model.payday == day) { model.payday = day }
                }
                DayChip(title: paydays.contains(model.payday) ? "Otro" : "\(model.payday)", selected: !paydays.contains(model.payday)) {
                    showsOtherDay = true
                }
            }
            HStack {
                Button("Prefiero no decirlo") {
                    model.income = AmountInput(currency: model.income.currency)
                    model.next()
                }
                .appFont(.cuerpo2)
                .foregroundStyle(Palette.texto2)
                .frame(minHeight: Size.toqueMinimo)
                Spacer()
                Button("Siguiente") { model.next() }
                    .buttonStyle(.primary)
                    .frame(width: 160)
                    .disabled(model.income.money.isZero)
            }
            Spacer(minLength: 0)
            NumericKeypad(input: $model.income)
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s4)
        .sheet(isPresented: $showsOtherDay) {
            DayPicker(selection: $model.payday).presentationDetents([.medium])
        }
    }
}

private struct DayChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appFont(.etiqueta)
                .foregroundStyle(selected ? Palette.sobreBrasa : Palette.texto1)
                .frame(minWidth: Size.toqueMinimo, minHeight: 40)
                .padding(.horizontal, Spacing.s1)
                .background(Capsule().fill(selected ? Palette.brasa : Palette.superficie3))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct DayPicker: View {
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.s4) {
            Text("¿Qué día te pagan?").appFont(.titulo2).foregroundStyle(Palette.texto1).padding(.top, Spacing.s6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 7), spacing: Spacing.s2) {
                ForEach(1...31, id: \.self) { day in
                    Button("\(day)") {
                        selection = day
                        dismiss()
                    }
                    .appFont(.cuerpo)
                    .foregroundStyle(selection == day ? Palette.sobreBrasa : Palette.texto1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Circle().fill(selection == day ? Palette.brasa : Color.clear))
                    .buttonStyle(.plain)
                }
            }
            Text("Si el mes no tiene ese día, se usa el último.").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
            Spacer()
        }
        .padding(.horizontal, Spacing.margen)
        .background(Palette.superficie2.ignoresSafeArea())
    }
}

// MARK: Paso 2 · Gastos fijos

private struct FixedStep: View {
    @Bindable var model: OnboardingModel
    @State private var editing: FixedSuggestion?

    var body: some View {
        VStack(spacing: Spacing.s5) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    StepHeader(title: "¿Qué pagas cada mes?",
                               message: "Marca los tuyos y ajusta el monto. Luego puedes cambiarlos.")
                        .padding(.top, Spacing.s6)
                    Card(padding: Spacing.s2) {
                        VStack(spacing: 0) {
                            ForEach(FixedSuggestion.defaults) { item in
                                let selected = model.fixedSelected.contains(item.id)
                                HStack(spacing: Spacing.s3) {
                                    IconTile(content: .symbol(item.symbol))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).appFont(.titulo3).foregroundStyle(Palette.texto1)
                                        Text("Día \(item.day)").appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                                    }
                                    Spacer()
                                    Button {
                                        editing = item
                                    } label: {
                                        Text(Money(units: model.fixedUnits[item.id] ?? item.units).formatted())
                                            .appFont(.cifraPequena)
                                            .foregroundStyle(selected ? Palette.texto1 : Palette.texto2)
                                            .frame(minHeight: Size.toqueMinimo)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Cambiar monto de \(item.name)")
                                    CheckCircle(on: selected)
                                }
                                .padding(.horizontal, Spacing.s2)
                                .frame(minHeight: 64)
                                .contentShape(Rectangle())
                                .onTapGesture { model.toggleFixed(item.id) }
                                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            StepFooter(back: "Atrás", next: "Siguiente", onBack: { model.back() }, onNext: { model.next() })
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s4)
        .sheet(item: $editing) { item in
            FixedAmountSheet(item: item, units: model.fixedUnits[item.id] ?? item.units) { units in
                model.fixedUnits[item.id] = units
                model.fixedSelected.insert(item.id)
            }
            .presentationDetents([.large])
        }
    }
}

private struct CheckCircle: View {
    let on: Bool

    var body: some View {
        ZStack {
            Circle().stroke(on ? Palette.brasa : Palette.lineaControl, lineWidth: 2)
            if on {
                Circle().fill(Palette.brasa)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.sobreBrasa)
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }
}

private struct FixedAmountSheet: View {
    let item: FixedSuggestion
    let onSave: @MainActor (Int64) -> Void
    @State private var input: AmountInput
    @Environment(\.dismiss) private var dismiss

    init(item: FixedSuggestion, units: Int64, onSave: @escaping @MainActor (Int64) -> Void) {
        self.item = item
        self.onSave = onSave
        _input = State(initialValue: AmountInput(text: String(units)))
    }

    var body: some View {
        VStack(spacing: Spacing.s5) {
            Text(item.name).appFont(.titulo2).foregroundStyle(Palette.texto1).padding(.top, Spacing.s6)
            AmountDisplay(input: input)
            Spacer()
            Button("Listo") {
                onSave(input.money.minor / input.currency.minorPerUnit)
                dismiss()
            }
            .buttonStyle(.primary)
            .disabled(input.money.isZero)
            NumericKeypad(input: $input)
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s4)
        .background(Palette.superficie2.ignoresSafeArea())
    }
}

// MARK: Paso 3 · Intereses

private struct InterestsStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: Spacing.s5) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    StepHeader(title: "¿Qué más quieres que haga por ti?",
                               message: "Elige lo que te interese y te lo muestro.")
                        .padding(.top, Spacing.s6)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s3), GridItem(.flexible())], spacing: Spacing.s3) {
                        ForEach(Interest.allCases) { interest in
                            InterestCard(interest: interest, selected: model.interests.contains(interest)) {
                                model.toggleInterest(interest)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            StepFooter(back: "Ahora no", next: model.interests.isEmpty ? "Siguiente" : "Muéstramelo (\(model.interests.count))",
                       onBack: { model.interests = []; model.next() }, onNext: { model.next() })
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s4)
    }
}

private struct InterestCard: View {
    let interest: Interest
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HStack {
                    Image(systemName: interest.symbol).font(.system(size: 22, weight: .medium))
                    Spacer()
                    CheckCircle(on: selected)
                }
                Text(interest.title)
                    .appFont(.titulo3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Palette.texto1)
            .padding(Spacing.s4)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Radius.boton, style: .continuous)
                    .fill(selected ? Palette.brasaVelo : Palette.superficie1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.boton, style: .continuous)
                    .stroke(selected ? Palette.brasa : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Paso 4 · Funciones elegidas

private struct FeatureStep: View {
    @Bindable var model: OnboardingModel
    let onFinish: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            if let interest = model.slides.indices.contains(model.slideIndex) ? model.slides[model.slideIndex] : nil {
                FeatureArt(interest: interest)
                    .frame(height: 340)
                    .padding(.top, Spacing.s5)
                    .id(interest)
                    .transition(.opacity)
                Text(interest.slideTitle)
                    .appFont(.titulo1)
                    .foregroundStyle(Palette.texto1)
                Text(interest.slideMessage)
                    .appFont(.cuerpo)
                    .foregroundStyle(Palette.texto2)
            } else {
                Spacer()
                StepHeader(title: "Todo listo", message: "Puedes activar más funciones cuando quieras desde Ajustes.")
            }
            Spacer(minLength: 0)
            StepFooter(back: "Atrás", next: model.isLastSlide || model.slides.isEmpty ? "Empezar a usar" : "Siguiente",
                       onBack: { model.back() }) {
                if model.isLastSlide || model.slides.isEmpty {
                    onFinish()
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) { model.next() }
                }
            }
        }
        .padding(.horizontal, Spacing.margen)
        .padding(.bottom, Spacing.s4)
    }
}

/// Ilustración de cada función: una notificación de ejemplo sobre la tarjeta.
private struct FeatureArt: View {
    let interest: Interest

    private var sample: (title: String, detail: String) {
        switch interest {
        case .applePay: ("Gasto registrado", "$ 81.900 en el mercado · Crédito ·· 4417")
        case .cuentas: ("Cuenta Trabajo", "3 gastos reembolsables este mes")
        case .pareja: ("Mariana registró un gasto", "Mercado · $ 84.300 · Hogar")
        case .limite: ("Vas en el 80 % de Salidas", "Te quedan $ 50.000 hasta fin de mes")
        case .ahorro: ("Viaje juntos al 48 %", "$ 2.400.000 de $ 5.000.000")
        case .avisos: ("La renta vence en 3 días", "Para Juan · $ 2.275.000")
        case .widget: ("Te quedan $ 1.901.100", "Próximo: Gimnasio mañana")
        case .recibos: ("Recibo leído", "Farmacia · $ 32.400 · listo para revisar")
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.hoja, style: .continuous)
                .fill(LinearGradient(colors: [Palette.brasaVelo, Palette.superficie1], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: interest.symbol)
                .font(.system(size: 120, weight: .ultraLight))
                .foregroundStyle(Palette.brasa.opacity(0.25))
            HStack(spacing: Spacing.s3) {
                IconTile(content: .symbol("circle.circle"), tint: Palette.brasa, foreground: Palette.sobreBrasa, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sample.title).appFont(.titulo3).foregroundStyle(Palette.texto1)
                    Text(sample.detail).appFont(.cuerpo2).foregroundStyle(Palette.texto2)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.s4)
            .glassBackground(RoundedRectangle(cornerRadius: Radius.boton, style: .continuous))
            .padding(.horizontal, Spacing.s5)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, Spacing.s6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sample.title). \(sample.detail)")
    }
}

#Preview {
    OnboardingView {}
        .modelContainer(try! Persistence.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
