package com.olarte.mprogress.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal
import java.time.LocalDate

/** Mismos números que CreditCardTests.swift; salen de src/test/vectors/credit_card_vectors.py. */
class CreditCardTest {
    private fun d(y: Int, m: Int, day: Int) = LocalDate.of(y, m, day)

    /** Cupo 5.000.000, corte 30, pago 15, 28,34 % E.A. */
    private val base = CardTerms(limitMinor = 500_000_000, cutDay = 30, dueDay = 15, rateEA = BigDecimal("28.34"))
    /** Con cuota de manejo de 32.900 y comisión por avance de 9.900. */
    private val conCuota = base.copy(handlingFeeMinor = 3_290_000, advanceFeeMinor = 990_000)

    private val compras = listOf(
        CardPurchase(name = "Mercado", amountMinor = 42_000_000, day = d(2026, 11, 2)),
        CardPurchase(name = "Celular", amountMinor = 240_000_000, day = d(2026, 11, 5), installments = 24),
        CardPurchase(name = "Tiquetes", amountMinor = 90_000_000, day = d(2026, 11, 12), installments = 6),
        CardPurchase(name = "Avance", amountMinor = 30_000_000, day = d(2026, 11, 20), installments = 2, kind = CardChargeKind.AVANCE),
        CardPurchase(name = "Cine", amountMinor = 8_500_000, day = d(2026, 11, 30)),
        CardPurchase(name = "Despues del corte", amountMinor = 5_000_000, day = d(2026, 12, 1)),
    )

    private fun lineas(s: CardStatement) = s.lines.map { listOf(it.installment.toLong(), it.installments.toLong(), it.capitalMinor, it.interestMinor, it.remainingAfterMinor) }

    @Test fun tasaMensual() {
        assertEquals(BigDecimal("0.02101040881997040579"), CreditCardMath.monthlyRate(BigDecimal("28.34")))
        assertEquals(BigDecimal("0.01833356684882571336"), CreditCardMath.monthlyRate(BigDecimal("24.36")))
        assertEquals(BigDecimal("0.05946309435929526456"), CreditCardMath.monthlyRate(BigDecimal("100")))
        assertEquals(BigDecimal("0.00948879293458297413"), CreditCardMath.monthlyRate(BigDecimal("12")))
        assertEquals(0, CreditCardMath.monthlyRate(BigDecimal.ZERO).signum())
        assertEquals(100L, CreditCardMath.roundingUnit(Currency.COP))
        assertEquals(1L, CreditCardMath.roundingUnit(Currency.USD))
        assertEquals(840_400L, CreditCardMath.roundToUnit(BigDecimal("840449.99"), 100))
        assertEquals(840_500L, CreditCardMath.roundToUnit(BigDecimal(840_450), 100))
    }

    @Test fun corteMesCorto() {
        assertEquals(d(2026, 2, 28), CreditCardMath.cut(2026, 2, 31))
        assertEquals(d(2028, 2, 29), CreditCardMath.cut(2028, 2, 31))
        assertEquals(d(2026, 4, 30), CreditCardMath.cut(2026, 4, 31))
        assertEquals(d(2027, 2, 28), CreditCardMath.nextCut(d(2027, 1, 31), 31))
        assertEquals(d(2027, 3, 31), CreditCardMath.nextCut(d(2027, 2, 28), 31))
        assertEquals(d(2026, 2, 28), CreditCardMath.previousCut(d(2026, 3, 30), 30))
    }

    @Test fun extractoDeLaCompra() {
        assertEquals(d(2026, 11, 30), CreditCardMath.statementCut(d(2026, 11, 30), 30))
        assertEquals(d(2026, 12, 30), CreditCardMath.statementCut(d(2026, 12, 1), 30))
        assertEquals(d(2027, 2, 28), CreditCardMath.statementCut(d(2027, 1, 31), 30))
        assertEquals(d(2027, 2, 28), CreditCardMath.statementCut(d(2027, 2, 28), 30))
        assertEquals(d(2027, 1, 15), CreditCardMath.statementCut(d(2026, 12, 31), 15))
    }

    @Test fun fechaDePago() {
        assertEquals(d(2026, 12, 15), CreditCardMath.dueDate(d(2026, 11, 30), 15))
        assertEquals(d(2026, 11, 28), CreditCardMath.dueDate(d(2026, 11, 10), 28))
        assertEquals(d(2027, 2, 28), CreditCardMath.dueDate(d(2027, 1, 31), 30))
        assertEquals(d(2026, 12, 15), CreditCardMath.dueDate(d(2026, 11, 15), 15))
    }

    @Test fun doceCuotas() {
        val cost = CreditCardMath.purchaseCost(120_000_000, 12, day = d(2026, 10, 20), terms = base)
        assertEquals(listOf<Long>(840_400L, 2_311_100, 2_101_000, 1_890_900, 1_680_800, 1_470_700, 1_260_600, 1_050_500, 840_400, 630_300, 420_200, 210_100),
            cost.schedule.map { it.interestMinor })
        assertTrue(cost.schedule.all { it.capitalMinor == 10_000_000L })
        assertEquals((1..12).toList(), cost.schedule.map { it.installment })
        assertEquals(d(2026, 10, 30), cost.schedule.first().cut)
        assertEquals(d(2026, 11, 15), cost.schedule.first().due)
        assertEquals(d(2027, 2, 28), cost.schedule[4].cut)
        assertEquals(d(2027, 9, 30), cost.schedule.last().cut)
        assertEquals(14_707_000L, cost.interestMinor)
        assertEquals(12, cost.months)
        assertEquals("Esta compra a 12 cuotas te cuesta $ 147.070 de intereses", CreditCardText.purchaseCost(cost, 12))
    }

    @Test fun cuotaFija() {
        val cost = CreditCardMath.purchaseCost(120_000_000, 12, day = d(2026, 10, 20), terms = base.copy(method = InstallmentMethod.CUOTA_FIJA))
        assertEquals(listOf<Long>(8_896_500L, 9_083_400, 9_274_200, 9_469_100, 9_668_000, 9_871_100, 10_078_500, 10_290_300, 10_506_400, 10_727_200, 10_952_600, 11_182_700),
            cost.schedule.map { it.capitalMinor })
        assertEquals(listOf<Long>(840_400L, 2_334_300, 2_143_500, 1_948_600, 1_749_700, 1_546_600, 1_339_200, 1_127_400, 911_200, 690_500, 465_100, 235_000),
            cost.schedule.map { it.interestMinor })
        assertEquals(120_000_000L, cost.schedule.sumOf { it.capitalMinor })
        assertEquals(15_331_500L, cost.interestMinor)
    }

    @Test fun unaCuota() {
        val free = CreditCardMath.purchaseCost(35_000_000, 1, day = d(2026, 11, 3), terms = base)
        assertEquals(0L, free.interestMinor)
        assertEquals(listOf<Long>(35_000_000L), free.schedule.map { it.capitalMinor })
        assertEquals("A 1 cuota no pagas intereses", CreditCardText.purchaseCost(free, 1))
        val paid = CreditCardMath.purchaseCost(35_000_000, 1, day = d(2026, 11, 3), terms = base.copy(oneInstallmentFree = false))
        assertEquals(640_500L, paid.interestMinor)
        assertEquals("Esta compra a 1 cuota te cuesta $ 6.405 de intereses", CreditCardText.purchaseCost(paid, 1))
        val cero = CreditCardMath.purchaseCost(35_000_000, 6, day = d(2026, 11, 3), terms = base.copy(rateEA = BigDecimal.ZERO))
        assertEquals("Esta compra a 6 cuotas no te cobra intereses", CreditCardText.purchaseCost(cero, 6))
    }

    @Test fun avance() {
        val t = base.copy(advanceFeeMinor = 990_000)
        val led = CreditCardMath.ledger(t, listOf(CardPurchase(name = "Avance", amountMinor = 50_000_000, day = d(2026, 11, 10), kind = CardChargeKind.AVANCE)),
            emptyList(), d(2026, 11, 30))
        val s = led.lastStatement!!
        assertEquals(677_800L, s.interestMinor)
        assertEquals(990_000L, s.advanceFeesMinor)
        assertEquals(51_667_800L, s.minimumMinor)
        assertEquals(51_667_800L, s.totalMinor)
        val tres = CreditCardMath.purchaseCost(50_000_000, 3, CardChargeKind.AVANCE, d(2026, 11, 10), t)
        assertEquals(listOf<Long>(16_666_700L, 16_666_700, 16_666_600), tres.schedule.map { it.capitalMinor })
        assertEquals(listOf<Long>(677_800L, 700_300, 350_200), tres.schedule.map { it.interestMinor })
        assertEquals(1_728_300L, tres.interestMinor)
        assertEquals(990_000L, tres.advanceFeesMinor)
        assertEquals("Este avance a 3 cuotas te cuesta $ 17.283 de intereses y $ 9.900 de comisión", CreditCardText.purchaseCost(tres, 3, CardChargeKind.AVANCE))
    }

    @Test fun extracto() {
        val s = CreditCardMath.statement(d(2026, 11, 30), conCuota, compras, emptyList())!!
        assertEquals(listOf("Mercado", "Celular", "Tiquetes", "Avance", "Cine"), s.lines.map { it.name })
        assertEquals(listOf(listOf<Long>(1L, 1, 42_000_000, 0, 0), listOf<Long>(1L, 24, 10_000_000, 4_066_500, 230_000_000),
            listOf<Long>(1L, 6, 15_000_000, 1_098_000, 75_000_000), listOf<Long>(1L, 2, 15_000_000, 203_300, 15_000_000),
            listOf<Long>(1L, 1, 8_500_000, 0, 0)), lineas(s))
        assertEquals(3_290_000L, s.handlingFeeMinor)
        assertEquals(990_000L, s.advanceFeesMinor)
        assertEquals(5_367_800L, s.interestMinor)
        assertEquals(100_147_800L, s.minimumMinor)
        assertEquals(420_147_800L, s.totalMinor)
        assertEquals(d(2026, 12, 15), s.due)
        assertEquals(d(2026, 10, 31), s.periodStart)
        assertEquals("Mínimo $ 1.001.478", CreditCardText.minimum(s))
        assertEquals("Paga $ 4.201.478 antes del 15 dic para no pagar más intereses", CreditCardText.payTotal(s))
        assertEquals("Cuota 1 de 24", CreditCardText.installment(s.lines[1]))
        assertEquals("1 cuota", CreditCardText.installment(s.lines[0]))
    }

    @Test fun cupo() {
        assertEquals(79_852_200L, CreditCardMath.availableMinor(d(2026, 11, 30), conCuota, compras, emptyList()))
        assertEquals(74_852_200L, CreditCardMath.availableMinor(d(2026, 12, 3), conCuota, compras, emptyList()))
        assertEquals("Te quedan $ 798.522 de cupo", CreditCardText.available(79_852_200))
        assertEquals("No te queda cupo", CreditCardText.available(0))
        assertEquals("Te pasaste $ 120.000 del cupo", CreditCardText.available(-12_000_000))
        assertEquals(0L, CreditCardMath.ledger(base, emptyList(), emptyList(), d(2026, 11, 30)).debtMinor)
    }

    @Test fun proximo() {
        val s = CreditCardMath.upcomingStatement(d(2026, 11, 20), conCuota, compras, emptyList())!!
        assertEquals(d(2026, 11, 30), s.cut)
        assertEquals(listOf("Mercado", "Celular", "Tiquetes", "Avance"), s.lines.map { it.name })
    }

    @Test fun pagoParcial() {
        val led = CreditCardMath.ledger(conCuota, compras, listOf(CardPayment(amountMinor = 200_000_000, day = d(2026, 12, 10))), d(2026, 12, 30))
        assertEquals(2, led.statements.size)
        assertEquals(200_000_000L, led.paidMinor[0])
        assertEquals(CardPaymentStatus.Minimo, CreditCardMath.status(led.statements[0], led.paidMinor[0], d(2026, 12, 20), conCuota))
        val dic = led.statements[1]
        assertEquals(listOf("Celular", "Tiquetes", "Despues del corte"), dic.lines.map { it.name })
        assertEquals(listOf(listOf<Long>(2L, 24, 6_310_800, 3_049_600, 138_837_000), listOf<Long>(2L, 6, 15_000_000, 1_575_800, 60_000_000), listOf<Long>(1L, 1, 5_000_000, 0, 0)), lineas(dic))
        assertEquals(34_226_200L, dic.minimumMinor)
        assertEquals(233_063_200L, dic.totalMinor)
        assertEquals(4_625_400L, dic.interestMinor)
        assertEquals(233_063_200L, led.debtMinor)
    }

    @Test fun pagoIncompleto() {
        val led = CreditCardMath.ledger(conCuota, compras, listOf(CardPayment(amountMinor = 50_000_000, day = d(2026, 12, 14))), d(2026, 12, 30))
        val nov = led.statements[0]
        assertEquals(CardPaymentStatus.Pendiente(50_147_800), CreditCardMath.status(nov, led.paidMinor[0], d(2026, 12, 10), conCuota))
        val late = CreditCardMath.status(nov, led.paidMinor[0], d(2026, 12, 16), conCuota)
        assertEquals(CardPaymentStatus.Incompleto(50_147_800, 1_053_600), late)
        assertEquals("Pago incompleto: faltaron $ 501.478 del mínimo · mora estimada $ 10.536", CreditCardText.status(late))
        assertEquals("Te faltan $ 501.478 para el mínimo", CreditCardText.status(CardPaymentStatus.Pendiente(50_147_800)))
        val dic = led.statements[1]
        assertEquals(50_147_800L, dic.overdueMinor)
        assertEquals(1_053_600L, dic.moraEstimateMinor)
        assertEquals(listOf(listOf<Long>(2L, 24, 10_000_000, 4_832_400, 220_000_000), listOf<Long>(2L, 6, 15_000_000, 1_575_800, 60_000_000),
            listOf<Long>(2L, 2, 15_000_000, 315_200, 0), listOf<Long>(1L, 1, 5_000_000, 0, 0)), lineas(dic))
        assertEquals(6_723_400L, dic.interestMinor)
        assertEquals(106_214_800L, dic.minimumMinor)
        assertEquals(386_214_800L, dic.totalMinor)
        assertEquals("Paga $ 3.862.148 antes del 15 ene para no pagar más intereses", CreditCardText.payTotal(dic))
    }

    @Test fun pagoTotal() {
        val led = CreditCardMath.ledger(conCuota, compras, listOf(CardPayment(amountMinor = 420_147_800, day = d(2026, 12, 15))), d(2026, 12, 30))
        assertEquals(CardPaymentStatus.Total, CreditCardMath.status(led.statements[0], led.paidMinor[0], d(2026, 12, 20), conCuota))
        val dic = led.statements[1]
        assertEquals(listOf(listOf<Long>(1L, 1, 5_000_000, 0, 0)), lineas(dic))
        assertEquals(8_290_000L, dic.minimumMinor)
        assertEquals(8_290_000L, dic.totalMinor)
        assertEquals(8_290_000L, led.debtMinor)
        assertEquals("Paga $ 82.900 antes del 15 ene para no pagar intereses", CreditCardText.payTotal(dic))
        assertEquals("Pagaste el total", CreditCardText.status(CardPaymentStatus.Total))
        assertEquals("Pagaste el mínimo", CreditCardText.status(CardPaymentStatus.Minimo))
    }

    @Test fun saldoAFavor() {
        val led = CreditCardMath.ledger(conCuota, compras, listOf(CardPayment(amountMinor = 430_147_800, day = d(2026, 12, 15))), d(2026, 12, 30))
        val dic = led.statements[1]
        assertTrue(dic.lines.isEmpty())
        assertEquals(3_290_000L, dic.creditAppliedMinor)
        assertEquals(0L, dic.minimumMinor)
        assertEquals(0L, dic.totalMinor)
        assertEquals(-1_710_000L, led.debtMinor)
        assertEquals("No debes nada de este extracto", CreditCardText.payTotal(dic))
        assertEquals(501_710_000L, CreditCardMath.availableMinor(conCuota, led))
    }

    @Test fun abonoAntes() {
        val led = CreditCardMath.ledger(base, listOf(CardPurchase(name = "TV", amountMinor = 100_000_000, day = d(2026, 11, 1), installments = 10)),
            listOf(CardPayment(amountMinor = 40_000_000, day = d(2026, 11, 15))), d(2026, 11, 30))
        val s = led.lastStatement!!
        assertEquals(listOf(listOf<Long>(1L, 10, 6_000_000, 1_179_300, 54_000_000)), lineas(s))
        assertEquals(7_179_300L, s.minimumMinor)
        assertEquals(61_179_300L, s.totalMinor)
        assertEquals(listOf<Long>(0L), led.paidMinor)
    }

    @Test fun corte31() {
        val t = base.copy(cutDay = 31, dueDay = 20)
        val led = CreditCardMath.ledger(t, listOf(CardPurchase(name = "Bici", amountMinor = 60_000_000, day = d(2027, 1, 31), installments = 3)), emptyList(), d(2027, 4, 30))
        assertEquals(listOf(d(2027, 1, 31), d(2027, 2, 28), d(2027, 3, 31), d(2027, 4, 30)), led.statements.map { it.cut })
        assertEquals(listOf(d(2027, 2, 20), d(2027, 3, 20), d(2027, 4, 20), d(2027, 5, 20)), led.statements.map { it.due })
        assertEquals(listOf<Long>(20_000_000L, 41_260_600, 62_547_700, 63_861_900), led.statements.map { it.minimumMinor })
        assertEquals(listOf<Long>(60_000_000L, 61_260_600, 62_547_700, 63_861_900), led.statements.map { it.totalMinor })
        assertEquals(listOf<Long>(0L, 20_000_000, 41_260_600, 62_547_700), led.statements.map { it.overdueMinor })
        assertEquals(listOf<Long>(0L, 420_200, 866_900, 1_314_200), led.statements.map { it.moraEstimateMinor })
        assertEquals(listOf<Long>(0L, 840_400, 420_200, 0), led.statements.map { it.interestMinor })
    }

    @Test fun simuladores() {
        val hoy = d(2026, 12, 1)
        val minimo = CreditCardMath.payOnlyMinimum(conCuota, compras, emptyList(), hoy)
        assertTrue(minimo.feasible)
        assertEquals(24, minimo.months)
        assertEquals(63_031_300L, minimo.interestMinor)
        assertEquals(484_889_100L, minimo.paidMinor)
        assertEquals(d(2028, 11, 15), minimo.lastPaymentDay)
        assertEquals("Si pagas solo el mínimo terminas en 24 meses y pagas $ 630.313 de intereses", CreditCardText.onlyMinimum(minimo))

        val fijo = CreditCardMath.payFixed(100_000_000, conCuota, compras, emptyList(), hoy)
        assertTrue(fijo.feasible)
        assertEquals(5, fijo.months)
        assertEquals(15_018_400L, fijo.interestMinor)
        assertEquals(436_876_200L, fijo.paidMinor)
        assertEquals(d(2027, 4, 15), fijo.lastPaymentDay)
        assertEquals("Si pagas $ 1.000.000 al mes terminas en 5 meses y pagas $ 150.184 de intereses", CreditCardText.fixedPayment(100_000_000, fijo))

        val poco = CreditCardMath.payFixed(30_000_000, conCuota, compras, emptyList(), hoy)
        assertFalse(poco.feasible)
        assertEquals(96_857_800L, poco.requiredMinimumMinor)
        assertEquals("Con $ 300.000 al mes no alcanzas el mínimo de $ 968.578", CreditCardText.fixedPayment(30_000_000, poco))

        val nada = CreditCardMath.payOnlyMinimum(base, emptyList(), emptyList(), hoy)
        assertEquals(0, nada.months)
        assertEquals("No tienes deuda en esta tarjeta", CreditCardText.onlyMinimum(nada))
    }

    @Test fun condiciones() {
        val usura = BigDecimal("28.34")
        val t = CreditCardMath.terms(null, null, null, null, usura)
        assertEquals(30, t.cutDay)
        assertEquals(14, t.dueDay)
        assertEquals(usura, t.rateEA)
        assertEquals(0L, t.limitMinor)
        assertTrue(t.oneInstallmentFree)
        assertEquals(30, CreditCardMath.terms(1, 15, null, null, usura).dueDay)
        assertEquals(16, CreditCardMath.terms(1, 1, null, null, usura).dueDay)
        val p = CreditCardMath.terms(9, 40, 0, BigDecimal(20), usura, 5, false)
        assertEquals(31, p.cutDay)
        assertEquals(1, p.dueDay)
        assertEquals(BigDecimal(20), p.rateEA)
        assertEquals(5L, p.handlingFeeMinor)
        assertFalse(p.oneInstallmentFree)
    }

    @Test fun textos() {
        assertEquals("15 nov", CreditCardText.dayMonth(d(2026, 11, 15)))
        assertEquals("28,34 % E.A.", CreditCardText.rate(BigDecimal("28.34")))
        assertEquals("24 % E.A.", CreditCardText.rate(BigDecimal(24)))
        val uno = CardPayoff(true, 1, 0, 1, null, 0)
        assertEquals("Si pagas solo el mínimo terminas en 1 mes y pagas $ 0 de intereses", CreditCardText.onlyMinimum(uno))
        assertNotNull(CreditCardText.available(1))
        assertFalse(CreditCardText.status(CardPaymentStatus.Incompleto(1, 1)).contains('\u2014'))
    }
}
