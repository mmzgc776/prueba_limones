import 'package:flutter/material.dart';
import '../../../data/database.dart';
import '../../../services/database_service.dart';
import '../../../data/delivery_state.dart';
import '../../../services/delivery_service.dart';

/// Widget que muestra el progreso del reparto actual:
/// - Lista de ventas realizadas
/// - Lista de interacciones con clientes (con resultados)
class DeliveryProgressView extends StatefulWidget {
  const DeliveryProgressView({Key? key}) : super(key: key);

  @override
  State<DeliveryProgressView> createState() => _DeliveryProgressViewState();
}

class _DeliveryProgressViewState extends State<DeliveryProgressView> {
  final DatabaseService _dbService = DatabaseService();
  final DeliveryStateManager _stateManager = DeliveryStateManager();

  List<Sale> _sales = [];
  List<Interaccione> _interacciones = [];
  Map<int, Cliente> _clientesMap = {};
  Delivery? _delivery;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _dbService.init();
      final deliveryNumber = _stateManager.getCurrentDeliveryNumber();

      if (deliveryNumber != null) {
        // Cargar ventas del reparto actual
        final sales = await _dbService.getSalesByDeliveryNumber(deliveryNumber);

        // Cargar interacciones del reparto actual
        final interacciones = await _dbService.getInteraccionesByDeliveryNumber(
          deliveryNumber,
        );

        // Cargar información del delivery
        final delivery = await _dbService.getDeliveryByNumber(deliveryNumber);

        // Cargar información de clientes
        final clientIds = <int>{
          ...sales.map((s) => s.clientId),
          ...interacciones.map((i) => i.clientId),
        };

        final clientesMap = <int, Cliente>{};
        for (final clientId in clientIds) {
          final cliente = await _dbService.getClienteById(clientId);
          if (cliente != null) {
            clientesMap[clientId] = cliente;
          }
        }

        setState(() {
          _sales = sales;
          _interacciones = interacciones;
          _clientesMap = clientesMap;
          _delivery = delivery;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error cargando datos del reparto: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final deliveryNumber = _stateManager.getCurrentDeliveryNumber();

    if (deliveryNumber == null) {
      return const Center(child: Text('No hay un reparto activo'));
    }

    final totalVentas = _sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final totalKg = _sales.fold<double>(0, (sum, sale) => sum + sale.quantity);

    // Calcular progreso de cajas
    String progressText = 'N/A';
    String progressLabel = 'Progreso';
    final totalBoxes = _delivery?.boxes ?? _stateManager.initialBoxes;
    if (totalBoxes != null && totalBoxes > 0) {
      final completedBoxes = totalKg / 17.0;
      final percentage = (completedBoxes / totalBoxes) * 100;
      final remainingBoxes = totalBoxes - completedBoxes;
      final remainingPercentage = 100 - percentage;
      progressText =
          '${percentage.toStringAsFixed(0)}% (${completedBoxes.toStringAsFixed(0)} cajas)\n${remainingPercentage.toStringAsFixed(0)}% (${remainingBoxes.toStringAsFixed(0)} cajas)';
      progressLabel = 'Quedan ${remainingBoxes.toStringAsFixed(0)}c';
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reparto #$deliveryNumber',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          context,
                          'Ventas',
                          Text(
                            _sales.length.toString(),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          Icons.shopping_cart,
                        ),
                        _buildSummaryItem(
                          context,
                          'Interacciones',
                          Text(
                            _interacciones.length.toString(),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          Icons.people,
                        ),
                        _buildSummaryItem(
                          context,
                          'Total',
                          Text(
                            '\$${totalVentas.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          Icons.attach_money,
                        ),
                        _buildSummaryItem(
                          context,
                          'Kg',
                          Text(
                            totalKg.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          Icons.scale,
                        ),
                        _buildSummaryItem(
                          context,
                          progressLabel,
                          _buildProgressWidget(context, progressText),
                          Icons.inventory,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Lista de Ventas
            Text(
              'Ventas Realizadas (${_sales.length})',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_sales.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No hay ventas registradas aún',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              ...(_sales.map((sale) => _buildSaleCard(context, sale))),

            const SizedBox(height: 24),

            // Lista de Interacciones
            Text(
              'Interacciones con Clientes (${_interacciones.length})',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_interacciones.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No hay interacciones registradas aún',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              ...(_interacciones.map(
                (interaccion) => _buildInteraccionCard(context, interaccion),
              )),

            const SizedBox(height: 80), // Espacio para el FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    Widget value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        value,
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSaleCard(BuildContext context, Sale sale) {
    final cliente = _clientesMap[sale.clientId];
    final clienteNombre = cliente?.nombre ?? 'Cliente desconocido';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.shopping_bag, color: Colors.green[700]),
        ),
        title: Text(
          clienteNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${sale.quantity.toStringAsFixed(1)} kg × \$${sale.price.toStringAsFixed(2)}',
        ),
        trailing: Text(
          '\$${sale.total.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressWidget(BuildContext context, String progressText) {
    if (progressText == 'N/A') {
      return const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(value: 0, strokeWidth: 4),
      );
    }

    final lines = progressText.split('\n');
    if (lines.length == 2) {
      final completedPercent = double.tryParse(lines[0].split('%')[0]) ?? 0;
      final progressValue = completedPercent / 100;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: progressValue,
              strokeWidth: 4,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progressValue < 0.5 ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${completedPercent.toStringAsFixed(0)}%',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return const SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(value: 0, strokeWidth: 4),
    );
  }

  Widget _buildInteraccionCard(BuildContext context, Interaccione interaccion) {
    final cliente = _clientesMap[interaccion.clientId];
    final clienteNombre = cliente?.nombre ?? 'Cliente desconocido';

    // Determinar color e icono según el resultado
    Color color;
    IconData icon;
    switch (interaccion.result) {
      case 'Venta':
        color = Colors.green;
        icon = Icons.shopping_cart;
        break;
      case 'Rechazó':
        color = Colors.red;
        icon = Icons.close;
        break;
      case 'Encargó':
        color = Colors.orange;
        icon = Icons.schedule;
        break;
      case 'Pendiente':
        color = Colors.blue;
        icon = Icons.pending_actions;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          clienteNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Chip(
          label: Text(
            interaccion.result,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: color,
        ),
      ),
    );
  }
}
