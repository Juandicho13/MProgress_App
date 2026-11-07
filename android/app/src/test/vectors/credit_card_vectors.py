#!/usr/bin/env python3
"""Modelo de referencia de tarjetas de crédito (Domain/CreditCard.swift y domain/CreditCard.kt).

Este archivo es la especificación ejecutable: las pruebas CreditCardTests.swift (iOS) y
CreditCardTest.kt (Android) comparan contra los números que imprime. Si cambias una regla,
cámbiala aquí primero, corre el script y copia los números nuevos en las dos pruebas.

Correr: python3 -I credit_card_vectors.py

Reglas (iguales en las tres implementaciones):
- Montos en unidades mínimas (COP: 100 por peso). Cada línea (capital o interés) se redondea a pesos
  enteros (múltiplo de 100) con mitad hacia arriba, solo al final de su cálculo.
- Tasa mensual = (1 + EA/100)^(1/12) - 1, con Newton en Decimal y redondeada a 20 decimales.
- Corte del mes M: día de corte o el último día si el mes es corto. Una compra hasta el corte (incluido)
  va en el extracto que corta en M; después del corte, en el siguiente.
- Fecha de pago: el primer día de pago después del corte (mismo mes si cae después, si no el mes siguiente).
- Método por defecto "capital fijo": capital = saldo / cuotas que faltan (redondeado; la última cuota lleva
  el resto) e interés = saldo pendiente x tasa mensual. En el primer extracto de una compra el interés va
  proporcional a los días desde la compra hasta el corte sobre los días del periodo.
  "Cuota fija" (francés): cuota = R*i*q/(q-1) con q=(1+i)^m; capital = cuota - interés del mes completo.
- Compra a 1 cuota sin intereses (si la tarjeta lo permite): interés 0; va completa en el mínimo.
- Avance: intereses desde el día uno (nunca es sin intereses) y comisión fija opcional en el extracto.
- Pago: primero cubre lo que falta del extracto (el mínimo); el excedente baja capital futuro: avances
  primero, luego el saldo con más intereses por delante (saldo x (cuotas que faltan + 1)), luego el más viejo.
  Si sobra, queda saldo a favor y se usa en el siguiente extracto.
- Lo que falta del mínimo al llegar el siguiente corte pasa como "pendiente" con interés de mora ESTIMADO
  = pendiente x tasa mensual (la app no modela la mora exacta del banco).
- Simuladores: sin cuota de manejo; pagan el día de pago de cada extracto.
"""
from dataclasses import dataclass, field, replace
from datetime import date, timedelta
from decimal import Decimal as D, getcontext, ROUND_HALF_UP
import calendar

getcontext().prec = 34
UNIT = 100  # COP: se redondea a pesos enteros


def monthly_rate(ea_percent) -> D:
    a = 1 + D(str(ea_percent)) / 100
    if a == 1:
        return D(0)
    x = 1 + D(str(ea_percent)) / 1200
    for _ in range(60):
        nx = x - (x ** 12 - a) / (12 * x ** 11)
        if abs(nx - x) < D("1e-30"):
            x = nx
            break
        x = nx
    return (x - 1).quantize(D("1e-20"), ROUND_HALF_UP)


def round_unit(value: D) -> int:
    return int((value / UNIT).quantize(D(1), ROUND_HALF_UP)) * UNIT


def dim(y, m):
    return calendar.monthrange(y, m)[1]


def clamp(y, m, day):
    return date(y, m, min(max(1, day), dim(y, m)))


def add_month(y, m, k):
    t = y * 12 + (m - 1) + k
    return t // 12, t % 12 + 1


def cut_in(y, m, cut_day):
    return clamp(y, m, cut_day)


def statement_cut(d: date, cut_day):
    c = cut_in(d.year, d.month, cut_day)
    if d <= c:
        return c
    y, m = add_month(d.year, d.month, 1)
    return cut_in(y, m, cut_day)


def next_cut(c: date, cut_day):
    y, m = add_month(c.year, c.month, 1)
    return cut_in(y, m, cut_day)


def previous_cut(c: date, cut_day):
    y, m = add_month(c.year, c.month, -1)
    return cut_in(y, m, cut_day)


def due_date(c: date, due_day):
    cand = clamp(c.year, c.month, due_day)
    if cand > c:
        return cand
    y, m = add_month(c.year, c.month, 1)
    return clamp(y, m, due_day)


@dataclass
class Terms:
    limit: int
    cut_day: int
    due_day: int
    rate_ea: str
    fee: int = 0
    one_free: bool = True
    advance_fee: int = 0
    method: str = "capitalFijo"


@dataclass
class Purchase:
    name: str
    amount: int
    day: date
    n: int = 1
    kind: str = "compra"


@dataclass
class Payment:
    amount: int
    day: date


@dataclass
class Balance:
    seq: int
    name: str
    kind: str
    n: int
    day: date
    amount: int
    remaining: int
    billed: int = 0


@dataclass
class Line:
    name: str
    kind: str
    k: int
    n: int
    capital: int
    interest: int
    remaining_after: int


@dataclass
class Statement:
    cut: date
    due: date
    lines: list
    fee: int
    advance_fees: int
    overdue: int
    mora: int
    credit_applied: int
    minimum: int
    total: int

    @property
    def interest(self):
        return sum(l.interest for l in self.lines)


@dataclass
class State:
    balances: list = field(default_factory=list)
    due_unpaid: int = 0
    credit: int = 0
    pending_adv_fees: int = 0
    seq: int = 0


def free_purchase(b: Balance, t: Terms):
    return b.kind == "compra" and b.n == 1 and t.one_free


def priority_key(b: Balance, t: Terms, i: D):
    bearing = (not free_purchase(b, t)) and i > 0
    left = max(1, b.n - b.billed)
    weight = b.remaining * (left + 1) if bearing else 0
    return (0 if b.kind == "avance" else 1, -weight, b.day, b.seq)


def prepay(state: State, amount: int, t: Terms, i: D) -> int:
    for b in sorted([b for b in state.balances if b.remaining > 0], key=lambda b: priority_key(b, t, i)):
        if amount <= 0:
            break
        x = min(amount, b.remaining)
        b.remaining -= x
        amount -= x
    return amount


def add_purchase(state: State, p: Purchase, t: Terms):
    state.balances.append(Balance(state.seq, p.name, p.kind, max(1, min(48, p.n)), p.day, p.amount, p.amount))
    state.seq += 1
    if p.kind == "avance":
        state.pending_adv_fees += t.advance_fee


def pay(state: State, amount: int, t: Terms, i: D):
    to_due = min(amount, state.due_unpaid)
    state.due_unpaid -= to_due
    rest = prepay(state, amount - to_due, t, i)
    state.credit += rest


def bill(state: State, c: date, t: Terms, i: D) -> Statement:
    prev = previous_cut(c, t.cut_day)
    period_days = (c - prev).days
    overdue = state.due_unpaid
    mora = round_unit(overdue * i) if overdue > 0 else 0
    lines = []
    for b in state.balances:
        if b.remaining <= 0:
            continue
        k = b.billed + 1
        left = max(1, b.n - b.billed)
        free = free_purchase(b, t)
        r = b.remaining
        if left <= 1:
            capital = r
        elif t.method == "cuotaFija" and not free and i > 0:
            q = (1 + i) ** left
            cuota = round_unit(D(r) * i * q / (q - 1))
            capital = max(0, min(r, cuota - round_unit(D(r) * i)))
        else:
            capital = round_unit(D(r) / left)
        if free:
            interest = 0
        elif b.billed == 0:
            days = (c - b.day).days
            interest = round_unit(D(r) * i * days / period_days)
        else:
            interest = round_unit(D(r) * i)
        b.remaining -= capital
        b.billed += 1
        lines.append(Line(b.name, b.kind, k, b.n, capital, interest, b.remaining))
    adv = state.pending_adv_fees
    state.pending_adv_fees = 0
    due = sum(l.capital + l.interest for l in lines) + t.fee + adv + overdue + mora
    used = min(state.credit, due)
    due -= used
    state.credit -= used
    if state.credit > 0:
        state.credit = prepay(state, state.credit, t, i)
    total = due + sum(b.remaining for b in state.balances)
    state.due_unpaid = due
    return Statement(c, due_date(c, t.due_day), lines, t.fee, adv, overdue, mora, used, due, total)


@dataclass
class Ledger:
    statements: list
    paid: list  # pagado a cada extracto (pagos entre su corte y el siguiente)
    state: State
    debt: int


def run(t: Terms, purchases, payments, through: date) -> Ledger:
    i = monthly_rate(t.rate_ea)
    events = [(p.day, 0, n, p) for n, p in enumerate(purchases)] + [(p.day, 1, n, p) for n, p in enumerate(payments)]
    events.sort(key=lambda e: (e[0], e[1], e[2]))
    state = State()
    statements, paid = [], []
    if not events:
        return Ledger([], [], state, 0)
    cut = statement_cut(events[0][0], t.cut_day)
    idx = 0

    def process(limit_day):
        nonlocal idx
        while idx < len(events) and events[idx][0] <= limit_day:
            _, kind, _, obj = events[idx]
            if kind == 0:
                add_purchase(state, obj, t)
            else:
                pay(state, obj.amount, t, i)
                if paid:
                    paid[-1] += obj.amount
            idx += 1

    while cut <= through:
        process(cut)
        statements.append(bill(state, cut, t, i))
        paid.append(0)
        cut = next_cut(cut, t.cut_day)
    process(through)
    debt = sum(b.remaining for b in state.balances) + state.due_unpaid - state.credit
    return Ledger(statements, paid, state, debt)


def status(st: Statement, paid: int, today: date, i: D):
    if paid >= st.total:
        return ("total", 0, 0)
    if paid >= st.minimum:
        return ("minimo", 0, 0)
    if today <= st.due:
        return ("pendiente", st.minimum - paid, 0)
    missing = st.minimum - paid
    return ("incompleto", missing, round_unit(missing * i))


def simulate(t: Terms, purchases, payments, now: date, fixed=None, max_months=600):
    """Pagar solo el mínimo (fixed=None) o un valor fijo al mes. Devuelve (factible, meses, intereses, pagado, ultimo_pago, minimo_requerido)."""
    t0 = replace(t, fee=0)
    i = monthly_rate(t.rate_ea)
    led = run(t0, purchases, payments, now)
    state = led.state
    months, interest, paid_total = 0, 0, 0
    last = None
    if led.statements:
        cut = next_cut(led.statements[-1].cut, t.cut_day)
        last_st = led.statements[-1]
    else:
        cut = statement_cut(now, t.cut_day)
        last_st = None

    def owed():
        return state.due_unpaid + sum(b.remaining for b in state.balances) - state.credit

    def do_pay(minimum, due_day):
        nonlocal months, paid_total, last
        if fixed is None:
            amount = state.due_unpaid
        else:
            if fixed < minimum:
                return False
            amount = min(fixed, owed())
        if amount > 0:
            pay(state, amount, t0, i)
            months += 1
            paid_total += amount
            last = due_day
        return True

    if last_st is not None and state.due_unpaid > 0:
        if not do_pay(state.due_unpaid, max(last_st.due, now)):
            return (False, 0, 0, 0, None, state.due_unpaid)
    for _ in range(max_months):
        if owed() <= 0:
            break
        st = bill(state, cut, t0, i)
        interest += st.interest + st.mora
        if not do_pay(st.minimum, st.due):
            return (False, 0, 0, 0, None, st.minimum)
        cut = next_cut(cut, t.cut_day)
    return (True, months, interest, paid_total, last, 0)


def schedule_and_cost(t: Terms, amount, n, day, kind="compra"):
    """Plan de cuotas de una compra sola pagando el mínimo: ([(corte, k, capital, interés)], intereses, comisiones)."""
    t0 = replace(t, fee=0)
    i = monthly_rate(t.rate_ea)
    state = State()
    add_purchase(state, Purchase("x", amount, day, n, kind), t0)
    cut = statement_cut(day, t.cut_day)
    out, interest, fees = [], 0, 0
    for _ in range(60):
        if sum(b.remaining for b in state.balances) <= 0:
            break
        st = bill(state, cut, t0, i)
        fees += st.advance_fees
        for l in st.lines:
            interest += l.interest
            out.append((cut, l.k, l.capital, l.interest))
        pay(state, state.due_unpaid, t0, i)
        cut = next_cut(cut, t.cut_day)
    return out, interest, fees


def schedule(t, amount, n, day, kind="compra"):
    return schedule_and_cost(t, amount, n, day, kind)[0]


def purchase_cost(t, amount, n, day, kind="compra"):
    _, interest, fees = schedule_and_cost(t, amount, n, day, kind)
    return interest, fees


def p(x):
    return x // UNIT  # para leer en pesos


def show_statement(label, st: Statement):
    print(f"  {label}: corte {st.cut} pago {st.due} minimo {st.minimum} total {st.total} cuota_manejo {st.fee} "
          f"avances {st.advance_fees} pendiente {st.overdue} mora {st.mora} favor {st.credit_applied} intereses {st.interest}")
    for l in st.lines:
        print(f"    {l.name} {l.kind} {l.k}/{l.n} capital {l.capital} interes {l.interest} queda {l.remaining_after}")


if __name__ == "__main__":
    print("== Tasa mensual")
    for ea in ["28.34", "24.36", "0", "100", "12"]:
        print(f"  EA {ea}: {monthly_rate(ea)}")

    print("== Fechas")
    print("  corte 31 en feb 2026:", cut_in(2026, 2, 31), " feb 2028:", cut_in(2028, 2, 31))
    print("  compra 2026-11-30 corte 30:", statement_cut(date(2026, 11, 30), 30), " 2026-12-01:", statement_cut(date(2026, 12, 1), 30))
    print("  compra 2027-01-31 corte 30:", statement_cut(date(2027, 1, 31), 30), " compra 2027-02-28 corte 30:", statement_cut(date(2027, 2, 28), 30))
    print("  pago dia 15 corte 2026-11-30:", due_date(date(2026, 11, 30), 15))
    print("  pago dia 28 corte 2026-11-10:", due_date(date(2026, 11, 10), 28))
    print("  pago dia 30 corte 2027-01-31 (corte 31):", due_date(date(2027, 1, 31), 30))
    print("  pago dia 15 corte 2026-11-15:", due_date(date(2026, 11, 15), 15))

    T = Terms(limit=5_000_000 * UNIT, cut_day=30, due_day=15, rate_ea="28.34")

    print("== V4 compra 1.200.000 a 12 cuotas el 2026-10-20 (corte 30, pago 15, 28,34 % EA)")
    for row in schedule(T, 1_200_000 * UNIT, 12, date(2026, 10, 20)):
        print("  ", row[0], row[1], row[2], row[3])
    print("  costo:", purchase_cost(T, 1_200_000 * UNIT, 12, date(2026, 10, 20)))

    print("== V4b misma compra con cuota fija")
    TF = replace(T, method="cuotaFija")
    for row in schedule(TF, 1_200_000 * UNIT, 12, date(2026, 10, 20)):
        print("  ", row[0], row[1], row[2], row[3])
    print("  costo:", purchase_cost(TF, 1_200_000 * UNIT, 12, date(2026, 10, 20)))

    print("== V5 compra a 1 cuota")
    print("  sin intereses:", schedule(T, 350_000 * UNIT, 1, date(2026, 11, 3)))
    print("  con intereses:", schedule(replace(T, one_free=False), 350_000 * UNIT, 1, date(2026, 11, 3)))

    print("== V6 avance 500.000 a 1 cuota el 2026-11-10 con comision 9.900")
    TA = replace(T, advance_fee=9_900 * UNIT)
    led = run(TA, [Purchase("Avance", 500_000 * UNIT, date(2026, 11, 10), 1, "avance")], [], date(2026, 11, 30))
    show_statement("avance", led.statements[-1])
    print("  costo avance 3 cuotas:", purchase_cost(TA, 500_000 * UNIT, 3, date(2026, 11, 10), "avance"))
    print("  plan avance 3 cuotas:", schedule(TA, 500_000 * UNIT, 3, date(2026, 11, 10), "avance"))

    print("== V7 extracto con varias compras y cuota de manejo 32.900")
    T7 = replace(T, fee=32_900 * UNIT, advance_fee=9_900 * UNIT)
    P7 = [
        Purchase("Mercado", 420_000 * UNIT, date(2026, 11, 2), 1),
        Purchase("Celular", 2_400_000 * UNIT, date(2026, 11, 5), 24),
        Purchase("Tiquetes", 900_000 * UNIT, date(2026, 11, 12), 6),
        Purchase("Avance", 300_000 * UNIT, date(2026, 11, 20), 2, "avance"),
        Purchase("Cine", 85_000 * UNIT, date(2026, 11, 30), 1),
        Purchase("Despues del corte", 50_000 * UNIT, date(2026, 12, 1), 1),
    ]
    led7 = run(T7, P7, [], date(2026, 11, 30))
    show_statement("nov", led7.statements[-1])
    print("  deuda 2026-11-30:", led7.debt, " disponible:", T7.limit - led7.debt)
    led7b = run(T7, P7, [], date(2026, 12, 3))
    print("  deuda 2026-12-03:", led7b.debt, " disponible:", T7.limit - led7b.debt)

    print("== V8 pago entre minimo y total (2.000.000 el 2026-12-10)")
    led8 = run(T7, P7, [Payment(2_000_000 * UNIT, date(2026, 12, 10))], date(2026, 12, 30))
    show_statement("nov", led8.statements[0])
    print("  pagado nov:", led8.paid[0], status(led8.statements[0], led8.paid[0], date(2026, 12, 20), monthly_rate(T7.rate_ea)))
    show_statement("dic", led8.statements[1])
    print("  deuda 2026-12-30:", led8.debt)

    print("== V9 pago menor al minimo (500.000 el 2026-12-14)")
    led9 = run(T7, P7, [Payment(500_000 * UNIT, date(2026, 12, 14))], date(2026, 12, 30))
    i7 = monthly_rate(T7.rate_ea)
    print("  estado el 2026-12-10:", status(led9.statements[0], led9.paid[0], date(2026, 12, 10), i7))
    print("  estado el 2026-12-16:", status(led9.statements[0], led9.paid[0], date(2026, 12, 16), i7))
    show_statement("dic", led9.statements[1])

    print("== V10 pago total")
    total_nov = led7.statements[-1].total
    led10 = run(T7, P7, [Payment(total_nov, date(2026, 12, 15))], date(2026, 12, 30))
    print("  total nov:", total_nov, status(led10.statements[0], led10.paid[0], date(2026, 12, 20), i7))
    show_statement("dic", led10.statements[1])
    print("  deuda:", led10.debt)

    print("== V10b pago de mas (total + 100.000) deja saldo a favor")
    led10b = run(T7, P7, [Payment(total_nov + 100_000 * UNIT, date(2026, 12, 15))], date(2026, 12, 30))
    show_statement("dic", led10b.statements[1])
    print("  deuda:", led10b.debt)

    print("== V11 simuladores sobre V7 al 2026-12-01")
    print("  solo minimo:", simulate(T7, P7, [], date(2026, 12, 1)))
    print("  1.000.000 al mes:", simulate(T7, P7, [], date(2026, 12, 1), fixed=1_000_000 * UNIT))
    print("  300.000 al mes:", simulate(T7, P7, [], date(2026, 12, 1), fixed=300_000 * UNIT))

    print("== V12 pago antes del primer corte baja capital")
    led12 = run(T, [Purchase("TV", 1_000_000 * UNIT, date(2026, 11, 1), 10)], [Payment(400_000 * UNIT, date(2026, 11, 15))], date(2026, 11, 30))
    show_statement("nov", led12.statements[-1])

    print("== V13 corte 31 en meses cortos")
    T13 = replace(T, cut_day=31, due_day=20)
    led13 = run(T13, [Purchase("Bici", 600_000 * UNIT, date(2027, 1, 31), 3)], [], date(2027, 4, 30))
    for st in led13.statements:
        show_statement(str(st.cut), st)
