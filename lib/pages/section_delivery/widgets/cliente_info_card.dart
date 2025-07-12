import 'package:flutter/material.dart';

class ClienteInfoCard extends StatelessWidget {
  final int? selectedClienteIndex;
  final bool started;
  final List<dynamic> clientes;

  const ClienteInfoCard({
    Key? key,
    required this.selectedClienteIndex,
    required this.started,
    required this.clientes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedClienteIndex == null ||
        !started ||
        clientes.isEmpty ||
        selectedClienteIndex! >= clientes.length)
      return const SizedBox.shrink();
    final idx = selectedClienteIndex!;
    final cliente = clientes[idx];
    return Positioned(
      top: 24,
      left: 24,
      right: 24,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cliente.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(cliente.domicilio ?? 'Domicilio no disponible'),
            const SizedBox(height: 4),
            Text(cliente.tipoNegocio ?? 'Tipo de negocio no disponible'),
            Text(cliente.ciudad ?? 'Ciudad no disponible'),
          ],
        ),
      ),
    );
  }
}
