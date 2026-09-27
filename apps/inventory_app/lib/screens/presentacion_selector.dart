import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import 'select_product_dialog.dart';

class PresentacionSeleccion {
  final bool activo;
  final String? baseId;
  final double? factor;

  const PresentacionSeleccion({required this.activo, this.baseId, this.factor});

  /// Mensaje de error si está activa pero incompleta; null si es válida.
  String? get error {
    if (!activo) return null;
    if (baseId == null) return 'Elige de qué producto es el paquete';
    if (factor == null || factor! <= 0) return 'Indica cuántas unidades trae el paquete';
    return null;
  }
}

/// Permite marcar un producto como caja/paquete de N unidades de otro producto.
class PresentacionSelector extends StatefulWidget {
  final ApiClient api;
  final String? excluirId;
  final String? baseIdInicial;
  final String? baseNombreInicial;
  final double factorInicial;
  final ValueChanged<PresentacionSeleccion> onChanged;

  const PresentacionSelector({
    super.key,
    required this.api,
    required this.onChanged,
    this.excluirId,
    this.baseIdInicial,
    this.baseNombreInicial,
    this.factorInicial = 1,
  });

  @override
  State<PresentacionSelector> createState() => _PresentacionSelectorState();
}

class _PresentacionSelectorState extends State<PresentacionSelector> {
  late bool _activo = widget.baseIdInicial != null;
  late String? _baseId = widget.baseIdInicial;
  late String? _baseNombre = widget.baseNombreInicial;
  late final _factorController = TextEditingController(
    text: widget.baseIdInicial != null ? widget.factorInicial.toStringAsFixed(0) : '',
  );

  void _emitir() {
    widget.onChanged(PresentacionSeleccion(
      activo: _activo,
      baseId: _baseId,
      factor: double.tryParse(_factorController.text),
    ));
  }

  Future<void> _elegirBase() async {
    final base = await showSelectProductDialog(
      context,
      api: widget.api,
      soloBase: true,
      excluirId: widget.excluirId,
    );
    if (base == null) return;
    setState(() {
      _baseId = base.id;
      _baseNombre = base.nombre;
    });
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Es caja/paquete de otro producto'),
          subtitle: const Text('Trae varias unidades de un producto que también se vende suelto'),
          value: _activo,
          onChanged: (v) {
            setState(() => _activo = v);
            _emitir();
          },
        ),
        if (_activo) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_baseNombre ?? 'Elegir producto unidad…'),
            subtitle: const Text('Producto unidad'),
            trailing: const Icon(Icons.search),
            onTap: _elegirBase,
          ),
          TextField(
            controller: _factorController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Unidades que trae', hintText: 'ej. 12'),
            onChanged: (_) => _emitir(),
          ),
        ],
      ],
    );
  }
}
