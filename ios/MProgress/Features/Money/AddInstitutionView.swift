import SwiftUI
import SwiftData

/// "+ Banco": nombre y color del banco o billetera. Efectivo crea de una vez su billetera.
struct AddInstitutionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let spaceId: UUID
    @State private var name = ""
    @State private var colorHex = InstitutionStyle.palette[0]
    @State private var errorText: String?

    private var clean: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    HStack(spacing: Spacing.s3) {
                        InstitutionStyle.tile(name: clean.isEmpty ? "?" : clean, hex: colorHex, size: 60)
                        TextField("Nombre del banco o billetera", text: $name)
                            .appFont(.titulo2)
                            .foregroundStyle(Palette.texto1)
                            .textInputAutocapitalization(.words)
                    }
                    SectionLabel(text: "Sugerencias")
                    FlowChips(items: InstitutionStyle.suggestions.map(\.name)) { pick in
                        name = pick
                        colorHex = InstitutionStyle.suggestions.first { $0.name == pick }?.hex ?? colorHex
                    }
                    SectionLabel(text: "Color")
                    HStack(spacing: Spacing.s2) {
                        ForEach(InstitutionStyle.palette, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle()
                                    .fill(InstitutionStyle.color(hex))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Palette.texto1, lineWidth: colorHex == hex ? 2 : 0).padding(-3))
                            }
                            .frame(minWidth: 36, minHeight: Size.toqueMinimo)
                            .accessibilityLabel("Color \(InstitutionStyle.palette.firstIndex(of: hex).map { $0 + 1 } ?? 0)")
                            .accessibilityAddTraits(colorHex == hex ? [.isSelected] : [])
                        }
                    }
                    Text("No nos conectamos a tu banco. Tú pones los saldos y nosotros llevamos la cuenta.")
                        .appFont(.leyenda)
                        .foregroundStyle(Palette.texto2)
                }
                .padding(.horizontal, Spacing.margen)
                .padding(.vertical, Spacing.s4)
            }
            .background(Palette.superficie2.ignoresSafeArea())
            .navigationTitle("Nuevo banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Agregar") { save() }.disabled(clean.isEmpty) }
            }
            .alert("No se pudo guardar", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func save() {
        let store = MoneyStore(context: context)
        do {
            if clean.caseInsensitiveCompare("Efectivo") == .orderedSame {
                // Ya hay efectivo: se agrega otro con nombre propio dentro del mismo grupo.
                let cash = try store.products(spaceId: spaceId).filter { $0.kind == .efectivo }
                if cash.isEmpty {
                    try store.cash(spaceId: spaceId)
                } else {
                    try store.addCash(spaceId: spaceId, name: WalletMath.nextCashName(existing: cash.map(\.name)))
                }
            } else {
                try store.addInstitution(spaceId: spaceId, name: clean, colorHex: colorHex)
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Chips que pasan a la siguiente línea cuando no caben.
struct FlowChips: View {
    let items: [String]
    let onPick: (String) -> Void

    var body: some View {
        FlowLayout(spacing: Spacing.s2) {
            ForEach(items, id: \.self) { item in
                Chip(title: item) { onPick(item) }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += row + spacing
                x = 0
                row = 0
            }
            x += size.width + spacing
            row = max(row, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(width, widest), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += row + spacing
                x = bounds.minX
                row = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}
