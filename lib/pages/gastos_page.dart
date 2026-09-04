import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../services/database_service.dart';

const List<String> categoriasGastos = [
  'Laboreo',
  'Corte',
  'Insumos',
  'Aplicación',
  'Luz',
  'Combustible',
];

class GastosPage extends StatefulWidget {
  const GastosPage({super.key});

  @override
  State<GastosPage> createState() => _GastosPageState();
}

class _GastosPageState extends State<GastosPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Gasto> _gastos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGastos();
  }

  Future<void> _loadGastos() async {
    setState(() => _isLoading = true);
    try {
      await _dbService.init();
      final gastos = await _dbService.getAllGastos();
      if (!mounted) return;
      setState(() {
        _gastos = gastos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading gastos: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _totalGastos =>
      _gastos.fold(0.0, (sum, g) => sum + g.monto);

  Future<void> _showGastoDialog({Gasto? gasto}) async {
    final formKey = GlobalKey<FormState>();
    final conceptoController = TextEditingController(text: gasto?.concepto ?? '');
    final montoController = TextEditingController(
      text: gasto?.monto.toString() ?? '',
    );
    String? categoria = gasto?.categoria ?? categoriasGastos.first;
    DateTime fecha = gasto?.fecha ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(gasto != null ? 'Editar Gasto' : 'Nuevo Gasto'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: categoriasGastos
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => categoria = v,
                ),
                TextFormField(
                  controller: conceptoController,
                  decoration: const InputDecoration(labelText: 'Concepto'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Campo requerido' : null,
                ),
                TextFormField(
                  controller: montoController,
                  decoration: const InputDecoration(labelText: 'Monto (\$)'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final monto = double.tryParse(v ?? '');
                    return (monto == null || monto <= 0)
                        ? 'Monto inválido'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fecha,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) fecha = picked;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final monto = double.parse(montoController.text);
              if (gasto == null) {
                await _dbService.insertGasto(
                  fecha: fecha,
                  concepto: conceptoController.text,
                  monto: monto,
                  categoria: categoria!,
                );
              } else {
                await _dbService.updateGasto(
                  id: gasto!.id,
                  fecha: fecha,
                  concepto: conceptoController.text,
                  monto: monto,
                  categoria: categoria!,
                );
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              await _loadGastos();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGasto(Gasto gasto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text('¿Eliminar "${gasto.concepto}" por \$${gasto.monto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dbService.deleteGasto(gasto.id);
      await _loadGastos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Gastos'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGastoDialog(),
        tooltip: 'Nuevo gasto',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_totalGastos.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _gastos.isEmpty
                      ? const Center(child: Text('No hay gastos registrados'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _gastos.length,
                          itemBuilder: (context, index) {
                            final gasto = _gastos[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    _iconForCategoria(gasto.categoria),
                                  ),
                                ),
                                title: Text(gasto.concepto),
                                subtitle: Text(
                                  '${gasto.categoria} • ${DateFormat('dd/MM/yyyy').format(gasto.fecha)}',
                                ),
                                trailing: Text(
                                  '\$${gasto.monto.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () => _showGastoDialog(gasto: gasto),
                                onLongPress: () => _deleteGasto(gasto),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  IconData _iconForCategoria(String categoria) {
    switch (categoria) {
      case 'Laboreo':
        return Icons.agriculture;
      case 'Corte':
        return Icons.content_cut;
      case 'Insumos':
        return Icons.inventory_2;
      case 'Aplicación':
        return Icons.opacity;
      case 'Luz':
        return Icons.lightbulb;
      case 'Combustible':
        return Icons.local_gas_station;
      default:
        return Icons.attach_money;
    }
  }
}