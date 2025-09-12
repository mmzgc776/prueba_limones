import 'package:flutter/material.dart';
import '../delivery_record.dart';
import 'delivery_detail_view.dart';

class DeliveryRecordsTable extends StatelessWidget {
  final List<DeliveryRecord> deliveryRecords;
  final Function() onLoadRecords;
  final Function() onDeleteRecords;
  final Function() onDebugContactos;

  const DeliveryRecordsTable({
    Key? key,
    required this.deliveryRecords,
    required this.onLoadRecords,
    required this.onDeleteRecords,
    required this.onDebugContactos,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'Historial de Repartos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: onLoadRecords,
                    child: const Text('Mostrar repartos'),
                  ),
                  ElevatedButton(
                    onPressed: onDeleteRecords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Eliminar repartos'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: onDebugContactos,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Debug Contactos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: deliveryRecords.isEmpty
                ? const Center(child: Text('No hay registros de repartos aún.'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Nº')),
                          DataColumn(label: Text('Fecha')),
                          DataColumn(label: Text('Duración')),
                          DataColumn(label: Text('Precio Prom.')),
                          DataColumn(label: Text('Kg')),
                          DataColumn(label: Text('Cajas')),
                          DataColumn(label: Text('Restante')),
                          DataColumn(label: Text('Vendedor')),
                          DataColumn(label: Text('Total')),
                        ],
                        rows: deliveryRecords.map((record) {
                          return DataRow(
                            onSelectChanged: (selected) {
                              if (selected == true) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DeliveryDetailView(
                                      deliveryRecord: record,
                                    ),
                                  ),
                                );
                              }
                            },
                            cells: [
                              DataCell(Text(record.deliveryNumber.toString())),
                              DataCell(
                                Text(
                                  '${record.date.day}/${record.date.month}/${record.date.year}',
                                ),
                              ),
                              DataCell(
                                Text(record.duration.toString().split('.')[0]),
                              ),
                              DataCell(
                                Text(record.avgPrice.toStringAsFixed(2)),
                              ),
                              DataCell(
                                Text(record.kilograms.toStringAsFixed(2)),
                              ),
                              DataCell(Text(record.boxes.toString())),
                              DataCell(
                                Text(record.remaining.toStringAsFixed(2)),
                              ),
                              DataCell(Text(record.seller)),
                              DataCell(Text(record.total.toStringAsFixed(2))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
