import Foundation

/// Reglas de "Nueva categoría" y de editar una categoría propia. Igual en Android (`domain/CategoryForm.kt`).
/// Los íconos se guardan como nombre de SF Symbol en los dos (Android los dibuja con su equivalente de Material).
enum CategoryForm {
    static let maxLength = 30

    /// Los 30 íconos que se ofrecen, con palabras en español para sugerir uno según el nombre.
    static let icons: [(symbol: String, words: String)] = [
        ("cart", "mercado super compras supermercado"), ("fork.knife", "comida restaurante salidas almuerzo"),
        ("cup.and.saucer", "cafe tinto desayuno"), ("house", "casa hogar renta arriendo"),
        ("bolt", "luz energia servicios"), ("drop", "agua"), ("wifi", "internet"), ("iphone", "celular plan telefono"),
        ("car", "carro gasolina parqueadero"), ("bus", "bus transporte taxi"), ("airplane", "viaje viajes vuelo vacaciones"),
        ("play.rectangle", "streaming series peliculas entretenimiento"), ("music.note", "musica"),
        ("gamecontroller", "juegos videojuegos"), ("briefcase", "trabajo oficina"), ("dumbbell", "gimnasio deporte"),
        ("cross.case", "salud medico"), ("pills", "medicina drogueria farmacia"), ("graduationcap", "estudio universidad educacion"),
        ("book", "libros lectura"), ("pawprint", "mascota mascotas perro gato"), ("gift", "regalo regalos"),
        ("heart", "pareja amor"), ("person.2", "amigos social familia"), ("tshirt", "ropa"),
        ("scissors", "peluqueria belleza"), ("wrench.and.screwdriver", "arreglos mantenimiento"),
        ("creditcard", "tarjeta pagos deudas"), ("banknote", "sueldo efectivo dinero ahorro"), ("building.2", "negocio empresa"),
    ]

    /// Ícono que se marca al abrir el formulario vacío.
    static let defaultIcon = "cart"

    /// Nombre limpio: sin espacios de más y con 30 letras como máximo.
    static func cleanName(_ raw: String) -> String {
        let words = raw.split(whereSeparator: { $0.isWhitespace })
        return String(words.joined(separator: " ").prefix(maxLength))
    }

    enum Problem: Equatable, Sendable {
        case empty, duplicate

        var message: String {
            switch self {
            case .empty: "Escribe un nombre"
            case .duplicate: "Ya tienes una categoría con ese nombre"
            }
        }
    }

    /// Qué impide guardar, si algo. Dos categorías no pueden llamarse igual (sin tildes ni mayúsculas).
    /// `editing` es la que se está cambiando, que no choca consigo misma.
    static func problem(name: String, existing: [(id: UUID, name: String)], editing: UUID? = nil) -> Problem? {
        let key = InitialUpload.normalizedName(cleanName(name))
        guard !key.isEmpty else { return .empty }
        let taken = existing.contains { $0.id != editing && InitialUpload.normalizedName($0.name) == key }
        return taken ? .duplicate : nil
    }

    /// Ícono sugerido para lo que se escribió ("Mascotas" da la huella). Nil si ninguna palabra coincide.
    static func suggestedIcon(for name: String) -> String? {
        let words = InitialUpload.normalizedName(name).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        for word in words where word.count >= 3 {
            if let hit = icons.first(where: { item in item.words.split(separator: " ").contains { $0.hasPrefix(word) || word.hasPrefix($0) } }) {
                return hit.symbol
            }
        }
        return nil
    }

    /// Orden de una categoría nueva: después de las propias y antes de "Otros" (que tiene 99).
    static func nextSort(existing: [Int]) -> Int {
        let below = existing.filter { $0 < 99 }
        return min(98, (below.max() ?? 14) + 1)
    }
}
