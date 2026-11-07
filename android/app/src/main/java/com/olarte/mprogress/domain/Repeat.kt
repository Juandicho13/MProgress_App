package com.olarte.mprogress.domain

import java.time.LocalDate
import kotlin.math.abs

/**
 * Los dos días de un pago quincenal. Por defecto el 15 y el último día del mes (la nómina de Colombia). 31 quiere decir "último día":
 * en cada mes cae en su último día (30, 31, 28 o 29). Igual que QuincenaDays de iOS.
 */
data class QuincenaDays(val first: Int, val second: Int) {
    /** El día que va primero en el mes. */
    val low: Int get() = minOf(first, second)
    /** El día que va después en el mes. */
    val high: Int get() = maxOf(first, second)
    val isValid: Boolean get() = abs(first - second) >= MIN_GAP
    /** "15 y último día", "15 y 30", "5 y 20". */
    val title: String get() = "${dayTitle(low)} y ${dayTitle(high)}"

    /** Cambia el primer día (1 a 28) y deja el segundo si sigue sirviendo; si no, pone el sugerido. */
    fun withFirst(day: Int): QuincenaDays {
        val f = day.coerceIn(FIRST_CHOICES)
        return QuincenaDays(f, if (second in secondChoices(f)) second else suggestedSecond(f))
    }

    /** Cambia el segundo día si sirve con el primero. */
    fun withSecond(day: Int): QuincenaDays = if (day in secondChoices(first)) QuincenaDays(first, day) else this

    companion object {
        const val LAST_DAY = 31
        /** Entre los dos días hay por lo menos 13 días, así son dos pagos de verdad y no dos seguidos. */
        const val MIN_GAP = 13
        /** El primer día se elige de 1 a 28. */
        val FIRST_CHOICES = 1..28
        val STANDARD = QuincenaDays(15, LAST_DAY)

        fun of(first: Int, second: Int) = QuincenaDays(first.coerceIn(1, LAST_DAY), second.coerceIn(1, LAST_DAY))
        /** "15" o "último día". */
        fun dayTitle(day: Int) = if (day >= LAST_DAY) "último día" else "$day"
        /** Días que sirven de segundo día: a 13 días o más del primero. 31 es "Último día". */
        fun secondChoices(first: Int): List<Int> = (1..LAST_DAY).filter { abs(it - first) >= MIN_GAP }
        /** El segundo día que se pone al cambiar el primero: quince días después, el último día o quince días antes. */
        fun suggestedSecond(first: Int): Int = when {
            first <= 14 -> first + 15
            first <= 18 -> LAST_DAY
            else -> first - 15
        }
    }
}

object QuincenaMath {
    /** El día de quincena de `date` si lo es; si no, el siguiente. */
    fun onOrAfter(date: LocalDate, days: QuincenaDays): LocalDate {
        val last = date.lengthOfMonth()
        if (date.dayOfMonth == minOf(days.low, last) || date.dayOfMonth == minOf(days.high, last)) return date
        return CycleMath.nextQuincena(date, days)
    }
}

/** "¿Se repite?" en Agregar y en editar pago fijo: Una vez, Semanal, Quincenal, Mensual u Otra. */
enum class RepeatChoice(val title: String) { UNA_VEZ("Una vez"), SEMANAL("Semanal"), QUINCENAL("Quincenal"), MENSUAL("Mensual"), OTRA("Otra") }

/** Unidad de "Cada N" en Otra, con lo que se puede escribir en cada una. */
enum class RepeatUnit(val range: IntRange, private val one: String, private val many: String) {
    DIAS(1..365, "día", "días"), SEMANAS(1..52, "semana", "semanas"), MESES(1..24, "mes", "meses"), ANIOS(1..2, "año", "años");

    /** "días" o "día" según el número. */
    fun title(count: Int) = if (count == 1) one else many
    /** Título del selector: siempre en plural. */
    val title: String get() = many
}

/** Atajos de Otra: Cada 2 meses, Trimestral, Semestral y Anual. */
enum class RepeatPreset(val title: String, val unit: RepeatUnit, val count: Int) {
    BIMESTRAL("Cada 2 meses", RepeatUnit.MESES, 2), TRIMESTRAL("Trimestral", RepeatUnit.MESES, 3), SEMESTRAL("Semestral", RepeatUnit.MESES, 6),
    ANUAL("Anual", RepeatUnit.ANIOS, 1)
}

/** Lo que la persona eligió en "¿Se repite?" y el ciclo que resulta. Una sola fuente para Agregar y editar pago fijo (igual que iOS). */
data class RepeatDraft(
    val choice: RepeatChoice = RepeatChoice.UNA_VEZ,
    val quincena: QuincenaDays = QuincenaDays.STANDARD,
    /** Otra: "Cada [N] [unidad]". El número va como texto porque se escribe con el teclado. */
    val unit: RepeatUnit = RepeatUnit.MESES,
    val countText: String = "2",
) {
    /** El número escrito en Otra. Null si está vacío. */
    val count: Int? get() = countText.filter(Char::isDigit).take(4).toIntOrNull()

    /** Otra con un número dentro del rango de su unidad (lo demás siempre sirve). */
    val isValid: Boolean get() = choice != RepeatChoice.OTRA || count?.let { it in unit.range } == true

    /** "Escribe de 1 a 24 meses" cuando el número no sirve. */
    val hint: String? get() = if (choice == RepeatChoice.OTRA && !isValid) "Escribe de ${unit.range.first} a ${unit.range.last} ${unit.title}" else null

    /** Quien escribe cada 15 días casi siempre quiere la quincena. */
    val tip: String? get() = if (choice == RepeatChoice.OTRA && unit == RepeatUnit.DIAS && count == 15) "¿Quincenal? Usa Quincenal para 15 y 30" else null

    /** El ciclo que se guarda. Con un número fuera de rango usa el más cercano (Guardar espera a que sea válido). */
    val cycle: Cycle get() = when (choice) {
        RepeatChoice.UNA_VEZ -> Cycle.Puntual
        RepeatChoice.SEMANAL -> Cycle.Semanal
        RepeatChoice.QUINCENAL -> Cycle.Quincenal(quincena)
        RepeatChoice.MENSUAL -> Cycle.Mensual
        RepeatChoice.OTRA -> {
            val n = (count ?: unit.range.first).coerceIn(unit.range)
            when (unit) {
                RepeatUnit.DIAS -> if (n == 7) Cycle.Semanal else Cycle.CadaDias(n)
                RepeatUnit.SEMANAS -> if (n == 1) Cycle.Semanal else Cycle.CadaDias(7 * n)
                RepeatUnit.MESES -> Cycle.months(n)
                RepeatUnit.ANIOS -> if (n == 1) Cycle.Anual else Cycle.CadaMeses(24)
            }
        }
    }

    /** El atajo que corresponde a lo escrito, si hay. */
    val preset: RepeatPreset? get() = if (choice != RepeatChoice.OTRA) null else RepeatPreset.entries.firstOrNull { it.unit == unit && it.count == count }

    fun apply(preset: RepeatPreset) = copy(choice = RepeatChoice.OTRA, unit = preset.unit, countText = "${preset.count}")

    /** Lo que dice la fila plegada: "Mensual", "Quincenal", "Trimestral", "Cada 10 días", "Cada 2 años". */
    val title: String get() = when {
        choice != RepeatChoice.OTRA -> choice.title
        isValid -> cycle.title
        else -> "Cada ${countText.ifEmpty { "N" }} ${unit.title}"
    }

    /** "cada 3 meses", "cada semana", "cada 2 años". */
    val everyText: String? get() {
        val n = count
        if (choice != RepeatChoice.OTRA || !isValid || n == null) return null
        return if (n == 1) "cada ${unit.title(1)}" else "cada $n ${unit.title(n)}"
    }

    /** "Se repite cada 3 meses, el próximo es el 7 feb". Null si no es Otra o el número no sirve. */
    fun summary(next: LocalDate?, today: LocalDate): String? {
        val every = everyText ?: return null
        return if (next == null) "Se repite $every" else "Se repite $every, el próximo es el ${DueText.shortDate(next, today)}"
    }

    companion object {
        /** El borrador que corresponde a un ciclo guardado (para editar). */
        fun of(cycle: Cycle): RepeatDraft = when (cycle) {
            Cycle.Puntual -> RepeatDraft(RepeatChoice.UNA_VEZ)
            Cycle.Semanal -> RepeatDraft(RepeatChoice.SEMANAL)
            Cycle.Mensual -> RepeatDraft(RepeatChoice.MENSUAL)
            is Cycle.Quincenal -> RepeatDraft(RepeatChoice.QUINCENAL, quincena = cycle.days)
            Cycle.Anual -> RepeatDraft(RepeatChoice.OTRA, unit = RepeatUnit.ANIOS, countText = "1")
            is Cycle.CadaMeses -> if (cycle.months == 24) RepeatDraft(RepeatChoice.OTRA, unit = RepeatUnit.ANIOS, countText = "2")
                else RepeatDraft(RepeatChoice.OTRA, unit = RepeatUnit.MESES, countText = "${cycle.months}")
            is Cycle.CadaDias -> if (cycle.days % 7 == 0 && cycle.days >= 14 && cycle.days / 7 in RepeatUnit.SEMANAS.range)
                RepeatDraft(RepeatChoice.OTRA, unit = RepeatUnit.SEMANAS, countText = "${cycle.days / 7}")
                else RepeatDraft(RepeatChoice.OTRA, unit = RepeatUnit.DIAS, countText = "${cycle.days}")
        }
    }
}
