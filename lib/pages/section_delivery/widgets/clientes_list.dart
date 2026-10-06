import 'package:flutter/material.dart';
import '../../../data/database.dart';
import '../../nuevo_cliente_page.dart';

class ClientesList extends StatelessWidget {
  final bool started;
  final bool paused;
  final List<Cliente> clientes;
  final List<bool> esRelleno;
  final List<List<String>> motivos;
  final List<bool> clientesContactados;
  final List<String> clientesEstado; // Estado: 'Rechazó', 'Pendiente', or ''
  final int? selectedClienteIndex;
  final Function(int) onClienteSelected;
  final Function(int) onShowInteraccionSheet;
  final Function() onResumeDelivery;

  const ClientesList({
    Key? key,
    required this.started,
    required this.paused,
    required this.clientes,
    required this.esRelleno,
    this.motivos = const [],
    required this.clientesContactados,
    required this.clientesEstado,
    required this.selectedClienteIndex,
    required this.onClienteSelected,
    required this.onShowInteraccionSheet,
    required this.onResumeDelivery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calcular padding dinámico basado en el tamaño de la pantalla
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomListPadding = screenHeight * 0.12; // 12% para el bottom de la lista

    return Column(
      children: [
        if (started)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  itemCount: clientes.length,
                  padding: EdgeInsets.only(bottom: bottomListPadding),
                  itemBuilder: (context, index) {
                    final cliente = clientes[index];
                    final contactado = clientesContactados[index];
                    return ListTile(
                      key: ValueKey(cliente.id),
                      subtitle: index < motivos.length
                          ? _Etiquetas(etiquetas: motivos[index])
                          : null,
                      onTap: () {
                        if (paused) onResumeDelivery();
                        onShowInteraccionSheet(index);
                      },
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(cliente.nombre, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              onClienteSelected(index);
                            },
                            child: Icon(
                              clientesEstado[index] == 'Rechazó'
                                  ? Icons.close
                                  : clientesEstado[index] == 'Pendiente'
                                  ? Icons.help_outline
                                  : contactado
                                  ? Icons.check_circle_outline
                                  : Icons.search,
                              color: clientesEstado[index] == 'Rechazó'
                                  ? Colors.red
                                  : clientesEstado[index] == 'Pendiente'
                                  ? Colors.blue
                                  : contactado
                                  ? Colors.green
                                  : Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () async {
                              if (paused) onResumeDelivery();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      NuevoClientePage(cliente: cliente),
                                ),
                              );
                            },
                            child: const Icon(Icons.edit, color: Colors.orange),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fila de etiquetas compactas: motivo, día predilecto y kg habituales.
class _Etiquetas extends StatelessWidget {
  final List<String> etiquetas;

  const _Etiquetas({required this.etiquetas});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (i, etiqueta) in etiquetas.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: i == 0
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 11,
                  color: i == 0
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
