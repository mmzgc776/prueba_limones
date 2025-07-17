import 'package:flutter/material.dart';
import '../delivery_record.dart';
import '../../../services/database_service.dart'; // Adjust path as necessary
import 'unassigned_sales_view.dart';

class DeliveryDetailView extends StatefulWidget {
  final DeliveryRecord deliveryRecord;

  const DeliveryDetailView({Key? key, required this.deliveryRecord})
    : super(key: key);

  @override
  _DeliveryDetailViewState createState() => _DeliveryDetailViewState();
}

class _DeliveryDetailViewState extends State<DeliveryDetailView> {
  late Future<DeliveryRecord> _deliveryRecordFuture;

  @override
  void initState() {
    super.initState();
    _loadDeliveryRecord();
  }

  void _loadDeliveryRecord() {
    _deliveryRecordFuture = _fetchDeliveryRecord();
  }

  Future<DeliveryRecord> _fetchDeliveryRecord() async {
    final dbService = DatabaseService();
    await dbService.init();

    final deliveries = await dbService.getAllDeliveries();
    final delivery = deliveries.firstWhere(
      (d) => d.deliveryNumber == widget.deliveryRecord.deliveryNumber,
    );

    return DeliveryRecord(
      deliveryNumber: delivery.deliveryNumber,
      date: delivery.date,
      duration: Duration(seconds: delivery.durationSeconds),
      avgPrice: delivery.avgPrice,
      kilograms: delivery.kilograms,
      boxes: delivery.boxes,
      remaining: delivery.remaining,
      seller: delivery.seller,
      total: delivery.total,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalle de Reparto #${widget.deliveryRecord.deliveryNumber}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar ventas',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UnassignedSalesView(
                    deliveryNumber: widget.deliveryRecord.deliveryNumber,
                  ),
                ),
              );

              // Si se asignaron ventas, refrescar la vista
              if (result == true) {
                setState(() {
                  _loadDeliveryRecord();
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<DeliveryRecord>(
        future: _deliveryRecordFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No se encontró el reparto'));
          }

          final deliveryRecord = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fecha: ${deliveryRecord.date.day}/${deliveryRecord.date.month}/${deliveryRecord.date.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Duración: ${deliveryRecord.duration.toString().split('.')[0]}',
                ),
                Text(
                  'Precio Promedio: ${deliveryRecord.avgPrice.toStringAsFixed(0)}',
                ),
                Text(
                  'Kilogramos: ${deliveryRecord.kilograms.toStringAsFixed(0)}',
                ),
                Text('Cajas: ${deliveryRecord.boxes}'),
                Text(
                  'Restante: ${deliveryRecord.remaining.toStringAsFixed(0)}',
                ),
                Text('Vendedor: ${deliveryRecord.seller}'),
                Text('Total: ${deliveryRecord.total.toStringAsFixed(0)}'),
                const SizedBox(height: 20),
                const Text(
                  'Lista de Ventas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildSalesList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchSalesData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No hay ventas asociadas a este reparto.'),
          );
        }

        List<Map<String, dynamic>> sales = snapshot.data!;

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          margin: const EdgeInsets.only(bottom: 20),
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Cliente')),
                      DataColumn(label: Text('Cantidad')),
                      DataColumn(label: Text('Precio')),
                      DataColumn(label: Text('Total')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: sales.map((sale) {
                      TextEditingController quantityController =
                          TextEditingController(
                            text: sale['quantity'].toStringAsFixed(0),
                          );
                      TextEditingController priceController =
                          TextEditingController(
                            text: sale['price'].toStringAsFixed(0),
                          );

                      return DataRow(
                        cells: [
                          DataCell(Text(sale['id'].toString())),
                          DataCell(Text(sale['clientName'] ?? 'Desconocido')),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  sale['quantity'] =
                                      int.tryParse(value) ?? sale['quantity'];
                                },
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: priceController,
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  sale['price'] =
                                      double.tryParse(value) ?? sale['price'];
                                },
                              ),
                            ),
                          ),
                          DataCell(Text(sale['total'].toStringAsFixed(0))),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.save),
                                  onPressed: () async {
                                    final databaseService = DatabaseService();
                                    await databaseService.init();
                                    await databaseService.updateSale(
                                      id: sale['id'],
                                      quantity: sale['quantity'],
                                      price: sale['price'],
                                      total: sale['quantity'] * sale['price'],
                                      date: DateTime.now(),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Cambios guardados para venta #${sale['id']}',
                                        ),
                                      ),
                                    );
                                    setState(() {
                                      _loadDeliveryRecord();
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final databaseService = DatabaseService();
                                    await databaseService.init();
                                    await databaseService.deleteSale(
                                      sale['id'],
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Venta #${sale['id']} eliminada',
                                        ),
                                      ),
                                    );
                                    setState(() {
                                      _loadDeliveryRecord();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    final databaseService = DatabaseService();
    await databaseService.init();

    // Fetch all sales and filter by deliveryNumber
    final allSales = await databaseService.getAllSales();
    final sales = allSales
        .where(
          (sale) => sale.deliveryNumber == widget.deliveryRecord.deliveryNumber,
        )
        .toList();

    // Fetch all clients to map clientId to client name
    final allClientes = await databaseService.getAllClientes();
    final clientMap = {
      for (var client in allClientes) client.id: client.contacto,
    };

    // Prepare the sales data with client names and total
    List<Map<String, dynamic>> salesData = sales.map((sale) {
      return {
        'id': sale.id,
        'clientId': sale.clientId,
        'clientName': clientMap[sale.clientId] ?? 'Desconocido',
        'quantity': sale.quantity,
        'price': sale.price,
        'total': sale.total,
      };
    }).toList();

    return salesData;
  }
}
