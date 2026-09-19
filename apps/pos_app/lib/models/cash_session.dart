class CashMovement {
  final String tipo;
  final double monto;
  final String? motivo;

  CashMovement({required this.tipo, required this.monto, required this.motivo});

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
        tipo: json['tipo'] as String,
        monto: (json['monto'] as num).toDouble(),
        motivo: json['motivo'] as String?,
      );
}

class CashSession {
  final String id;
  final double fondoInicial;
  final DateTime abiertoEn;
  final List<CashMovement> movimientos;

  CashSession({
    required this.id,
    required this.fondoInicial,
    required this.abiertoEn,
    required this.movimientos,
  });

  factory CashSession.fromJson(Map<String, dynamic> json) => CashSession(
        id: json['id'] as String,
        fondoInicial: (json['fondoInicial'] as num).toDouble(),
        abiertoEn: DateTime.parse(json['abiertoEn'] as String),
        movimientos: (json['movimientos'] as List<dynamic>? ?? [])
            .map((e) => CashMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CashSessionClosed {
  final double efectivoContado;
  final double efectivoEsperado;
  final double diferencia;

  CashSessionClosed({
    required this.efectivoContado,
    required this.efectivoEsperado,
    required this.diferencia,
  });

  factory CashSessionClosed.fromJson(Map<String, dynamic> json) => CashSessionClosed(
        efectivoContado: (json['efectivoContado'] as num).toDouble(),
        efectivoEsperado: (json['efectivoEsperado'] as num).toDouble(),
        diferencia: (json['diferencia'] as num).toDouble(),
      );
}
