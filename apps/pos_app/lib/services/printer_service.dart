import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class PrinterService {
  Future<List<BluetoothInfo>> pairedPrinters() {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connect(String macAddress) {
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<List<int>> buildTicketBytes({
    required SaleResult sale,
    required String nombreTienda,
    String? piePagina,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    bytes.addAll(generator.text(
      nombreTienda,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      _dateFormat.format(sale.fecha),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text('Ticket #${sale.numeroTicket}',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());

    for (final item in sale.items) {
      bytes.addAll(generator.text(item.nombreProducto));
      bytes.addAll(generator.row([
        PosColumn(text: '${item.cantidad.toStringAsFixed(0)} x ${_currency.format(item.precioUnitario)}', width: 8),
        PosColumn(
          text: _currency.format(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: _currency.format(sale.total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));

    if (sale.montoRecibido != null) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Recibido', width: 6),
        PosColumn(text: _currency.format(sale.montoRecibido!), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    if (sale.cambio != null) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Cambio', width: 6),
        PosColumn(text: _currency.format(sale.cambio!), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.feed(1));
    if (piePagina != null && piePagina.trim().isNotEmpty) {
      bytes.addAll(generator.text(piePagina, styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  Future<bool> printTicket(List<int> bytes) {
    return PrintBluetoothThermal.writeBytes(bytes);
  }
}
