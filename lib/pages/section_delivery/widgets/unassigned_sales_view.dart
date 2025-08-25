import 'package:flutter/material.dart';
import '../../../services/database_service.dart';

class UnassignedSalesView extends StatefulWidget {
  final int deliveryNumber;

  const UnassignedSalesView({Key? key, required this.deliveryNumber})
    : super(key: key);

  @override
  _UnassignedSalesViewState createState() => _UnassignedSalesViewState();
}

class _UnassignedSalesViewState extends State<UnassignedSalesView> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _unassignedSales = [];
  final Set<int> _selectedSales = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadUnassignedSales();
  }

  Future<void> _loadUnassignedSales() async {
    try {
      await _databaseService.init();
      final unassignedSales = await _databaseService.getUnassignedSales();

      // Get client names
      final allClientes = await _databaseService.getAllClientes();
      final clientMap = {
        for (var client in allClientes) client.id: client.contacto,
      };

      setState(() {
        _unassignedSales = unassignedSales.map((sale) {
          return {
            'id': sale.id,
            'clientId': sale.clientId,
            'clientName': clientMap[sale.clientId] ?? 'Desconocido',
            'quantity': sale.quantity,
            'price': sale.price,
            'total': sale.total,
            'date': sale.date,
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar ventas: $e')));
    }
  }

  Future<void> _assignSelectedSales() async {
    if (_selectedSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos una venta'),
        ),
      );
      return;
    }

    try {
      await _databaseService.init();
      final updatedCount = await _databaseService.assignSalesToDelivery(
        saleIds: _selectedSales.toList(),
        deliveryNumber: widget.deliveryNumber,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$updatedCount ventas asignadas al reparto #${widget.deliveryNumber}',
          ),
        ),
      );

      // Regresar a la vista anterior y refrescar
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al asignar ventas: $e')));
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedSales.addAll(_unassignedSales.map((sale) => sale['id']));
      } else {
        _selectedSales.clear();
      }
    });
  }

  void _toggleSaleSelection(int saleId) {
    setState(() {
      if (_selectedSales.contains(saleId)) {
        _selectedSales.remove(saleId);
      } else {
        _selectedSales.add(saleId);
      }
      // Actualizar el estado de "seleccionar todas"
      _selectAll = _selectedSales.length == _unassignedSales.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas No Asignadas'),
        actions: [
          if (_selectedSales.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _assignSelectedSales,
              tooltip: 'Asignar ventas seleccionadas',
            ),
        ],
      ),
      body: _unassignedSales.isEmpty
          ? const Center(child: Text('No hay ventas sin asignar'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Reparto #${widget.deliveryNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('ID')),
                        const DataColumn(label: Text('Cliente')),
                        const DataColumn(label: Text('Cantidad')),
                        const DataColumn(label: Text('Precio')),
                        const DataColumn(label: Text('Total')),
                        const DataColumn(label: Text('Fecha')),
                      ],
                      rows: _unassignedSales.map((sale) {
                        return DataRow(
                          selected: _selectedSales.contains(sale['id']),
                          onSelectChanged: (selected) {
                            _toggleSaleSelection(sale['id']);
                          },
                          cells: [
                            DataCell(Text(sale['id'].toString())),
                            DataCell(Text(sale['clientName'])),
                            DataCell(Text(sale['quantity'].toString())),
                            DataCell(
                              Text('\$${sale['price'].toStringAsFixed(0)}'),
                            ),
                            DataCell(
                              Text('\$${sale['total'].toStringAsFixed(0)}'),
                            ),
                            DataCell(
                              Text(
                                '${sale['date'].day}/${sale['date'].month}/${sale['date'].year}',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
