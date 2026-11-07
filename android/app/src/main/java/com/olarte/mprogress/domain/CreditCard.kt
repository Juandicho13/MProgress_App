package com.olarte.mprogress.domain

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit
import java.util.UUID

// Tarjetas de crédito a la colombiana: corte, fecha de pago, cuotas, avances, mínimo, pago total, cupo
// disponible, pagos parciales y simuladores. Igual a ios/MProgress/Domain/CreditCard.swift.
// La especificación ejecutable con los números de las pruebas es src/test/vectors/credit_card_vectors.py.
//
// Reglas:
// - Montos en unidades mínimas. Cada línea (capital o interés) se redondea a la unidad que se ve (pesos
//   enteros en COP) con mitad hacia arriba, solo al final de su cálculo.
// - Tasa mensual = (1 + EA/100)^(1/12) - 1, con Newton en BigDecimal, redondeada a 20 decimales.
// - Una compra hasta el día de corte (incluido) va en el extracto que corta ese mes; después, en el siguiente.
//   Un corte 29, 30 o 31 cae el último día en los meses cortos.
// - Fecha de pago: el primer día de pago después del corte (mismo mes si cae después, si no el siguiente).
// - Capital fijo (por defecto): capital = saldo / cuotas que faltan (la última lleva el resto) e interés =
//   saldo pendiente x tasa mensual; en el primer extracto, proporcional a los días desde la compra al corte.
// - Cuota fija (francés): cuota = R*i*q / (q - 1), q = (1 + i)^m.
// - Compra a 1 cuota sin intereses si la tarjeta lo permite. Avance: intereses desde el día uno y comisión.
// - Un pago cubre primero lo que falta del extracto; el excedente baja capital: avances, luego el saldo con
//   más intereses por delante, luego el más viejo. Si sobra, queda saldo a favor.
// - Lo que falta del mínimo al siguiente corte pasa como pendiente con mora ESTIMADA (misma tasa).

/** Compra normal o avance. */
enum class CardChargeKind { COMPRA, AVANCE }

/** Cómo reparte el banco cada cuota. */
enum class InstallmentMethod {
    /** Capital igual más intereses sobre el saldo (lo normal en Colombia). */
    CAPITAL_FIJO,
    /** Cuota total igual (francés). */
    CUOTA_FIJA,
}

/** Condiciones de una tarjeta. `rateEA` en porcentaje (28.34), como `Product.rateEA`. */
data class CardTerms(
    val limitMinor: Long,
    val cutDay: Int,
    val dueDay: Int,
    val rateEA: BigDecimal,
    val handlingFeeMinor: Long = 0,
    val oneInstallmentFree: Boolean = true,
    val advanceFeeMinor: Long = 0,
    val method: InstallmentMethod = InstallmentMethod.CAPITAL_FIJO,
    val currency: Currency = Currency.COP,
)

data class CardPurchase(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val amountMinor: Long,
    val day: LocalDate,
    /** De 1 a 48. */
    val installments: Int = 1,
    val kind: CardChargeKind = CardChargeKind.COMPRA,
)

data class CardPayment(val id: String = UUID.randomUUID().toString(), val amountMinor: Long, val day: LocalDate)

data class CardStatementLine(
    val purchaseId: String,
    val name: String,
    val kind: CardChargeKind,
    val installment: Int,
    val installments: Int,
    val capitalMinor: Long,
    val interestMinor: Long,
    /** Capital que queda para las cuotas siguientes. */
    val remainingAfterMinor: Long,
) { val cuotaMinor get() = capitalMinor + interestMinor }

data class CardStatement(
    val cut: LocalDate,
    val due: LocalDate,
    val periodStart: LocalDate,
    val lines: List<CardStatementLine>,
    val handlingFeeMinor: Long,
    val advanceFeesMinor: Long,
    /** Lo que faltó del mínimo del extracto anterior. */
    val overdueMinor: Long,
    /** Interés de mora ESTIMADO sobre lo que faltó. */
    val moraEstimateMinor: Long,
    val creditAppliedMinor: Long,
    val minimumMinor: Long,
    val totalMinor: Long,
) {
    val interestMinor get() = lines.sumOf { it.interestMinor }
    val capitalMinor get() = lines.sumOf { it.capitalMinor }
}

/** Saldo de una compra dentro de la tarjeta. */
data class CardBalance(
    val seq: Int,
    val purchaseId: String,
    val name: String,
    val kind: CardChargeKind,
    val installments: Int,
    var billed: Int,
    val day: LocalDate,
    val amountMinor: Long,
    var remainingMinor: Long,
)

/** Estado de la tarjeta en un momento. */
class CardState(
    val balances: MutableList<CardBalance> = mutableListOf(),
    /** Lo que falta pagar del último extracto. */
    var dueUnpaidMinor: Long = 0,
    /** Saldo a favor. */
    var creditMinor: Long = 0,
    var pendingAdvanceFeesMinor: Long = 0,
    var nextSeq: Int = 0,
) {
    val futureCapitalMinor get() = balances.sumOf { it.remainingMinor }
    /** Todo lo que se debe (negativo si hay saldo a favor). */
    val debtMinor get() = futureCapitalMinor + dueUnpaidMinor - creditMinor
    fun copy() = CardState(balances.map { it.copy() }.toMutableList(), dueUnpaidMinor, creditMinor, pendingAdvanceFeesMinor, nextSeq)
}

class CardLedger(
    val statements: List<CardStatement>,
    /** Lo pagado a cada extracto (pagos entre su corte y el siguiente). */
    val paidMinor: List<Long>,
    val state: CardState,
) {
    val debtMinor get() = state.debtMinor
    val lastStatement get() = statements.lastOrNull()
    val paidToLastMinor get() = paidMinor.lastOrNull() ?: 0L
}

sealed interface CardPaymentStatus {
    data object Total : CardPaymentStatus
    data object Minimo : CardPaymentStatus
    data class Pendiente(val missingMinor: Long) : CardPaymentStatus
    data class Incompleto(val missingMinor: Long, val moraEstimateMinor: Long) : CardPaymentStatus
}

data class CardPayoff(
    val feasible: Boolean,
    val months: Int,
    /** Intereses de los extractos que faltan (sin cuota de manejo). */
    val interestMinor: Long,
    val paidMinor: Long,
    val lastPaymentDay: LocalDate?,
    val requiredMinimumMinor: Long,
)

data class CardScheduleRow(
    val cut: LocalDate,
    val due: LocalDate,
    val installment: Int,
    val installments: Int,
    val capitalMinor: Long,
    val interestMinor: Long,
) { val cuotaMinor get() = capitalMinor + interestMinor }

data class CardPurchaseCost(val interestMinor: Long, val advanceFeesMinor: Long, val schedule: List<CardScheduleRow>) {
    val months get() = schedule.size
}

object CreditCardMath {
    const val MAX_INSTALLMENTS = 48
    private val MC = MathContext.DECIMAL128
    private val EPS = BigDecimal("1e-30")

    // Tasa y redondeo

    /** (1 + EA/100)^(1/12) - 1 a 20 decimales. */
    fun monthlyRate(rateEA: BigDecimal): BigDecimal {
        if (rateEA.signum() <= 0) return BigDecimal.ZERO
        val a = BigDecimal.ONE.add(rateEA.divide(BigDecimal(100), MC), MC)
        var x = BigDecimal.ONE.add(rateEA.divide(BigDecimal(1200), MC), MC)
        repeat(60) {
            val next = x.subtract(x.pow(12, MC).subtract(a, MC).divide(BigDecimal(12).multiply(x.pow(11, MC), MC), MC), MC)
            val delta = next.subtract(x, MC).abs()
            x = next
            if (delta < EPS) return x.subtract(BigDecimal.ONE, MC).setScale(20, RoundingMode.HALF_UP)
        }
        return x.subtract(BigDecimal.ONE, MC).setScale(20, RoundingMode.HALF_UP)
    }

    /** Unidad de redondeo: 100 en COP (no muestra centavos). */
    fun roundingUnit(currency: Currency): Long = pow10(maxOf(0, currency.minorDigits - currency.shownDigits))

    fun roundToUnit(value: BigDecimal, unit: Long): Long =
        value.divide(BigDecimal(unit), MC).setScale(0, RoundingMode.HALF_UP).longValueExact() * unit

    // Fechas

    private fun clamp(ym: YearMonth, day: Int): LocalDate = ym.atDay(day.coerceIn(1, ym.lengthOfMonth()))

    fun cut(year: Int, month: Int, cutDay: Int): LocalDate = clamp(YearMonth.of(year, month), cutDay)

    fun statementCut(day: LocalDate, cutDay: Int): LocalDate {
        val ym = YearMonth.from(day)
        val thisMonth = clamp(ym, cutDay)
        return if (!day.isAfter(thisMonth)) thisMonth else clamp(ym.plusMonths(1), cutDay)
    }

    fun nextCut(cut: LocalDate, cutDay: Int): LocalDate = clamp(YearMonth.from(cut).plusMonths(1), cutDay)

    fun previousCut(cut: LocalDate, cutDay: Int): LocalDate = clamp(YearMonth.from(cut).minusMonths(1), cutDay)

    fun dueDate(cut: LocalDate, dueDay: Int): LocalDate {
        val ym = YearMonth.from(cut)
        val sameMonth = clamp(ym, dueDay)
        return if (sameMonth.isAfter(cut)) sameMonth else clamp(ym.plusMonths(1), dueDay)
    }

    private fun days(from: LocalDate, to: LocalDate) = ChronoUnit.DAYS.between(from, to)

    // Motor

    private fun isFree(b: CardBalance, t: CardTerms) = b.kind == CardChargeKind.COMPRA && b.installments == 1 && t.oneInstallmentFree

    private fun prepayOrder(state: CardState, t: CardTerms, rate: BigDecimal): List<CardBalance> {
        fun weight(b: CardBalance): Long {
            val bearing = !isFree(b, t) && rate.signum() > 0
            val left = maxOf(1, b.installments - b.billed).toLong()
            return if (bearing) b.remainingMinor * (left + 1) else 0
        }
        return state.balances.filter { it.remainingMinor > 0 }.sortedWith(
            compareBy<CardBalance> { if (it.kind == CardChargeKind.AVANCE) 0 else 1 }
                .thenByDescending { weight(it) }
                .thenBy { it.day }
                .thenBy { it.seq }
        )
    }

    private fun prepay(state: CardState, amount: Long, t: CardTerms, rate: BigDecimal): Long {
        var left = amount
        for (b in prepayOrder(state, t, rate)) {
            if (left <= 0) break
            val used = minOf(left, b.remainingMinor)
            b.remainingMinor -= used
            left -= used
        }
        return left
    }

    private fun add(p: CardPurchase, state: CardState, t: CardTerms) {
        val count = p.installments.coerceIn(1, MAX_INSTALLMENTS)
        state.balances.add(CardBalance(state.nextSeq, p.id, p.name, p.kind, count, 0, p.day, p.amountMinor, p.amountMinor))
        state.nextSeq += 1
        if (p.kind == CardChargeKind.AVANCE) state.pendingAdvanceFeesMinor += t.advanceFeeMinor
    }

    /** Aplica un pago: primero lo que falta del extracto, luego capital, y lo que sobra queda a favor. */
    fun applyPayment(amount: Long, state: CardState, t: CardTerms) {
        val rate = monthlyRate(t.rateEA)
        val toDue = minOf(amount, state.dueUnpaidMinor)
        state.dueUnpaidMinor -= toDue
        state.creditMinor += prepay(state, amount - toDue, t, rate)
    }

    /** Genera el extracto que corta en `cut` y deja el estado listo para recibir pagos. */
    fun bill(state: CardState, cut: LocalDate, t: CardTerms): CardStatement {
        val rate = monthlyRate(t.rateEA)
        val unit = roundingUnit(t.currency)
        val previous = previousCut(cut, t.cutDay)
        val periodDays = maxOf(1L, days(previous, cut))
        val overdue = state.dueUnpaidMinor
        val mora = if (overdue > 0) roundToUnit(BigDecimal(overdue).multiply(rate, MC), unit) else 0L
        val lines = mutableListOf<CardStatementLine>()
        for (b in state.balances) {
            if (b.remainingMinor <= 0) continue
            val left = maxOf(1, b.installments - b.billed)
            val free = isFree(b, t)
            val remaining = BigDecimal(b.remainingMinor)
            val capital = when {
                left <= 1 -> b.remainingMinor
                t.method == InstallmentMethod.CUOTA_FIJA && !free && rate.signum() > 0 -> {
                    val q = BigDecimal.ONE.add(rate, MC).pow(left, MC)
                    val cuota = roundToUnit(remaining.multiply(rate, MC).multiply(q, MC).divide(q.subtract(BigDecimal.ONE, MC), MC), unit)
                    maxOf(0L, minOf(b.remainingMinor, cuota - roundToUnit(remaining.multiply(rate, MC), unit)))
                }
                else -> roundToUnit(remaining.divide(BigDecimal(left), MC), unit)
            }
            val interest = when {
                free -> 0L
                b.billed == 0 -> roundToUnit(remaining.multiply(rate, MC).multiply(BigDecimal(days(b.day, cut)), MC).divide(BigDecimal(periodDays), MC), unit)
                else -> roundToUnit(remaining.multiply(rate, MC), unit)
            }
            val k = b.billed + 1
            b.remainingMinor -= capital
            b.billed += 1
            lines.add(CardStatementLine(b.purchaseId, b.name, b.kind, k, b.installments, capital, interest, b.remainingMinor))
        }
        val advanceFees = state.pendingAdvanceFeesMinor
        state.pendingAdvanceFeesMinor = 0
        var due = lines.sumOf { it.capitalMinor + it.interestMinor } + t.handlingFeeMinor + advanceFees + overdue + mora
        val used = minOf(state.creditMinor, due)
        due -= used
        state.creditMinor -= used
        if (state.creditMinor > 0) state.creditMinor = prepay(state, state.creditMinor, t, rate)
        state.dueUnpaidMinor = due
        return CardStatement(cut, dueDate(cut, t.dueDay), previous.plusDays(1), lines, t.handlingFeeMinor, advanceFees,
            overdue, mora, used, due, due + state.futureCapitalMinor)
    }

    private data class Event(val day: LocalDate, val order: Int, val index: Int, val purchase: CardPurchase?, val payment: CardPayment?)

    /** Recorre compras, pagos y cortes hasta `through` (incluido). El mismo día: compras, pagos y al final el corte. */
    fun ledger(t: CardTerms, purchases: List<CardPurchase>, payments: List<CardPayment>, through: LocalDate): CardLedger {
        val events = (purchases.mapIndexed { i, p -> Event(p.day, 0, i, p, null) } + payments.mapIndexed { i, p -> Event(p.day, 1, i, null, p) })
            .sortedWith(compareBy<Event> { it.day }.thenBy { it.order }.thenBy { it.index })
        val state = CardState()
        val statements = mutableListOf<CardStatement>()
        val paid = mutableListOf<Long>()
        if (events.isEmpty()) return CardLedger(statements, paid, state)
        var cursor = 0
        fun process(limit: LocalDate) {
            while (cursor < events.size && !events[cursor].day.isAfter(limit)) {
                val e = events[cursor]
                e.purchase?.let { add(it, state, t) }
                e.payment?.let {
                    applyPayment(it.amountMinor, state, t)
                    if (paid.isNotEmpty()) paid[paid.size - 1] += it.amountMinor
                }
                cursor += 1
            }
        }
        var cut = statementCut(events.first().day, t.cutDay)
        var guard = 0
        while (!cut.isAfter(through) && guard < 1200) {
            process(cut)
            statements.add(bill(state, cut, t))
            paid.add(0)
            cut = nextCut(cut, t.cutDay)
            guard += 1
        }
        process(through)
        return CardLedger(statements, paid, state)
    }

    fun statement(cut: LocalDate, t: CardTerms, purchases: List<CardPurchase>, payments: List<CardPayment>): CardStatement? =
        ledger(t, purchases, payments, cut).statements.lastOrNull { it.cut == cut }

    /** Próximo extracto visto desde hoy, con lo registrado hasta ahora. */
    fun upcomingStatement(today: LocalDate, t: CardTerms, purchases: List<CardPurchase>, payments: List<CardPayment>): CardStatement? =
        statement(statementCut(today, t.cutDay), t, purchases.filter { !it.day.isAfter(today) }, payments.filter { !it.day.isAfter(today) })

    /** Cupo menos todo lo que se debe (capital futuro incluido). Negativo si se pasó. */
    fun availableMinor(t: CardTerms, ledger: CardLedger): Long = t.limitMinor - ledger.debtMinor

    fun availableMinor(at: LocalDate, t: CardTerms, purchases: List<CardPurchase>, payments: List<CardPayment>): Long =
        availableMinor(t, ledger(t, purchases, payments, at))

    fun status(statement: CardStatement, paidMinor: Long, today: LocalDate, t: CardTerms): CardPaymentStatus {
        if (paidMinor >= statement.totalMinor) return CardPaymentStatus.Total
        if (paidMinor >= statement.minimumMinor) return CardPaymentStatus.Minimo
        val missing = statement.minimumMinor - paidMinor
        if (!today.isAfter(statement.due)) return CardPaymentStatus.Pendiente(missing)
        val mora = roundToUnit(BigDecimal(missing).multiply(monthlyRate(t.rateEA), MC), roundingUnit(t.currency))
        return CardPaymentStatus.Incompleto(missing, mora)
    }

    // Simuladores

    fun payOnlyMinimum(t: CardTerms, purchases: List<CardPurchase>, payments: List<CardPayment>, today: LocalDate): CardPayoff =
        simulate(t, purchases, payments, today, null)

    fun payFixed(amountMinor: Long, t: CardTerms, purchases: List<CardPurchase>, payments: List<CardPayment>, today: LocalDate): CardPayoff =
        simulate(t, purchases, payments, today, amountMinor)

    private fun simulate(original: CardTerms, purchases: List<CardPurchase>, payments: List<CardPayment>, today: LocalDate,
                         fixedMinor: Long?, maxMonths: Int = 600): CardPayoff {
        val t = original.copy(handlingFeeMinor = 0)
        val base = ledger(t, purchases, payments, today)
        val state = base.state
        var months = 0
        var interest = 0L
        var paidTotal = 0L
        var lastDay: LocalDate? = null
        var cut = base.lastStatement?.let { nextCut(it.cut, t.cutDay) } ?: statementCut(today, t.cutDay)

        fun pay(minimum: Long, day: LocalDate): Boolean {
            val amount = if (fixedMinor != null) {
                if (fixedMinor < minimum) return false
                minOf(fixedMinor, state.debtMinor)
            } else state.dueUnpaidMinor
            if (amount > 0) {
                applyPayment(amount, state, t)
                months += 1
                paidTotal += amount
                lastDay = day
            }
            return true
        }

        val last = base.lastStatement
        if (last != null && state.dueUnpaidMinor > 0) {
            val minimum = state.dueUnpaidMinor
            if (!pay(minimum, if (last.due.isAfter(today)) last.due else today)) return CardPayoff(false, 0, 0, 0, null, minimum)
        }
        for (i in 0 until maxMonths) {
            if (state.debtMinor <= 0) break
            val s = bill(state, cut, t)
            interest += s.interestMinor + s.moraEstimateMinor
            if (!pay(s.minimumMinor, s.due)) return CardPayoff(false, 0, 0, 0, null, s.minimumMinor)
            cut = nextCut(cut, t.cutDay)
        }
        return CardPayoff(true, months, interest, paidTotal, lastDay, 0)
    }

    /** Plan de cuotas y costo de una compra sola pagando el mínimo. */
    fun purchaseCost(amountMinor: Long, installments: Int, kind: CardChargeKind = CardChargeKind.COMPRA, day: LocalDate, terms: CardTerms): CardPurchaseCost {
        val t = terms.copy(handlingFeeMinor = 0)
        val state = CardState()
        add(CardPurchase(name = "", amountMinor = amountMinor, day = day, installments = installments, kind = kind), state, t)
        var cut = statementCut(day, t.cutDay)
        val rows = mutableListOf<CardScheduleRow>()
        var interest = 0L
        var fees = 0L
        repeat(MAX_INSTALLMENTS + 12) {
            if (state.futureCapitalMinor <= 0) return CardPurchaseCost(interest, fees, rows)
            val s = bill(state, cut, t)
            fees += s.advanceFeesMinor
            for (l in s.lines) {
                interest += l.interestMinor
                rows.add(CardScheduleRow(cut, s.due, l.installment, l.installments, l.capitalMinor, l.interestMinor))
            }
            applyPayment(state.dueUnpaidMinor, state, t)
            cut = nextCut(cut, t.cutDay)
        }
        return CardPurchaseCost(interest, fees, rows)
    }

    /** Condiciones desde un producto. Sin corte usa 30, sin día de pago 15 días después y sin tasa `defaultRateEA`. */
    fun terms(limitMinor: Long?, cutDay: Int?, dueDay: Int?, rateEA: BigDecimal?, defaultRateEA: BigDecimal,
              handlingFeeMinor: Long? = null, oneInstallmentFree: Boolean? = null, currency: Currency = Currency.COP): CardTerms {
        val cut = (cutDay ?: 30).coerceIn(1, 31)
        val due = (dueDay ?: ((cut + 14) % 31 + 1)).coerceIn(1, 31)
        return CardTerms(maxOf(0L, limitMinor ?: 0L), cut, due, rateEA ?: defaultRateEA, maxOf(0L, handlingFeeMinor ?: 0L),
            oneInstallmentFree ?: true, currency = currency)
    }
}

/** Textos en español para las pantallas de tarjeta. */
object CreditCardText {
    val months = listOf("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")

    fun dayMonth(day: LocalDate) = "${day.dayOfMonth} ${months[day.monthValue - 1]}"

    private fun money(minor: Long, currency: Currency) = Money(minor, currency).formatted()

    fun payTotal(s: CardStatement, currency: Currency = Currency.COP): String {
        if (s.totalMinor <= 0) return "No debes nada de este extracto"
        val tail = if (s.interestMinor > 0 || s.overdueMinor > 0) "para no pagar más intereses" else "para no pagar intereses"
        return "Paga ${money(s.totalMinor, currency)} antes del ${dayMonth(s.due)} $tail"
    }

    fun minimum(s: CardStatement, currency: Currency = Currency.COP) = "Mínimo ${money(s.minimumMinor, currency)}"

    fun available(availableMinor: Long, currency: Currency = Currency.COP) = when {
        availableMinor > 0 -> "Te quedan ${money(availableMinor, currency)} de cupo"
        availableMinor == 0L -> "No te queda cupo"
        else -> "Te pasaste ${money(-availableMinor, currency)} del cupo"
    }

    fun installment(line: CardStatementLine) = if (line.installments <= 1) "1 cuota" else "Cuota ${line.installment} de ${line.installments}"

    fun purchaseCost(cost: CardPurchaseCost, installments: Int, kind: CardChargeKind = CardChargeKind.COMPRA, currency: Currency = Currency.COP): String {
        val what = if (kind == CardChargeKind.AVANCE) "Este avance" else "Esta compra"
        val plan = if (installments <= 1) "a 1 cuota" else "a $installments cuotas"
        val fee = if (cost.advanceFeesMinor > 0) money(cost.advanceFeesMinor, currency) + " de comisión" else null
        if (cost.interestMinor <= 0) {
            if (kind == CardChargeKind.COMPRA && installments <= 1) return "A 1 cuota no pagas intereses"
            return "$what $plan no te cobra intereses" + (fee?.let { ", solo $it" } ?: "")
        }
        return "$what $plan te cuesta ${money(cost.interestMinor, currency)} de intereses" + (fee?.let { " y $it" } ?: "")
    }

    private fun monthsText(n: Int) = if (n == 1) "1 mes" else "$n meses"

    fun onlyMinimum(p: CardPayoff, currency: Currency = Currency.COP): String {
        if (p.months == 0) return "No tienes deuda en esta tarjeta"
        return "Si pagas solo el mínimo terminas en ${monthsText(p.months)} y pagas ${money(p.interestMinor, currency)} de intereses"
    }

    fun fixedPayment(amountMinor: Long, p: CardPayoff, currency: Currency = Currency.COP): String {
        if (!p.feasible) return "Con ${money(amountMinor, currency)} al mes no alcanzas el mínimo de ${money(p.requiredMinimumMinor, currency)}"
        if (p.months == 0) return "No tienes deuda en esta tarjeta"
        return "Si pagas ${money(amountMinor, currency)} al mes terminas en ${monthsText(p.months)} y pagas ${money(p.interestMinor, currency)} de intereses"
    }

    fun status(s: CardPaymentStatus, currency: Currency = Currency.COP): String = when (s) {
        CardPaymentStatus.Total -> "Pagaste el total"
        CardPaymentStatus.Minimo -> "Pagaste el mínimo"
        is CardPaymentStatus.Pendiente -> "Te faltan ${money(s.missingMinor, currency)} para el mínimo"
        is CardPaymentStatus.Incompleto ->
            "Pago incompleto: faltaron ${money(s.missingMinor, currency)} del mínimo · mora estimada ${money(s.moraEstimateMinor, currency)}"
    }

    /** "28,34 % E.A.". */
    fun rate(rateEA: BigDecimal): String =
        rateEA.setScale(2, RoundingMode.HALF_UP).stripTrailingZeros().toPlainString().replace('.', ',') + " % E.A."
}
