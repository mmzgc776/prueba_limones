import 'package:flutter/material.dart';

class ClienteInfoCard extends StatefulWidget {
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
  State<ClienteInfoCard> createState() => _ClienteInfoCardState();
}

class _ClienteInfoCardState extends State<ClienteInfoCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.selectedClienteIndex == null ||
        !widget.started ||
        widget.clientes.isEmpty ||
        widget.selectedClienteIndex! >= widget.clientes.length)
      return const SizedBox.shrink();
    final idx = widget.selectedClienteIndex!;
    final cliente = widget.clientes[idx];

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    cliente.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  tooltip: _isExpanded ? 'Contraer' : 'Ver métricas',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(cliente.domicilio ?? 'Domicilio no disponible'),
            const SizedBox(height: 4),
            Text(cliente.tipoNegocio ?? 'Tipo de negocio no disponible'),
            Text(cliente.ciudad ?? 'Ciudad no disponible'),

            // Métricas expandibles
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Métricas del Cliente',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.deepPurple.shade700,
                ),
              ),
              const SizedBox(height: 12),

              // Grid de métricas
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricChip(
                    context,
                    icon: Icons.star,
                    label: 'Puntuación',
                    value: cliente.puntuacion?.toStringAsFixed(1) ?? '0.0',
                    color: Colors.amber,
                  ),
                  _buildMetricChip(
                    context,
                    icon: Icons.event,
                    label: 'Eventos',
                    value: '${cliente.eventos ?? 0}',
                    color: Colors.blue,
                  ),
                  _buildMetricChip(
                    context,
                    icon: Icons.scale,
                    label: 'Kg/Evento',
                    value: (cliente.kgEvento ?? 0).toStringAsFixed(1),
                    color: Colors.green,
                  ),
                  _buildMetricChip(
                    context,
                    icon: Icons.trending_up,
                    label: 'Moda',
                    value: '${(cliente.moda ?? 0).toStringAsFixed(1)} kg',
                    color: Colors.purple,
                  ),
                  _buildMetricChip(
                    context,
                    icon: Icons.history,
                    label: 'Últimas 10',
                    value: '${((cliente.ultimas10 ?? 0) * 100).toStringAsFixed(0)}%',
                    color: Colors.orange,
                  ),
                  _buildMetricChip(
                    context,
                    icon: Icons.shopping_cart,
                    label: 'Ventas/Vuelta',
                    value: (cliente.ventasVuelta ?? 0).toStringAsFixed(2),
                    color: Colors.teal,
                  ),
                  _buildMetricChip(
                    context,
                    icon: Icons.arrow_upward,
                    label: 'Máximo',
                    value: '${(cliente.maximo ?? 0).toStringAsFixed(1)} kg',
                    color: Colors.red,
                  ),
                  _buildMetricChip(
                    context,
                    icon: Icons.inventory,
                    label: 'Total Histórico',
                    value: '${(cliente.kgTotal ?? 0).toStringAsFixed(1)} kg',
                    color: Colors.indigo,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
