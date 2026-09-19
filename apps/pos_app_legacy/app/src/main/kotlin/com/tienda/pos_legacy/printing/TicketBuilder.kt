package com.tienda.pos_legacy.printing

import com.tienda.pos_legacy.model.SaleResult
import java.io.ByteArrayOutputStream
import java.text.NumberFormat
import java.util.Locale

/** Construye los bytes ESC/POS de un ticket de venta a mano (sin depender de una librería externa). */
object TicketBuilder {
    private val ESC = 0x1B
    private val GS = 0x1D
    private val currency = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-CO")).apply {
        maximumFractionDigits = 0
    }

    private fun align(out: ByteArrayOutputStream, mode: Int) {
        out.write(ESC); out.write(0x61); out.write(mode) // 0=izq, 1=centro, 2=der
    }

    private fun bold(out: ByteArrayOutputStream, on: Boolean) {
        out.write(ESC); out.write(0x45); out.write(if (on) 1 else 0)
    }

    private fun textLine(out: ByteArrayOutputStream, text: String) {
        out.write(text.toByteArray(Charsets.ISO_8859_1))
        out.write('\n'.code)
    }

    private fun feed(out: ByteArrayOutputStream, lines: Int) {
        out.write(ESC); out.write(0x64); out.write(lines)
    }

    private fun cut(out: ByteArrayOutputStream) {
        out.write(GS); out.write(0x56); out.write(1)
    }

    private fun row(out: ByteArrayOutputStream, left: String, right: String, width: Int = 32) {
        val space = (width - left.length - right.length).coerceAtLeast(1)
        textLine(out, left + " ".repeat(space) + right)
    }

    fun build(sale: SaleResult, nombreTienda: String, piePagina: String?): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(ESC); out.write(0x40) // init

        align(out, 1)
        bold(out, true)
        textLine(out, nombreTienda)
        bold(out, false)
        textLine(out, sale.fecha.replace("T", " ").take(16))
        textLine(out, "Ticket #${sale.numeroTicket}")
        align(out, 0)
        textLine(out, "-".repeat(32))

        for (item in sale.items) {
            textLine(out, item.nombreProducto)
            row(
                out,
                "${item.cantidad.toInt()} x ${currency.format(item.precioUnitario)}",
                currency.format(item.subtotal),
            )
        }

        textLine(out, "-".repeat(32))
        bold(out, true)
        row(out, "TOTAL", currency.format(sale.total))
        bold(out, false)

        sale.montoRecibido?.let { row(out, "Recibido", currency.format(it)) }
        sale.cambio?.let { row(out, "Cambio", currency.format(it)) }

        feed(out, 1)
        if (!piePagina.isNullOrBlank()) {
            align(out, 1)
            textLine(out, piePagina)
        }
        feed(out, 3)
        cut(out)

        return out.toByteArray()
    }
}
