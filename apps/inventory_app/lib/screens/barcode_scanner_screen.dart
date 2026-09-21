import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla de escaneo; devuelve el código detectado con [Navigator.pop] o
/// `null` si el usuario cancela.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código de barras')),
      body: MobileScanner(
        onDetect: _onDetect,
        // El paquete mobile_scanner oculta el detalle real del error en modo
        // release (siempre muestra "An unexpected error occurred"); esta app
        // es interna, así que conviene ver siempre la causa real.
        errorBuilder: (context, error, child) => _CameraErrorView(error: error),
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  final MobileScannerException error;

  const _CameraErrorView({required this.error});

  String get _mensaje {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'No hay permiso de cámara para esta app.\n'
            'Ve a Ajustes del teléfono > Apps > Inventario > Permisos y activa la cámara.';
      case MobileScannerErrorCode.unsupported:
        return 'Este dispositivo no tiene una cámara utilizable para escanear.';
      default:
        return 'No se pudo abrir la cámara (${error.errorCode.name}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              Text(
                _mensaje,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (error.errorDetails?.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.errorDetails!.message!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
