package com.olarte.mprogress.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.olarte.mprogress.auto.LaunchAction
import com.olarte.mprogress.data.Store
import com.olarte.mprogress.domain.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth

/** Colores Forja de los widgets, los mismos de iOS (MProgressWidgets). */
private object Forja {
    val fondo = Color(0xFF0A0B0D); val superficie = Color(0xFF1A1C20); val texto1 = Color(0xFFF3F4F6); val texto2 = Color(0xFF9EA3AB)
    val brasa = Color(0xFFF55F1F); val oro = Color(0xFFF5C451); val peligro = Color(0xFFFF6B6B); val sobreOro = Color(0xFF140A05)
}

private fun style(size: TextUnit, color: Color, bold: Boolean = false) = TextStyle(color = ColorProvider(color), fontSize = size, fontWeight = if (bold) FontWeight.Bold else FontWeight.Medium)

/** Lo que ven los widgets, ya calculado, como WidgetSnapshot de iOS. */
private data class Snapshot(val remaining: Long, val charges: List<UpcomingCharge>, val month: YearMonth, val today: LocalDate, val chargeDays: Map<Int, Int>, val chargesThisMonth: Int)

private fun snapshot(context: Context): Snapshot {
    val store = Store.get(context)
    val l = store.ledger.value
    val today = LocalDate.now()
    val active = l.recurring.filter { it.active }
    val summary = BalanceCalculator.monthSummary(l.entries, active, today)
    val month = YearMonth.from(today)
    val days = CalendarMath.days(month, emptyList(), l.recurring, today)
    val chargeDays = days.filter { it.value.charges.isNotEmpty() }.mapKeys { it.key.dayOfMonth }.mapValues { (_, v) ->
        val d = v.charges.minOf { it.daysLeft }; if (d <= 0) 0 else if (d <= 3) 1 else 2 }
    return Snapshot(summary.remainingMinor, BalanceCalculator.upcoming(active, today, kind = null, limit = 6), month, today, chargeDays, days.values.sumOf { it.charges.size })
}

private fun dueText(d: Int) = when { d < 0 -> "Vencido"; d == 0 -> "Hoy"; d == 1 -> "Mañana"; else -> "$d d" }

private fun open(context: Context, action: String) = actionStartActivity(LaunchAction.intent(context, action))

/** Pequeño: próximo cargo. */
class NextChargeWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = snapshot(context)
        provideContent {
            Column(GlanceModifier.fillMaxSize().background(Forja.fondo).cornerRadius(22.dp).padding(14.dp).clickable(open(context, "fijos"))) {
                val c = s.charges.firstOrNull()
                if (c == null) { Spacer(GlanceModifier.defaultWeight()); Text("Sin cobros próximos", style = style(13.sp, Forja.texto2)) }
                else {
                    Badge(c.daysLeft)
                    Spacer(GlanceModifier.defaultWeight())
                    Text(c.name, style = style(14.sp, Forja.texto1, true), maxLines = 1)
                    Text(Money(c.amountMinor).formatted(), style = style(19.sp, Forja.texto1, true), maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun Badge(days: Int) {
    val (bg, fg) = when { days <= 0 -> Forja.brasa to Color.White; days <= 3 -> Forja.oro to Forja.sobreOro; else -> Forja.superficie to Forja.texto2 }
    Box(GlanceModifier.background(bg).cornerRadius(10.dp).padding(horizontal = 8.dp, vertical = 3.dp)) {
        Text(dueText(days).uppercase(), style = style(11.sp, fg, true))
    }
}

/** Mediano: te quedan, + Gasto y 4 cargos. */
class RemainingWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = snapshot(context)
        provideContent {
            Row(GlanceModifier.fillMaxSize().background(Forja.fondo).cornerRadius(22.dp).padding(14.dp).clickable(open(context, "inicio"))) {
                Column(GlanceModifier.defaultWeight().fillMaxSize()) {
                    Text("Te quedan", style = style(12.sp, Forja.texto2))
                    Text(Money(s.remaining).formatted(), style = style(21.sp, if (s.remaining < 0) Forja.peligro else Forja.texto1, true), maxLines = 1)
                    Spacer(GlanceModifier.defaultWeight())
                    Box(GlanceModifier.fillMaxWidth().height(38.dp).background(Forja.brasa).cornerRadius(19.dp).clickable(open(context, "gasto")), contentAlignment = Alignment.Center) {
                        Text("+ Gasto", style = style(14.sp, Color.White, true))
                    }
                }
                Spacer(GlanceModifier.width(14.dp))
                Column(GlanceModifier.defaultWeight().fillMaxSize()) {
                    if (s.charges.isEmpty()) Text("Sin cobros próximos", style = style(11.sp, Forja.texto2))
                    s.charges.take(4).forEach { c ->
                        Row(GlanceModifier.fillMaxWidth().padding(bottom = 7.dp)) {
                            Text(c.name, style = style(12.sp, Forja.texto1), maxLines = 1, modifier = GlanceModifier.defaultWeight())
                            Text(dueText(c.daysLeft), style = style(12.sp, if (c.daysLeft <= 1) Forja.oro else Forja.texto2, true))
                        }
                    }
                }
            }
        }
    }
}

/** Grande: calendario del mes con los días en que se cobra algo. */
class CalendarWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = snapshot(context)
        provideContent {
            Column(GlanceModifier.fillMaxSize().background(Forja.fondo).cornerRadius(22.dp).padding(16.dp).clickable(open(context, "calendario"))) {
                Row(GlanceModifier.fillMaxWidth()) {
                    Text("${DueText.monthName(s.month.atDay(1)).replaceFirstChar { it.uppercase() }} ${s.month.year}", style = style(16.sp, Forja.texto1, true), modifier = GlanceModifier.defaultWeight())
                    Text("${s.chargesThisMonth} cargos", style = style(12.sp, Forja.texto2))
                }
                Spacer(GlanceModifier.height(8.dp))
                Row(GlanceModifier.fillMaxWidth()) { CalendarMath.weekdays.forEach { Text(it, style = style(11.sp, Forja.texto2), modifier = GlanceModifier.defaultWeight()) } }
                CalendarMath.grid(s.month).chunked(7).forEach { week ->
                    Row(GlanceModifier.fillMaxWidth().padding(top = 5.dp)) {
                        (0 until 7).forEach { i ->
                            val date = week.getOrNull(i)
                            Box(GlanceModifier.defaultWeight().height(24.dp), contentAlignment = Alignment.Center) {
                                if (date != null) {
                                    val u = s.chargeDays[date.dayOfMonth]
                                    val bg = when (u) { 0 -> Forja.brasa; 1 -> Forja.oro; 2 -> Forja.texto1; else -> null }
                                    val fg = when (u) { 0 -> Color.White; 1, 2 -> Forja.sobreOro; else -> if (date == s.today) Forja.brasa else Forja.texto1 }
                                    Box((if (bg != null) GlanceModifier.background(bg).cornerRadius(12.dp) else GlanceModifier).width(30.dp).height(22.dp), contentAlignment = Alignment.Center) {
                                        Text("${date.dayOfMonth}", style = style(12.sp, fg, u != null))
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer(GlanceModifier.defaultWeight())
                s.charges.firstOrNull()?.let { next ->
                    Row(GlanceModifier.fillMaxWidth().background(Forja.superficie).cornerRadius(12.dp).padding(horizontal = 12.dp, vertical = 9.dp)) {
                        Text("Próximo · ${next.name}", style = style(12.sp, Forja.texto2), maxLines = 1, modifier = GlanceModifier.defaultWeight())
                        Text(Money(next.amountMinor).formatted(), style = style(13.sp, Forja.texto1, true))
                    }
                }
            }
        }
    }
}

class NextChargeReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = NextChargeWidget() }
class RemainingReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = RemainingWidget() }
class CalendarReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = CalendarWidget() }

/** Refresca los widgets cuando cambian los datos. */
object WidgetRefresher {
    private val scope = CoroutineScope(Dispatchers.Default)
    fun refresh(context: Context) {
        val app = context.applicationContext
        scope.launch { runCatching { NextChargeWidget().updateAll(app); RemainingWidget().updateAll(app); CalendarWidget().updateAll(app) } }
    }
}
