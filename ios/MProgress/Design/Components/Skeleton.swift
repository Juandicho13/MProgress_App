import SwiftUI

/// Esqueleto de carga (pantalla 41). Brilla suave; con Reducir movimiento queda quieto.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var radius: CGFloat = 12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Palette.superficie1)
            .frame(width: width, height: height)
            .opacity(reduceMotion ? 1 : (lit ? 0.55 : 1))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: lit)
            .onAppear { lit = true }
            .accessibilityHidden(true)
    }
}

/// Inicio mientras carga.
struct HomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s6) {
            HStack {
                SkeletonBlock(width: 130, height: 44, radius: 22)
                Spacer()
            }
            VStack(alignment: .leading, spacing: Spacing.s3) {
                SkeletonBlock(width: 150, height: 14)
                SkeletonBlock(width: 240, height: 46)
                SkeletonBlock(height: 8, radius: 4)
            }
            HStack(spacing: Spacing.s3) {
                ForEach(0..<4, id: \.self) { _ in SkeletonBlock(height: 76, radius: Radius.boton) }
            }
            SkeletonBlock(height: 260, radius: Radius.tarjeta)
        }
        .padding(.horizontal, Spacing.margen)
        .accessibilityElement()
        .accessibilityLabel("Cargando")
    }
}

#Preview {
    HomeSkeleton().background(Palette.fondo).preferredColorScheme(.dark)
}
