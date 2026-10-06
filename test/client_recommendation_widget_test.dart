import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_limones/data/database.dart';
import 'package:prueba_limones/pages/section_delivery/widgets/clientes_list.dart';

void main() {
  testWidgets('Muestra motivos legibles sin el icono de relleno', (
    tester,
  ) async {
    final clients = List.generate(
      3,
      (i) => Cliente.fromJson(
        jsonDecode('''{
      "id": ${i + 1}, "nombre": "Cliente ${i + 1}", "contacto": "",
      "tipoNegocio": "", "ciudad": "", "domicilio": "", "ubicacion": "",
      "telefono": "", "consumo": 0, "ultimoContacto": 0,
      "horaInicio": 0, "horaCierre": 24, "dias": "", "eventos": 0,
      "kgTotal": 0.0, "moda": 0.0, "maximo": 0.0, "ultimas10": 0.0,
      "kgEvento": 0.0, "kgSemana": 0.0, "ventasVuelta": 0.0,
      "puntuacion": 0.0, "sellerId": 1
    }''')
            as Map<String, dynamic>,
      ),
    );
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientesList(
            started: true,
            paused: false,
            clientes: clients,
            esRelleno: const [false, true, true],
            motivos: const [
              ['Recompra', 'Lunes', '20kg'],
              ['Seguimiento', 'Viernes', '12.5kg'],
              ['Reactivación', 'Martes', '30kg'],
            ],
            clientesContactados: const [false, false, false],
            clientesEstado: const ['', '', ''],
            selectedClienteIndex: null,
            onClienteSelected: (_) {},
            onShowInteraccionSheet: (i) => selected = i,
            onResumeDelivery: () {},
          ),
        ),
      ),
    );
    expect(find.text('Recompra'), findsOneWidget);
    expect(find.text('Seguimiento'), findsOneWidget);
    expect(find.text('Reactivación'), findsOneWidget);
    expect(find.text('Viernes'), findsOneWidget);
    expect(find.text('12.5kg'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsNothing);
    await tester.tap(find.text('Cliente 2'));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
