import SwiftUI

/// Apariencia (pantalla 5): vista previa del vidrio, 4 niveles, Seguir a iOS y tema.
struct AppearanceView: View {
    @AppStorage(GlassLevel.storageKey) private var glassRaw = GlassLevel.normal.rawValue
    @AppStorage(AppTheme.storageKey) private var themeRaw = AppTheme.oscuro.rawValue
    @AppStorage(GlassLevel.followSystemKey) private var followSystem = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var level: GlassLevel { GlassLevel(rawValue: glassRaw) ?? .normal }

    private var followText: String {
        switch (followSystem, reduceTransparency) {
        case (true, true): "Reducir transparencia está activo en tu iPhone, así que el vidrio se ve sólido."
        case (true, false): "Si activas Reducir transparencia en Ajustes del iPhone, el vidrio se vuelve sólido."
        case (false, _): "La app usa el nivel que elegiste aquí, sin mirar Reducir transparencia."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                Text("Apariencia").appFont(.titulo1).foregroundStyle(Palette.texto1).accessibilityAddTraits(.isHeader)
                preview
                SectionLabel(text: "Transparencia del vidrio")
                SegmentedPill(options: GlassLevel.allCases.map { (value: $0.rawValue, title: $0.title) }, selection: $glassRaw)
                SectionLabel(text: "Tema")
                SegmentedPill(options: AppTheme.allCases.map { (value: $0.rawValue, title: $0.title) }, selection: $themeRaw)
                Card {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Toggle(isOn: $followSystem) {
                            Text("Seguir a iOS").appFont(.titulo3).foregroundStyle(Palette.texto1)
                        }
                        .tint(Palette.brasa)
                        Text(followText)
                            .appFont(.cuerpo2)
                            .foregroundStyle(Palette.texto2)
                    }
                }
                Text("El texto siempre se mantiene legible: con menos transparencia el vidrio se oscurece y nunca baja del contraste mínimo.")
                    .appFont(.leyenda)
                    .foregroundStyle(Palette.texto2)
                SignatureFooter()
            }
            .padding(.horizontal, Spacing.margen)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.fondo.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Fondo con color detrás de una barra de vidrio, para ver el efecto del nivel elegido.
    private var preview: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Palette.brasa, Color(hex: 0x6CC4F2), Palette.oroRelleno], startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack {
                ForEach(["Inicio", "Resumen", "Dinero", "Ajustes"], id: \.self) { title in
                    Text(title)
                        .appFont(.pestana)
                        .foregroundStyle(title == "Inicio" ? Palette.brasaTinta : Palette.texto1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 52)
            .glassBackground(Capsule())
            .environment(\.glassLevel, level)
            .padding(Spacing.s4)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tarjeta, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Vista previa del vidrio en nivel \(level.title)")
    }
}
