import 'package:flutter/material.dart';
import '../../../data/database.dart';
import '../../../services/database_service.dart';
import '../../../data/delivery_state.dart';

/// Widget que muestra el progreso del reparto actual:
/// - Lista de ventas realizadas
/// - Lista de clientes contactados (con resultados)
class DeliveryProgressView extends StatefulWidget {
  const DeliveryProgressView({Key? key}) : super(key: key);

  @override
  State<DeliveryProgressView> createState() => _DeliveryProgressViewState();
}

class _DeliveryProgressViewState extends State<DeliveryProgressView> {
  final DatabaseService _dbService = DatabaseService();
  final DeliveryStateManager _stateManager = DeliveryStateManager();

  List<Sale> _sales = [];
  List<Contacto> _contactos = [];
  Map<int, Cliente> _clientesMap = {};
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

        // Cargar contactos del reparto actual
        final contactos =
            await _dbService.getContactosByDeliveryNumber(deliveryNumber);

        // Cargar información de clientes
        final clientIds = <int>{
          ...sales.map((s) => s.clientId),
          ...contactos.map((c) => c.clientId),
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
          _contactos = contactos;
          _clientesMap = clientesMap;
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
      return const Center(
        child: Text('No hay un reparto activo'),
      );
    }

    final totalVentas = _sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final totalKg = _sales.fold<double>(0, (sum, sale) => sum + sale.quantity);

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
                          _sales.length.toString(),
                          Icons.shopping_cart,
                        ),
                        _buildSummaryItem(
                          context,
                          'Contactos',
                          _contactos.length.toString(),
                          Icons.people,
                        ),
                        _buildSummaryItem(
                          context,
                          'Total',
                          '\$${totalVentas.toStringAsFixed(0)}',
                          Icons.attach_money,
                        ),
                        _buildSummaryItem(
                          context,
                          'Kg',
                          totalKg.toStringAsFixed(1),
                          Icons.scale,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            if (_sales.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No hay ventas registradas aún',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                ),
              )
            else
              ...(_sales.map((sale) => _buildSaleCard(context, sale))),

            const SizedBox(height: 24),

            // Lista de Contactos
            Text(
              'Clientes Contactados (${_contactos.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            if (_contactos.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No hay contactos registrados aún',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                ),
              )
            else
              ...(_contactos.map((contacto) => _buildContactoCard(
                    context,
                    contacto,
                  ))),

            const SizedBox(height: 80), // Espacio para el FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
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

  Widget _buildContactoCard(BuildContext context, Contacto contacto) {
    final cliente = _clientesMap[contacto.clientId];
    final clienteNombre = cliente?.nombre ?? 'Cliente desconocido';

    // Determinar color e icono según el resultado
    Color color;
    IconData icon;
    switch (contacto.result) {
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
            contacto.result,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          backgroundColor: color,
        ),
      ),
    );
  }
}
