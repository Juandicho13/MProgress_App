import SwiftUI
import SwiftData

/// Selecciona ícono (pantalla 8): iniciales o símbolos, con buscador.
struct IconPickerView: View {
    @Binding var selection: String?
    let name: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    /// Símbolos con palabras en español para el buscador.
    static let symbols: [(symbol: String, words: String)] = [
        ("cart", "mercado super compras"), ("fork.knife", "comida restaurante salida"), ("cup.and.saucer", "cafe tinto"),
        ("house", "renta arriendo casa hogar"), ("bolt", "luz energia servicio"), ("drop", "agua servicio"),
        ("flame", "gas servicio"), ("wifi", "internet"), ("iphone", "celular plan telefono"),
        ("car", "carro gasolina transporte"), ("bus", "bus transporte"), ("airplane", "viaje vuelo"),
        ("play.rectangle", "streaming series peliculas"), ("music.note", "musica"), ("gamecontroller", "juegos"),
        ("icloud", "nube almacenamiento"), ("sparkles", "ia inteligencia artificial"), ("briefcase", "trabajo oficina"),
        ("dumbbell", "gimnasio deporte"), ("cross.case", "salud medico farmacia"), ("pills", "medicina drogueria"),
        ("graduationcap", "estudio universidad educacion"), ("book", "libros"), ("pawprint", "mascota perro gato"),
        ("gift", "regalo"), ("heart", "pareja amor"), ("person.2", "amigos social"), ("tshirt", "ropa"),
        ("scissors", "peluqueria"), ("wrench.and.screwdriver", "arreglos mantenimiento"), ("creditcard", "tarjeta pago"),
        ("banknote", "sueldo efectivo dinero"), ("building.columns", "banco"), ("chart.line.uptrend.xyaxis", "inversion"),
        ("arrow.left.arrow.right", "transferencia"), ("building.2", "negocio empresa"),
    ]

    private var filtered: [(symbol: String, words: String)] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        guard !text.isEmpty else { return Self.symbols }
        return Self.symbols.filter { $0.words.contains(text) || $0.symbol.contains(text) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    SectionLabel(text: "Iniciales")
                    choice(content: .initials(name.isEmpty ? "?" : name), isSelected: selection == nil) {
                        selection = nil
                        dismiss()
                    }
                    SectionLabel(text: "Símbolos")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s3), count: 5), spacing: Spacing.s3) {
                        ForEach(filtered, id: \.symbol) { item in
                            choice(content: .symbol(item.symbol), isSelected: selection == item.symbol) {
                                selection = item.symbol
                                dismiss()
                            }
                            .accessibilityLabel(item.words.components(separatedBy: " ").first ?? item.symbol)
                        }
                    }
                    Text("Los logos de marcas llegan más adelante.")
                        .appFont(.cuerpo2)
                        .foregroundStyle(Palette.texto2)
                }
                .padding(Spacing.margen)
            }
            .searchable(text: $query, prompt: "Buscar ícono")
            .navigationTitle("Ícono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .background(Palette.superficie2)
        }
    }

    private func choice(content: IconTile.Content, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IconTile(content: content, tint: isSelected ? Palette.brasaVelo : Palette.superficie3,
                     foreground: isSelected ? Palette.brasaTinta : Palette.texto1, size: 56)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? Palette.brasa : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Categoría (pantalla 9): recientes y todas.
struct CategoryPickerView: View {
    @Binding var selection: UUID?
    let spaceId: UUID
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SpendCategory> { $0.deletedAt == nil }, sort: \SpendCategory.sort) private var all: [SpendCategory]

    private var available: [SpendCategory] { all.filter { $0.ownerSpaceId == nil || $0.ownerSpaceId == spaceId } }
    private var recent: [SpendCategory] {
        available.filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(3).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    if !recent.isEmpty {
                        SectionLabel(text: "Recientes")
                        group(recent)
                    }
                    SectionLabel(text: "Todas")
                    group(available)
                    Button("Sin categoría") {
                        selection = nil
                        dismiss()
                    }
                    .buttonStyle(.secondary)
                }
                .padding(Spacing.margen)
            }
            .navigationTitle("Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .background(Palette.superficie2)
        }
    }

    private func group(_ items: [SpendCategory]) -> some View {
        Card(padding: Spacing.s2) {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    let isSelected = item.id == selection
                    Button {
                        selection = item.id
                        dismiss()
                    } label: {
                        HStack(spacing: Spacing.s3) {
                            IconTile(content: .symbol(item.icon), tint: isSelected ? Palette.brasaVelo : Palette.superficie3,
                                     foreground: isSelected ? Palette.brasaTinta : Palette.texto1, size: 36)
                            Text(item.name)
                                .appFont(.cuerpo)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .foregroundStyle(isSelected ? Palette.brasaTinta : Palette.texto1)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.brasaTinta)
                            }
                        }
                        .padding(.horizontal, Spacing.s2)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}
