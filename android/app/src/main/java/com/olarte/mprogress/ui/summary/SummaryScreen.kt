package com.olarte.mprogress.ui.summary

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.DueText
import com.olarte.mprogress.domain.EntryKind
import com.olarte.mprogress.domain.EntryRecord
import com.olarte.mprogress.domain.Money
import com.olarte.mprogress.domain.SummaryMath
import com.olarte.mprogress.domain.BalanceCalculator
import com.olarte.mprogress.ui.components.Card
import com.olarte.mprogress.ui.components.Chip
import com.olarte.mprogress.ui.components.T
import com.olarte.mprogress.ui.components.Type
import com.olarte.mprogress.ui.theme.Palette
import com.olarte.mprogress.ui.theme.Spacing
import java.time.LocalDate
import java.time.YearMonth

private val presets = listOf(1 to "Este mes", 3 to "3 meses", 6 to "6 meses", 12 to "12 meses")

private fun money(minor: Long, sign: Boolean = false) = Money(minor).formatted(sign)

/** Resumen (pantalla 10), igual que SummaryView de iOS: periodo, este mes (solo datos reales), ingresos y gastos, cómo va tu gasto, en qué gastas, tu mes normal, el mes que viene y los próximos 3 meses con pagos fijos. */
@Composable
fun SummaryScreen(store: Store, today: LocalDate = LocalDate.now()) {
    val ledger by store.ledger.collectAsState()
    var months by remember { mutableStateOf(12) }
    var categoryId by remember { mutableStateOf<String?>(null) }
    val start = YearMonth.from(today).minusMonths(months - 1L)
    val inPeriod = ledger.entries.filter { !YearMonth.from(it.occurredAt).isBefore(start) && !YearMonth.from(it.occurredAt).isAfter(YearMonth.from(today)) }
    val chipIds = inPeriod.filter { it.kind == EntryKind.GASTO }.mapNotNull { it.categoryId }.distinct().sortedBy { com.olarte.mprogress.domain.Categories.byId(it)?.sort ?: 999 }
    val filtered = if (categoryId == null) ledger.entries else ledger.entries.filter { it.kind == EntryKind.GASTO && it.categoryId == categoryId }
    val visible = inPeriod.filter { categoryId == null || (it.kind == EntryKind.GASTO && it.categoryId == categoryId) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = Spacing.margen).padding(top = Spacing.s4, bottom = 120.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.s5),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T("Resumen", Type.titulo1, modifier = Modifier.weight(1f))
            PeriodMenu(months) { months = it }
        }
        if (chipIds.isNotEmpty()) Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            Chip("Todas", categoryId == null) { categoryId = null }
            chipIds.forEach { id -> Chip(com.olarte.mprogress.domain.Categories.byId(id)?.name ?: "Sin categoría", categoryId == id) { categoryId = if (categoryId == id) null else id } }
        }
        if (ledger.entries.isEmpty()) EmptyCard() else {
            MonthFactsCard(ledger.entries, ledger.recurring.filter { it.active }, today)
            FlowsCard(SummaryMath.flows(filtered, today, months).map { Triple(it.month, it.incomeMinor, it.spentMinor) }, categoryId)
            PaceCard(filtered, today)
            CategoriesCard(visible)
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                val normal = SummaryMath.normalMonth(ledger.entries, today)
                val totals = (1..12).map { off -> val m = YearMonth.from(today).minusMonths(off.toLong())
                    ledger.entries.filter { it.kind == EntryKind.GASTO && YearMonth.from(it.occurredAt) == m }.sumOf { it.amountMinor } }.filter { it > 0 }
                SmallCard("Tu mes normal", normal?.let { money(it) } ?: "Sin datos",
                    normal?.let { n -> "${totals.count { it > n }} de ${totals.size} meses arriba" } ?: "Necesita un mes completo", Modifier.weight(1f))
                val next = today.withDayOfMonth(1).plusMonths(1)
                var count = 0; var expense = 0L
                ledger.recurring.forEach { r -> val c = BalanceCalculator.pendingOccurrences(r, next).size; count += c; if (r.kind == EntryKind.GASTO) expense += c * r.amountMinor }
                SmallCard("El mes que viene", money(expense), if (count == 0) "Nada programado" else "ya previsto en $count ${if (count == 1) "pago" else "pagos"}", Modifier.weight(1f))
            }
            NextMonthsCard(com.olarte.mprogress.domain.Forecast.nextMonths(3, ledger.recurring, today))
        }
    }
}

@Composable
private fun PeriodMenu(months: Int, onPick: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(Modifier.heightIn(min = 36.dp).clip(CircleShape).background(Palette.superficie1).clickable { open = true }.padding(horizontal = Spacing.s4),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
            T(presets.first { it.first == months }.second, Type.etiqueta)
            Icon(Icons.Rounded.KeyboardArrowDown, null, Modifier.size(16.dp), tint = Palette.texto1)
        }
        DropdownMenu(open, { open = false }, containerColor = Palette.superficie2) {
            presets.forEach { (m, title) ->
                DropdownMenuItem({ T(title, Type.cuerpo) }, { onPick(m); open = false },
                    leadingIcon = { if (m == months) Icon(Icons.Rounded.Check, null, Modifier.size(18.dp), tint = Palette.texto1) else Spacer(Modifier.size(18.dp)) })
            }
        }
    }
}

@Composable
private fun LegendDot(color: Color, text: String, textColor: Color = color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.s1)) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        T(text, Type.leyenda, textColor)
    }
}

@Composable
private fun FlowsCard(flows: List<Triple<YearMonth, Long, Long>>, categoryId: String?) {
    val income = flows.sumOf { it.second }; val spent = flows.sumOf { it.third }
    val hielo = Palette.hielo
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            val showsIncome = categoryId == null
            T(if (showsIncome) "Ingresos y gastos" else "Gastos de ${com.olarte.mprogress.domain.Categories.byId(categoryId)?.name ?: "Sin categoría"}", Type.cuerpo2, Palette.texto2)
            T(if (showsIncome) money(income - spent, sign = true) else money(spent), Type.cifraGrande, maxLines = 1)
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                if (showsIncome) LegendDot(hielo, "Ingresos ${money(income)}")
                LegendDot(Palette.brasa, "Gastos ${money(spent)}")
            }
            val max = flows.maxOf { maxOf(it.second, it.third) }.coerceAtLeast(1)
            Column {
                Canvas(Modifier.fillMaxWidth().height(130.dp)) {
                    val slot = size.width / flows.size
                    val bar = minOf(slot * 0.32f, 16.dp.toPx())
                    flows.forEachIndexed { i, (_, inc, sp) ->
                        val cx = slot * i + slot / 2
                        listOf(inc to hielo, sp to Palette.brasa).forEachIndexed { j, (v, c) ->
                            val h = size.height * v / max
                            if (h > 0) drawRoundRect(c, Offset(cx - bar - 1.dp.toPx() + j * (bar + 2.dp.toPx()), size.height - h), Size(bar, h), CornerRadius(4.dp.toPx()))
                        }
                    }
                }
                Row(Modifier.fillMaxWidth().padding(top = Spacing.s1)) {
                    flows.forEach { T(DueText.months[it.first.monthValue - 1], Type.leyenda, Palette.texto2, Modifier.weight(1f), align = TextAlign.Center, maxLines = 1) }
                }
            }
        }
    }
}

private fun cumulative(entries: List<EntryRecord>, month: YearMonth, upTo: Int?): List<Long> {
    val last = upTo ?: month.lengthOfMonth()
    var run = 0L
    return (1..last).map { d -> run += entries.filter { it.kind == EntryKind.GASTO && it.occurredAt == month.atDay(minOf(d, month.lengthOfMonth())) && d <= month.lengthOfMonth() }.sumOf { it.amountMinor }; run }
}

@Composable
private fun PaceCard(entries: List<EntryRecord>, today: LocalDate) {
    val thisMonth = YearMonth.from(today); val lastMonth = thisMonth.minusMonths(1)
    val now = cumulative(entries, thisMonth, today.dayOfMonth)
    val past = cumulative(entries, lastMonth, null)
    val (spent, before) = SummaryMath.versusLastMonth(entries, today)
    val diff = spent - before
    val lastName = DueText.monthName(lastMonth.atDay(1))
    val gray = Palette.texto2
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            T("Cómo va tu gasto", Type.cuerpo2, Palette.texto2)
            T(money(spent), Type.cifraGrande)
            T(when { diff == 0L -> "Igual que a esta altura de $lastName"; diff > 0 -> "${money(diff)} más que a esta altura de $lastName"
                else -> "${money(-diff)} menos que a esta altura de $lastName" }, Type.cuerpo2, if (diff > 0) Palette.peligro else Palette.texto2)
            val max = maxOf(now.maxOrNull() ?: 0, past.maxOrNull() ?: 0).coerceAtLeast(1)
            Column {
                Canvas(Modifier.fillMaxWidth().height(110.dp)) {
                    fun path(series: List<Long>) = Path().apply {
                        series.forEachIndexed { i, v ->
                            val x = size.width * i / 30f; val y = size.height - size.height * v / max
                            if (i == 0) moveTo(x, y) else lineTo(x, y)
                        }
                    }
                    drawPath(path(past), gray.copy(alpha = 0.6f), style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))))
                    drawPath(path(now), Palette.brasa, style = Stroke(3.dp.toPx(), cap = StrokeCap.Round))
                }
                Box(Modifier.fillMaxWidth().padding(top = Spacing.s1)) {
                    listOf(1, 10, 20, 30).forEach { d ->
                        T("$d", Type.leyenda, Palette.texto2, Modifier.fillMaxWidth((d - 1) / 30f + 0.02f), align = TextAlign.End)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                LegendDot(Palette.brasa, "Este mes")
                LegendDot(gray, "Mes pasado")
            }
        }
    }
}

@Composable
private fun CategoriesCard(visible: List<EntryRecord>) {
    val rows = com.olarte.mprogress.domain.CategoryMath.spending(visible)
    val total = rows.sumOf { it.totalMinor }
    val top = rows.firstOrNull()?.totalMinor?.coerceAtLeast(1) ?: 1
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            T("En qué gastas", Type.cuerpo2, Palette.texto2)
            T(money(total), Type.cifraGrande)
            if (rows.isEmpty()) T("Sin gastos en este periodo.", Type.cuerpo2, Palette.texto2)
            rows.take(8).forEach { row ->
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                    Row { T(com.olarte.mprogress.domain.Categories.byId(row.categoryId)?.name ?: "Sin categoría", Type.cuerpo, modifier = Modifier.weight(1f)); T(money(row.totalMinor), Type.cifraPequena) }
                    Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(Palette.superficie3)) {
                        Box(Modifier.fillMaxWidth((row.totalMinor.toFloat() / top).coerceIn(0.02f, 1f)).height(6.dp).clip(CircleShape).background(Palette.brasa))
                    }
                }
            }
        }
    }
}

/** "Este mes" (PLAN_F12B Paso 4, sin predicciones inventadas): entró, gastaste, fijos que faltan y te quedan, el mismo número de Inicio. */
@Composable
private fun MonthFactsCard(entries: List<EntryRecord>, recurring: List<com.olarte.mprogress.domain.RecurringRecord>, today: LocalDate) {
    val f = com.olarte.mprogress.domain.Forecast.monthFacts(entries, recurring, today)
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s2)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("Este mes", Type.cuerpo2, Palette.texto2, Modifier.weight(1f))
                if (f.isOver) com.olarte.mprogress.ui.components.Badge("Ojo", Palette.peligroVelo, Palette.peligro)
            }
            FactRow("Entró", money(f.enteredMinor))
            if (f.pendingIncomeMinor > 0) FactRow("Por entrar", money(f.pendingIncomeMinor))
            FactRow("Gastaste", money(f.spentMinor))
            FactRow("Fijos que faltan", money(f.pendingFixedMinor))
            Box(Modifier.fillMaxWidth().height(1.dp).background(Palette.linea))
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("Te quedan", Type.cuerpo, modifier = Modifier.weight(1f))
                T(money(f.remainingMinor), Type.cifraGrande, if (f.isOver) Palette.peligro else Palette.texto1, maxLines = 1)
            }
            com.olarte.mprogress.domain.Forecast.overText(f.remainingMinor)?.let { T(it, Type.cuerpo2, Palette.peligro) }
        }
    }
}

@Composable
private fun FactRow(title: String, value: String) {
    Row(Modifier.fillMaxWidth().heightIn(min = 28.dp), verticalAlignment = Alignment.CenterVertically) {
        T(title, Type.cuerpo, Palette.texto2, Modifier.weight(1f))
        T(value, Type.cifraPequena)
    }
}

/** "Los próximos 3 meses": ingresos fijos y gastos fijos, con lo que quedaría. Solo pagos fijos. */
@Composable
private fun NextMonthsCard(months: List<com.olarte.mprogress.domain.MonthForecast>) {
    val hielo = Palette.hielo; val brasa = Palette.brasa
    val max = months.maxOfOrNull { maxOf(it.fixedIncomeMinor, it.fixedExpenseMinor) }?.coerceAtLeast(1) ?: 1
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s3)) {
            T("Los próximos 3 meses", Type.cuerpo2, Palette.texto2)
            Column {
                Canvas(Modifier.fillMaxWidth().height(120.dp)) {
                    val slot = size.width / months.size
                    val bar = minOf(slot * 0.24f, 24.dp.toPx()); val gap = 3.dp.toPx()
                    months.forEachIndexed { i, m ->
                        val start = slot * i + slot / 2 - (bar * 2 + gap) / 2
                        listOf(m.fixedIncomeMinor to hielo, m.fixedExpenseMinor to brasa).forEachIndexed { j, (v, c) ->
                            val h = size.height * v / max
                            if (h > 0) drawRoundRect(c, Offset(start + j * (bar + gap), size.height - h), Size(bar, h), CornerRadius(4.dp.toPx()))
                        }
                    }
                }
                Row(Modifier.fillMaxWidth().padding(top = Spacing.s1)) {
                    months.forEach { T(DueText.months[it.month.monthValue - 1], Type.leyenda, Palette.texto2, Modifier.weight(1f), align = TextAlign.Center) }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.s3)) {
                LegendDot(hielo, "Ingresos fijos", Palette.texto2); LegendDot(brasa, "Gastos fijos", Palette.texto2)
            }
            months.forEach { m ->
                Row(Modifier.fillMaxWidth().heightIn(min = 32.dp), verticalAlignment = Alignment.CenterVertically) {
                    T(DueText.monthName(m.month.atDay(1)).replaceFirstChar { it.uppercase() }, Type.cuerpo, modifier = Modifier.weight(1f))
                    T(com.olarte.mprogress.domain.Forecast.netText(m), Type.cifraPequena, if (m.netMinor < 0) Palette.peligro else Palette.texto1)
                }
            }
            T(com.olarte.mprogress.domain.Forecast.NEXT_MONTHS_NOTE, Type.leyenda, Palette.texto2)
        }
    }
}

@Composable
private fun SmallCard(title: String, value: String, caption: String, modifier: Modifier) {
    Box(modifier) {
        Card {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.s1)) {
                T(title, Type.leyenda, Palette.texto2)
                T(value, Type.cifra, maxLines = 1)
                T(caption, Type.leyenda, Palette.texto2)
            }
        }
    }
}

@Composable
private fun EmptyCard() {
    Card {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.s4)) {
            T("Ingresos y gastos", Type.cuerpo2, Palette.texto2)
            Row(Modifier.fillMaxWidth().height(110.dp), horizontalArrangement = Arrangement.spacedBy(Spacing.s3), verticalAlignment = Alignment.Bottom) {
                listOf(0.5f, 0.8f, 0.6f, 0.9f, 0.7f, 1f).forEach { Box(Modifier.weight(1f).fillMaxHeight(it).clip(RoundedCornerShape(4.dp)).background(Palette.superficie3)) }
            }
            T("Agrega movimientos para ver tu resumen", Type.cuerpo, Palette.texto2)
        }
    }
}
