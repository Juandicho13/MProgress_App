package com.olarte.mprogress.domain

/**
 * Reglas de "Nueva categoría" y de editar una categoría propia, igual que CategoryForm de iOS.
 * Los íconos se guardan como nombre de SF Symbol (así viajan igual a iOS); Android los dibuja con su equivalente de Material.
 */
object CategoryForm {
    const val MAX_LENGTH = 30

    /** Los 30 íconos que se ofrecen, con palabras en español para sugerir uno según el nombre. */
    val icons: List<Pair<String, String>> = listOf(
        "cart" to "mercado super compras supermercado", "fork.knife" to "comida restaurante salidas almuerzo",
        "cup.and.saucer" to "cafe tinto desayuno", "house" to "casa hogar renta arriendo",
        "bolt" to "luz energia servicios", "drop" to "agua", "wifi" to "internet", "iphone" to "celular plan telefono",
        "car" to "carro gasolina parqueadero", "bus" to "bus transporte taxi", "airplane" to "viaje viajes vuelo vacaciones",
        "play.rectangle" to "streaming series peliculas entretenimiento", "music.note" to "musica",
        "gamecontroller" to "juegos videojuegos", "briefcase" to "trabajo oficina", "dumbbell" to "gimnasio deporte",
        "cross.case" to "salud medico", "pills" to "medicina drogueria farmacia", "graduationcap" to "estudio universidad educacion",
        "book" to "libros lectura", "pawprint" to "mascota mascotas perro gato", "gift" to "regalo regalos",
        "heart" to "pareja amor", "person.2" to "amigos social familia", "tshirt" to "ropa",
        "scissors" to "peluqueria belleza", "wrench.and.screwdriver" to "arreglos mantenimiento",
        "creditcard" to "tarjeta pagos deudas", "banknote" to "sueldo efectivo dinero ahorro", "building.2" to "negocio empresa",
    )

    /** Ícono que se marca al abrir el formulario vacío. */
    const val DEFAULT_ICON = "cart"

    /** Nombre limpio: sin espacios de más y con 30 letras como máximo. */
    fun cleanName(raw: String) = raw.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ").take(MAX_LENGTH)

    enum class Problem(val message: String) { EMPTY("Escribe un nombre"), DUPLICATE("Ya tienes una categoría con ese nombre") }

    /** Qué impide guardar, si algo. Dos categorías no pueden llamarse igual (sin tildes ni mayúsculas). */
    fun problem(name: String, existing: List<CategoryRecord>, editing: String? = null): Problem? {
        val key = InitialUpload.normalizedName(cleanName(name))
        if (key.isEmpty()) return Problem.EMPTY
        val taken = existing.any { !it.id.equals(editing, ignoreCase = true) && InitialUpload.normalizedName(it.name) == key }
        return if (taken) Problem.DUPLICATE else null
    }

    /** Ícono sugerido para lo que se escribió ("Mascotas" da la huella). Null si ninguna palabra coincide. */
    fun suggestedIcon(name: String): String? {
        val words = InitialUpload.normalizedName(name).split(" ").filter { it.length >= 3 }
        for (word in words) {
            icons.firstOrNull { (_, ws) -> ws.split(" ").any { it.startsWith(word) || word.startsWith(it) } }?.let { return it.first }
        }
        return null
    }

    /** Orden de una categoría nueva: después de las propias y antes de "Otros" (que tiene 99). */
    fun nextSort(existing: List<Int>): Int = minOf(98, (existing.filter { it < 99 }.maxOrNull() ?: 14) + 1)
}
