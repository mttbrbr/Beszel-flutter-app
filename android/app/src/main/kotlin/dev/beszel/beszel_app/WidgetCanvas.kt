package dev.beszel.beszel_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Widgets drawn to a bitmap sized exactly like the widget on screen, so the content
 * always scales to the available grid (1x1, 2x1, bigger...) instead of floating in it.
 */
object WidgetCanvas {
    class Scene(val c: Canvas, val w: Float, val h: Float, val d: Float)

    private const val SURFACE = 0xB0101114.toInt() // ~69% opaque, lets the wallpaper through
    private const val HAIRLINE = 0x24FFFFFF
    private const val WHITE = 0xFFF4F4F5.toInt()

    fun render(ctx: Context, mgr: AppWidgetManager, id: Int, draw: (Scene) -> Unit): Bitmap {
        val o = mgr.getAppWidgetOptions(id)
        // Portrait: width = MIN_WIDTH, height = MAX_HEIGHT. Landscape: width = MAX_WIDTH, height = MIN_HEIGHT.
        val land = ctx.resources.configuration.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE
        fun opt(key: String, fallback: Int) = o.getInt(key, 0).takeIf { it > 0 } ?: fallback
        val wDp = if (land) opt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 110) else opt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
        val hDp = if (land) opt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 56) else opt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 56)
        var d = ctx.resources.displayMetrics.density
        var w = wDp * d
        var h = hDp * d
        val maxPx = 900_000f
        if (w * h > maxPx) {
            val s = sqrt(maxPx / (w * h))
            w *= s; h *= s; d *= s
        }
        val bmp = Bitmap.createBitmap(max(2, w.roundToInt()), max(2, h.roundToInt()), Bitmap.Config.ARGB_8888)
        draw(Scene(Canvas(bmp), bmp.width.toFloat(), bmp.height.toFloat(), d))
        return bmp
    }

    // ---------------------------------------------------------------- primitives

    private fun paint(color: Int, size: Float = 0f, bold: Boolean = false, align: Paint.Align = Paint.Align.LEFT) =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            textSize = size
            textAlign = align
            typeface = Typeface.create(if (bold) "sans-serif-medium" else "sans-serif", if (bold) Typeface.BOLD else Typeface.NORMAL)
        }

    private fun fit(p: Paint, s: String, maxW: Float, size: Float, minSize: Float): Paint {
        p.textSize = size
        while (p.measureText(s) > maxW && p.textSize > minSize) p.textSize = max(minSize, p.textSize * 0.93f)
        return p
    }

    private fun background(s: Scene, accent: Int? = null) {
        val r = 16 * s.d
        val rect = RectF(0f, 0f, s.w, s.h)
        s.c.drawRoundRect(rect, r, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = SURFACE })
        if (accent != null) {
            s.c.drawRoundRect(rect, r, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = (accent and 0x00FFFFFF) or 0x1C000000 })
        }
        val b = 0.5f * s.d
        s.c.drawRoundRect(
            RectF(b, b, s.w - b, s.h - b), r, r,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = s.d
                color = if (accent != null) (accent and 0x00FFFFFF) or 0x66000000 else HAIRLINE
            },
        )
    }

    private fun centered(s: Scene, text: String, color: Int) {
        val p = fit(paint(color, 13 * s.d, true, Paint.Align.CENTER), text, s.w - 12 * s.d, 13 * s.d, 8 * s.d)
        s.c.drawText(text, s.w / 2, s.h / 2 + p.textSize * 0.35f, p)
    }

    /** Status dot + machine name, left-aligned at [x] or centered on it. */
    private fun nameLine(s: Scene, m: Machine, x: Float, baseline: Float, size: Float, maxW: Float, center: Boolean) {
        val dot = size * 0.5f
        val gap = size * 0.35f
        val p = fit(paint(WHITE, size, true), m.name, maxW - dot - gap, size, 7 * s.d)
        val total = dot + gap + p.measureText(m.name)
        val x0 = if (center) x - total / 2 else x
        s.c.drawCircle(x0 + dot / 2, baseline - p.textSize * 0.33f, dot / 2, paint(WidgetData.statusColor(m)))
        s.c.drawText(m.name, x0 + dot + gap, baseline, p)
    }

    private fun rings(c: Canvas, cx: Float, cy: Float, dia: Float, values: List<Double?>, colors: List<Int>) {
        val stroke = dia * 0.11f
        val gap = dia * 0.035f
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke; color = 0x33FFFFFF }
        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke; strokeCap = Paint.Cap.ROUND }
        values.forEachIndexed { i, v ->
            val r = dia / 2 - stroke / 2 - i * (stroke + gap)
            if (r <= 0) return@forEachIndexed
            val rect = RectF(cx - r, cy - r, cx + r, cy + r)
            c.drawArc(rect, 0f, 360f, false, track)
            if (v != null && v > 0) {
                arc.color = colors[i]
                c.drawArc(rect, -90f, (v.coerceIn(0.0, 100.0) * 3.6).toFloat().coerceAtLeast(6f), false, arc)
            }
        }
    }

    /** Check / cross / exclamation drawn as strokes (no font dependency). */
    private fun badge(s: Scene, cx: Float, cy: Float, dia: Float, color: Int, symbol: String) {
        s.c.drawCircle(cx, cy, dia / 2, paint((color and 0x00FFFFFF) or 0x2E000000))
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color; style = Paint.Style.STROKE; strokeWidth = dia * 0.1f
            strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
        }
        val u = dia * 0.22f
        when (symbol) {
            "ok" -> s.c.drawPath(Path().apply { moveTo(cx - u, cy + u * 0.05f); lineTo(cx - u * 0.3f, cy + u * 0.8f); lineTo(cx + u, cy - u * 0.7f) }, p)
            "err" -> {
                s.c.drawLine(cx - u * 0.8f, cy - u * 0.8f, cx + u * 0.8f, cy + u * 0.8f, p)
                s.c.drawLine(cx + u * 0.8f, cy - u * 0.8f, cx - u * 0.8f, cy + u * 0.8f, p)
            }
            "warn" -> {
                s.c.drawLine(cx, cy - u, cx, cy + u * 0.25f, p)
                s.c.drawPoint(cx, cy + u * 0.85f, p)
            }
            else -> s.c.drawCircle(cx, cy, u * 0.35f, paint(color))
        }
    }

    // ---------------------------------------------------------------- widgets

    /** CPU / RAM / disk as three rings. */
    fun ringsWidget(s: Scene, m: Machine?) {
        background(s)
        if (m == null) return centered(s, "Scegli una macchina", WidgetData.MUTED)
        val d = s.d
        val pad = (s.h * 0.12f).coerceIn(5 * d, 10 * d)
        val up = m.isUp
        val vals = if (up) listOf(m.cpu, m.mem, m.disk) else listOf(null, null, null)
        val cols = listOf(WidgetData.BLUE, WidgetData.GREEN, WidgetData.ORANGE)

        if (s.w / s.h < 1.5f) { // square-ish: ring on top, name below
            val nameSize = (s.h * 0.16f).coerceIn(8 * d, 13 * d)
            val dia = min(s.w - 2 * pad, s.h - 2 * pad - nameSize * 1.5f).coerceAtLeast(10 * d)
            rings(s.c, s.w / 2, pad + dia / 2, dia, vals, cols)
            if (up && dia >= 34 * d && m.cpu != null) {
                val t = "${m.cpu.toInt()}"
                s.c.drawText(t, s.w / 2, pad + dia / 2 + dia * 0.1f, paint(WHITE, dia * 0.26f, true, Paint.Align.CENTER))
            }
            nameLine(s, m, s.w / 2, s.h - pad, nameSize, s.w - 2 * pad, true)
            return
        }

        val dia = min(s.h - 2 * pad, s.w * 0.45f)
        rings(s.c, pad + dia / 2, s.h / 2, dia, vals, cols)
        val tx = pad + dia + pad * 1.3f
        val tw = s.w - tx - pad
        val nameSize = (s.h * 0.2f).coerceIn(11 * d, 16 * d)

        if (s.h < 80 * d) { // 2x1: name, then CPU + temperature on one line
            val size = nameSize * 0.92f
            val total = nameSize * 1.25f + size
            val y0 = (s.h - total) / 2
            nameLine(s, m, tx, y0 + nameSize, nameSize, tw, false)
            val cpuText = if (up) WidgetData.pct(m.cpu) else WidgetData.stateLabel(m)
            val cp = fit(paint(if (up) WidgetData.BLUE else WidgetData.statusColor(m), size, true), cpuText, tw, size, 7 * d)
            val base = y0 + nameSize * 1.25f + size * 0.85f
            s.c.drawText(cpuText, tx, base, cp)
            if (up && m.temp != null) {
                val t = "${m.temp.toInt()}°"
                val x2 = tx + cp.measureText(cpuText) + 6 * d
                val tp = fit(paint(WidgetData.MUTED, size * 0.95f), t, s.w - x2 - pad, size * 0.95f, 7 * d)
                if (x2 + tp.measureText(t) <= s.w - pad + 1) s.c.drawText(t, x2, base, tp)
            }
        } else { // taller: one row per metric, as many as fit
            val rowSize = (s.h * 0.13f).coerceIn(10 * d, 14 * d)
            val rowH = rowSize * 1.4f
            val rows = if (up) listOfNotNull(
                Triple("CPU", WidgetData.pct(m.cpu), WidgetData.BLUE),
                Triple("RAM", WidgetData.pct(m.mem), WidgetData.GREEN),
                Triple("Disco", WidgetData.pct(m.disk), WidgetData.ORANGE),
                m.temp?.let { Triple("Temp", "${it.toInt()}°C", WidgetData.MUTED) },
            ) else listOf(Triple("Stato", WidgetData.stateLabel(m), WidgetData.statusColor(m)))
            val n = floor((s.h - 2 * pad - nameSize * 1.4f) / rowH).toInt().coerceIn(1, rows.size)
            val total = nameSize * 1.4f + n * rowH
            val y0 = (s.h - total) / 2
            nameLine(s, m, tx, y0 + nameSize, nameSize, tw, false)
            for (i in 0 until n) {
                val (label, value, color) = rows[i]
                val base = y0 + nameSize * 1.4f + (i + 1) * rowH - rowH * 0.25f
                s.c.drawText(label, tx, base, fit(paint(WidgetData.MUTED, rowSize), label, tw * 0.5f, rowSize, 7 * d))
                s.c.drawText(value, tx + tw, base, fit(paint(color, rowSize, true, Paint.Align.RIGHT), value, tw * 0.5f, rowSize, 7 * d))
            }
        }
    }

    /** One machine block inside the rect (x, y, w, h): name with status dot, then three stacked bars. */
    private fun barsIn(s: Scene, m: Machine, x: Float, y: Float, w: Float, h: Float) {
        val d = s.d
        val up = m.isUp
        val nameSize = (h * 0.22f).coerceIn(9 * d, 15 * d)

        // Header: right side shows temperature, or the state when not online.
        val right = when {
            !up -> WidgetData.stateLabel(m) to WidgetData.statusColor(m)
            m.temp != null && w >= 85 * d -> "${m.temp.toInt()}°" to WidgetData.MUTED
            else -> null
        }
        var nameMax = w
        if (right != null) {
            val rp = paint(right.second, nameSize * 0.9f, true, Paint.Align.RIGHT)
            s.c.drawText(right.first, x + w, y + nameSize, rp)
            nameMax -= rp.measureText(right.first) + 6 * d
        }
        nameLine(s, m, x, y + nameSize, nameSize, nameMax, false)

        val top = y + nameSize * 1.3f
        val rh = (y + h - top) / 3f
        val barH = (rh * 0.42f).coerceIn(3 * d, 9 * d)
        val fs = (rh * 0.78f).coerceIn(6.5f * d, 12 * d)
        val wide = w >= 140 * d
        val rows = listOf(
            Triple(if (wide) "CPU" else "C", m.cpu, WidgetData.BLUE),
            Triple(if (wide) "RAM" else "R", m.mem, WidgetData.GREEN),
            Triple(if (wide) "DSK" else "D", m.disk, WidgetData.ORANGE),
        )
        val lp = paint(WidgetData.MUTED, fs)
        val vp = paint(WHITE, fs, true, Paint.Align.RIGHT)
        val lw = lp.measureText(if (wide) "RAM" else "R") + 4 * d
        val vw = vp.measureText("100%") + 2 * d
        val x0 = x + lw
        val x1 = x + w - vw
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x2EFFFFFF }
        rows.forEachIndexed { i, (label, v, color) ->
            val cy = top + rh * i + rh / 2
            s.c.drawText(label, x, cy + fs * 0.35f, lp)
            val bar = RectF(x0, cy - barH / 2, x1, cy + barH / 2)
            s.c.drawRoundRect(bar, barH / 2, barH / 2, track)
            if (up && v != null) {
                val fill = RectF(x0, bar.top, x0 + max(barH, (x1 - x0) * (v / 100.0).toFloat().coerceIn(0f, 1f)), bar.bottom)
                s.c.drawRoundRect(fill, barH / 2, barH / 2, paint(if (v >= 90) WidgetData.RED else color))
            }
            s.c.drawText(if (up) WidgetData.pct(v) else "–", x + w, cy + fs * 0.35f, vp)
        }
    }

    /** One machine: name with status dot and CPU / RAM / disk as stacked bars. */
    fun barsWidget(s: Scene, m: Machine?) {
        background(s)
        if (m == null) return centered(s, "Scegli una macchina", WidgetData.MUTED)
        val pad = (s.h * 0.12f).coerceIn(5 * s.d, 10 * s.d)
        barsIn(s, m, pad, pad, s.w - 2 * pad, s.h - 2 * pad)
    }

    /** Every machine as a stacked block (name + three bars); as many as fit, problems first. */
    fun fleetBarsWidget(s: Scene, all: List<Machine>) {
        background(s)
        if (all.isEmpty()) return centered(s, "Apri l'app", WidgetData.MUTED)
        val d = s.d
        val sorted = all.sortedWith(compareBy({ it.status == "up" }, { it.name.lowercase() }))
        val pad = (min(s.w, s.h) * 0.09f).coerceIn(5 * d, 10 * d)
        val minBlock = 42 * d
        val avail = s.h - 2 * pad
        var k = floor(avail / minBlock).toInt().coerceIn(1, sorted.size)
        val footer = if (sorted.size > k && k > 1) 11 * d else 0f
        if (footer > 0f) k = floor((avail - footer) / minBlock).toInt().coerceIn(1, sorted.size)
        val blockH = min((avail - if (sorted.size > k) footer else 0f) / k, 74 * d)
        val gap = 5 * d
        for (i in 0 until k) {
            val y = pad + i * blockH
            if (i > 0) s.c.drawLine(pad, y - gap / 2, s.w - pad, y - gap / 2, Paint().apply { color = 0x14FFFFFF; strokeWidth = d })
            barsIn(s, sorted[i], pad, y, s.w - 2 * pad, blockH - gap)
        }
        if (sorted.size > k) {
            s.c.drawText("+${sorted.size - k} altre", s.w - pad, s.h - pad * 0.7f, paint(WidgetData.MUTED, 9 * d, false, Paint.Align.RIGHT))
        }
    }

    /** Badge + two lines of text, or badge above a short label on tiny grids. */
    private fun badgeTile(s: Scene, accent: Int?, color: Int, symbol: String, line1: String, line1Color: Int, line2: String) {
        background(s, accent)
        val d = s.d
        val pad = (s.h * 0.13f).coerceIn(5 * d, 11 * d)
        if (s.w / s.h < 1.5f) {
            val size = (s.h * 0.16f).coerceIn(8 * d, 13 * d)
            val dia = min(s.w - 2 * pad, s.h - 2 * pad - size * 1.5f).coerceAtLeast(12 * d)
            badge(s, s.w / 2, pad + dia / 2, dia, color, symbol)
            val p = fit(paint(line1Color, size, true, Paint.Align.CENTER), line1, s.w - 2 * pad, size, 7 * d)
            s.c.drawText(line1, s.w / 2, s.h - pad, p)
            return
        }
        val dia = min(s.h - 2 * pad, 46 * d)
        badge(s, pad + dia / 2, s.h / 2, dia, color, symbol)
        val tx = pad + dia + pad
        val tw = s.w - tx - pad
        val size = (s.h * 0.26f).coerceIn(12 * d, 18 * d)
        val sub = size * 0.78f
        val total = size * 1.3f + sub
        val y0 = (s.h - total) / 2
        s.c.drawText(line1, tx, y0 + size, fit(paint(line1Color, size, true), line1, tw, size, 8 * d))
        if (line2.isNotEmpty()) s.c.drawText(line2, tx, y0 + size * 1.3f + sub * 0.85f, fit(paint(WidgetData.MUTED, sub), line2, tw, sub, 7 * d))
    }

    /** Only the online/offline state of one machine. */
    fun statusWidget(s: Scene, m: Machine?) {
        if (m == null) return badgeTile(s, null, WidgetData.MUTED, "none", "Scegli", WidgetData.MUTED, "Tocca per configurare")
        val c = WidgetData.statusColor(m)
        val symbol = if (m.isUp) "ok" else if (m.status == "down") "err" else "none"
        // Square grids show the machine name under the badge; wide ones show name + state.
        if (s.w / s.h < 1.5f) badgeTile(s, if (m.status == "down") WidgetData.RED else null, c, symbol, m.name, WidgetData.statusColor(m), "")
        else badgeTile(s, if (m.status == "down") WidgetData.RED else null, c, symbol, m.name, 0xFFF4F4F5.toInt(), WidgetData.stateLabel(m))
    }

    /** "Is everything fine?" tile. */
    fun overallWidget(s: Scene, all: List<Machine>, alerts: Int) {
        val up = all.count { it.isUp }
        val down = all.count { it.status == "down" }
        val title: String
        val color: Int
        val symbol: String
        when {
            all.isEmpty() -> { title = "Apri l'app"; color = WidgetData.MUTED; symbol = "none" }
            down == 0 && alerts == 0 -> { title = "Tutto ok"; color = WidgetData.GREEN; symbol = "ok" }
            down == 0 -> { title = if (alerts == 1) "1 avviso" else "$alerts avvisi"; color = WidgetData.ORANGE; symbol = "warn" }
            else -> { title = "$down offline"; color = WidgetData.RED; symbol = "err" }
        }
        val sub = if (all.isEmpty()) "" else "$up/${all.size} online" + if (alerts > 0 && down > 0) " · $alerts avvisi" else ""
        badgeTile(s, if (all.isEmpty()) null else color, color, symbol, title, color, sub)
    }
}
