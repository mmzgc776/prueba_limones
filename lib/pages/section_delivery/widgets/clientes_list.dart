import 'package:flutter/material.dart';
import '../../../data/database.dart';
import '../../nuevo_cliente_page.dart';

class ClientesList extends StatelessWidget {
  final bool started;
  final bool paused;
  final List<Cliente> clientes;
  final List<bool> clientesContactados;
  final List<String> clientesEstado; // Estado: 'Rechazó', 'Pendiente', or ''
  final int? selectedClienteIndex;
  final Function(int) onClienteSelected;
  final Function(int) onShowContactoSheet;
  final Function() onResumeDelivery;

  const ClientesList({
    Key? key,
    required this.started,
    required this.paused,
    required this.clientes,
    required this.clientesContactados,
    required this.clientesEstado,
    required this.selectedClienteIndex,
    required this.onClienteSelected,
    required this.onShowContactoSheet,
    required this.onResumeDelivery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        if (started)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 170,
              ),
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
                  padding: const EdgeInsets.only(bottom: 140),
                  itemBuilder: (context, index) {
                    final cliente = clientes[index];
                    final contactado = clientesContactados[index];
                    return ListTile(
                      onTap: () {
                        onClienteSelected(index);
                      },
                      title: Text(cliente.nombre),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (paused) onResumeDelivery();
                              onShowContactoSheet(index);
                            },
                            child: Icon(
                              clientesEstado[index] == 'Rechazó'
                                  ? Icons.close
                                  : clientesEstado[index] == 'Pendiente'
                                  ? Icons.help_outline
                                  : contactado
                                  ? Icons.check_circle_outline
                                  : Icons.hourglass_empty,
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
