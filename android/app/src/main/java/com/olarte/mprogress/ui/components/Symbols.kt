package com.olarte.mprogress.ui.components

import androidx.compose.material.icons.outlined.LocalCafe
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.WaterDrop
import androidx.compose.material.icons.outlined.Wifi
import androidx.compose.material.icons.outlined.PhoneIphone
import androidx.compose.material.icons.outlined.DirectionsBus
import androidx.compose.material.icons.outlined.Flight
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material.icons.outlined.Medication
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.Pets
import androidx.compose.material.icons.outlined.CardGiftcard
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Checkroom
import androidx.compose.material.icons.outlined.ContentCut
import androidx.compose.material.icons.outlined.CreditCard
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
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material.icons.outlined.DirectionsCar
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.outlined.MedicalServices
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.Business
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Cloud
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
        QuickActionKind.FIJOS -> Icons.AutoMirrored.Rounded.ReceiptLong
        QuickActionKind.RAPIDO -> Icons.Rounded.TouchApp
        QuickActionKind.LIMITES -> Icons.Rounded.Speed
        QuickActionKind.AHORRO -> Icons.Rounded.TrackChanges
        QuickActionKind.RECIBO -> Icons.Rounded.DocumentScanner
        QuickActionKind.AUTOMATICO -> Icons.Rounded.AutoFixHigh
    }

    val savings = Icons.Rounded.Savings

    /** Íconos de iOS (SF Symbols) usados en datos: categorías, pagos fijos. */
    fun sf(name: String?): ImageVector? = when (name) {
        "play.rectangle" -> Icons.Outlined.SmartDisplay
        "music.note" -> Icons.Rounded.MusicNote
        "briefcase" -> Icons.Outlined.WorkOutline
        "wrench.and.screwdriver" -> Icons.Outlined.Build
        "house" -> Icons.Outlined.Home
        "cart" -> Icons.Outlined.ShoppingCart
        "car" -> Icons.Outlined.DirectionsCar
        "fork.knife" -> Icons.Outlined.Restaurant
        "dumbbell" -> Icons.Rounded.FitnessCenter
        "cross.case" -> Icons.Outlined.MedicalServices
        "graduationcap" -> Icons.Outlined.School
        "person.2" -> Icons.Outlined.People
        "building.2" -> Icons.Outlined.Business
        "banknote" -> Icons.Outlined.Payments
        "square.grid.2x2" -> Icons.Outlined.GridView
        "icloud" -> Icons.Outlined.Cloud
        "sparkles" -> Icons.Rounded.AutoAwesome
        "cup.and.saucer" -> Icons.Outlined.LocalCafe
        "bolt" -> Icons.Outlined.Bolt
        "drop" -> Icons.Outlined.WaterDrop
        "wifi" -> Icons.Outlined.Wifi
        "iphone" -> Icons.Outlined.PhoneIphone
        "bus" -> Icons.Outlined.DirectionsBus
        "airplane" -> Icons.Outlined.Flight
        "gamecontroller" -> Icons.Outlined.SportsEsports
        "pills" -> Icons.Outlined.Medication
        "book" -> Icons.Outlined.Book
        "pawprint" -> Icons.Outlined.Pets
        "gift" -> Icons.Outlined.CardGiftcard
        "heart" -> Icons.Outlined.FavoriteBorder
        "tshirt" -> Icons.Outlined.Checkroom
        "scissors" -> Icons.Outlined.ContentCut
        "creditcard" -> Icons.Outlined.CreditCard
        else -> null
    }
}
