import 'package:flutter/material.dart';
import '../widgets/venta_form.dart';
import '../services/database_service.dart';
import '../data/database.dart';

class EditSalePage extends StatefulWidget {
  final int saleId;
  final int? deliveryNumber;

  const EditSalePage({super.key, required this.saleId, this.deliveryNumber});

  @override
  State<EditSalePage> createState() => _EditSalePageState();
}

class _EditSalePageState extends State<EditSalePage> {
  Sale? _sale;
  Cliente? _cliente;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaleData();
  }

  Future<void> _loadSaleData() async {
    try {
      final databaseService = DatabaseService();
      await databaseService.init();

      final sale = await databaseService.getSaleById(widget.saleId);
      if (sale != null) {
        final cliente = await databaseService.getClienteById(sale.clientId);
        setState(() {
          _sale = sale;
          _cliente = cliente;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la venta')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar la venta: $e')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Venta'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.deliveryNumber != null
                  ? '( #${widget.deliveryNumber} )'
                  : '( Sin reparto )',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
          ? const Center(child: Text('No se pudo cargar la venta'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: EditVentaForm(
                sale: _sale!,
                cliente: _cliente,
                deliveryNumber: widget.deliveryNumber,
              ),
            ),
    );
  }
}
