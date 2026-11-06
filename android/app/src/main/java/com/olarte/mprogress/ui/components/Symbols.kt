package com.olarte.mprogress.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ReceiptLong
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.AccountBalance
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.AutoFixHigh
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.CreditCard
import androidx.compose.material.icons.rounded.DocumentScanner
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.Payments
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.Savings
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.TrackChanges
import androidx.compose.ui.graphics.vector.ImageVector
import com.olarte.mprogress.domain.QuickActionKind

/** Equivalentes de los SF Symbols de iOS en Material. */
object Sym {
    val house = Icons.Outlined.Home
    val houseFill = Icons.Rounded.Home
    val chart = Icons.Outlined.BarChart
    val chartFill = Icons.Rounded.BarChart
    val bank = Icons.Outlined.AccountBalance
    val bankFill = Icons.Rounded.AccountBalance
    val calendar = Icons.Outlined.CalendarMonth
    val calendarFill = Icons.Rounded.CalendarMonth
    val gear = Icons.Outlined.Settings
    val gearFill = Icons.Rounded.Settings
    val bell = Icons.Outlined.Notifications
    val repeat = Icons.Rounded.Repeat
    val card = Icons.Rounded.CreditCard
    val up = Icons.Rounded.ArrowUpward
    val down = Icons.Rounded.ArrowDownward
    val more = Icons.Rounded.MoreHoriz

    fun of(kind: QuickActionKind): ImageVector = when (kind) {
        QuickActionKind.GASTO -> Icons.Rounded.Add
        QuickActionKind.INGRESO -> Icons.Rounded.ArrowDownward
        QuickActionKind.FIJO -> Icons.Rounded.Repeat
        QuickActionKind.SUELDO -> Icons.Outlined.Payments
        QuickActionKind.ANUAL -> Icons.Rounded.CalendarMonth
        QuickActionKind.FIJOS -> Icons.AutoMirrored.Rounded.ReceiptLong
        QuickActionKind.RAPIDO -> Icons.Rounded.TouchApp
        QuickActionKind.LIMITES -> Icons.Rounded.Speed
        QuickActionKind.AHORRO -> Icons.Rounded.TrackChanges
        QuickActionKind.HISTORIAL -> Icons.Rounded.History
        QuickActionKind.RECIBO -> Icons.Rounded.DocumentScanner
        QuickActionKind.AUTOMATICO -> Icons.Rounded.AutoFixHigh
    }

    val savings = Icons.Rounded.Savings
}
