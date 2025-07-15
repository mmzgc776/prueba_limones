import 'package:flutter/material.dart';
import '../delivery_record.dart';
import '../../../services/database_service.dart'; // Adjust path as necessary

class DeliveryDetailView extends StatefulWidget {
  final DeliveryRecord deliveryRecord;

  const DeliveryDetailView({Key? key, required this.deliveryRecord})
    : super(key: key);

  @override
  _DeliveryDetailViewState createState() => _DeliveryDetailViewState();
}

class _DeliveryDetailViewState extends State<DeliveryDetailView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalle de Reparto #${widget.deliveryRecord.deliveryNumber}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fecha: ${widget.deliveryRecord.date.day}/${widget.deliveryRecord.date.month}/${widget.deliveryRecord.date.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Duración: ${widget.deliveryRecord.duration.toString().split('.')[0]}',
            ),
            Text(
              'Precio Promedio: ${widget.deliveryRecord.avgPrice.toStringAsFixed(2)}',
            ),
            Text(
              'Kilogramos: ${widget.deliveryRecord.kilograms.toStringAsFixed(2)}',
            ),
            Text('Cajas: ${widget.deliveryRecord.boxes}'),
            Text(
              'Restante: ${widget.deliveryRecord.remaining.toStringAsFixed(2)}',
            ),
            Text('Vendedor: ${widget.deliveryRecord.seller}'),
            Text('Total: ${widget.deliveryRecord.total.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            const Text(
              'Lista de Ventas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildSalesList()),
          ],
        ),
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

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Cliente')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Precio')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: sales.map((sale) {
              TextEditingController quantityController = TextEditingController(
                text: sale['quantity'].toString(),
              );
              TextEditingController priceController = TextEditingController(
                text: sale['price'].toStringAsFixed(2),
              );

              return DataRow(
                cells: [
                  DataCell(Text(sale['id'].toString())),
                  DataCell(Text(sale['clientName'] ?? 'Desconocido')),
                  DataCell(
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        // TODO: Update sale quantity in the database
                        sale['quantity'] =
                            int.tryParse(value) ?? sale['quantity'];
                      },
                    ),
                  ),
                  DataCell(
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        // TODO: Update sale price in the database
                        sale['price'] = double.tryParse(value) ?? sale['price'];
                      },
                    ),
                  ),
                  DataCell(Text(sale['total'].toStringAsFixed(2))),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: () async {
                            // Update the sale in the database with current values and current date
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
                            // Refresh the data to reflect changes
                            setState(() {
                              // This will rebuild the widget tree to refresh the data
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            // Delete the sale from the database
                            final databaseService = DatabaseService();
                            await databaseService.init();
                            await databaseService.deleteSale(sale['id']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Venta #${sale['id']} eliminada'),
                              ),
                            );
                            // Refresh the data to reflect changes
                            setState(() {
                              // This will rebuild the widget tree to refresh the data
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
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    final databaseService = DatabaseService();
    await databaseService.init(); // Ensure the database is initialized

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
