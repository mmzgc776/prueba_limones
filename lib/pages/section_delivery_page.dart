import 'package:flutter/material.dart';
import 'nuevo_cliente_page.dart';
import '../data/database.dart';
import '../controllers/delivery_controller.dart';
import '../services/delivery_service.dart';
import 'section_delivery/delivery_record.dart';
import 'section_delivery/widgets/active_delivery_view.dart';
import 'section_delivery/widgets/delivery_records_table.dart';
import 'section_delivery/widgets/fabs.dart';
import 'section_delivery/widgets/interaccion_options_sheet.dart';
import '../widgets/venta_form.dart';

class SectionDeliveryPage extends StatefulWidget {
  final int? resumeDeliveryNumber;

  const SectionDeliveryPage({Key? key, this.resumeDeliveryNumber})
    : super(key: key);

  @override
  State<SectionDeliveryPage> createState() => _SectionDeliveryPageState();
}

class _SectionDeliveryPageState extends State<SectionDeliveryPage> {
  late DeliveryController _controller;
  late DeliveryService _deliveryService;
  List<Cliente> _clientes = [];
  late BuildContext rootContext;
  bool _isResumedDelivery = false;

  @override
  void initState() {
    super.initState();
    _controller = DeliveryController();
    _deliveryService = DeliveryService();
    _isResumedDelivery = widget.resumeDeliveryNumber != null;
    // Load data
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final clientes = await _deliveryService.loadClientes(
        excludeDeliveryNumber: widget.resumeDeliveryNumber,
      );
      setState(() {
        _clientes = clientes;
        _controller.initializeClients(clientes.length);
      });
      await _controller.loadDeliveryRecords();

      // Si se está reanudando un reparto, iniciarlo automáticamente
      if (widget.resumeDeliveryNumber != null) {
        await _controller.resumeSpecificDelivery(widget.resumeDeliveryNumber!);
      }

      /* ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos cargados correctamente')),
      ); */
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    }
  }

  void _showInteraccionSheet(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => InteraccionOptionsSheet(
        cliente: _clientes[index],
        index: index,
        onInteraccionUpdated: (contactado, estado) {
          _controller.updateContactoStatus(index, contactado, estado);
        },
        onActionSelected: (action) {
          _handleInteraccionAction(action, index);
        },
        deliveryService: _deliveryService,
      ),
    );
  }

  void _handleInteraccionAction(String action, int index) {
    _controller.updateContactoStatus(index, true, action);
    if (action == 'Venta') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Registrar Venta')),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: VentaForm(cliente: _clientes[index]),
            ),
          ),
        ),
      );
    } else if (action == 'Encargó') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              NuevoClientePage(cliente: _clientes[index], focusOnNotas: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        rootContext = ctx;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return WillPopScope(
              onWillPop: () async {
                if (_controller.started && !_controller.paused) {
                  await _controller.pauseDelivery();
                }
                return true;
              },
              child: Scaffold(
                appBar: AppBar(title: const Text('Iniciar Reparto')),
                body: _controller.started
                    ? ActiveDeliveryView(
                        started: _controller.started,
                        paused: _controller.paused,
                        formattedTime: _controller.formattedTime,
                        clientes: _clientes,
                        clientesContactados: List<bool>.from(
                          _controller.clientesContactados,
                        ),
                        clientesEstado: _controller.clientesEstado,
                        selectedClienteIndex: _controller.selectedClienteIndex,
                        onClienteSelected: _controller.selectCliente,
                        onShowInteraccionSheet: _showInteraccionSheet,
                        onResumeDelivery: _controller.resumeDelivery,
                      )
                    : DeliveryRecordsTable(
                        deliveryRecords: _controller.deliveryRecords,
                        onLoadRecords: _controller.loadDeliveryRecords,
                        onDeleteRecords: _controller.deleteDeliveryRecords,
                        onDebugInteracciones: _controller.debugInteracciones,
                      ),
                floatingActionButton: FABs(
                  started: _controller.started,
                  paused: _controller.paused,
                  elapsedSeconds: _controller.elapsedSeconds,
                  clientesContactados: List<bool>.from(
                    _controller.clientesContactados,
                  ),
                  selectedClienteIndex: _controller.selectedClienteIndex,
                  onStartDelivery: () async {
                    // Mostrar diálogo para preguntar número de cajas
                    final boxes = await _showBoxesDialog();
                    if (boxes != null) {
                      _controller.startDelivery(
                        _controller.deliveryRecords.length + 1,
                        boxes: boxes,
                      );
                    }
                  },
                  onPauseDelivery: _controller.pauseDelivery,
                  onResumeDelivery: _controller.resumeDelivery,
                  onEndDelivery: () {
                    showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar'),
                        content: const Text(
                          '¿Estás seguro que deseas detener el reparto? Esto guardará este número de reparto.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Detener reparto'),
                          ),
                        ],
                      ),
                    ).then((confirm) async {
                      if (confirm == true) {
                        await _controller.endDelivery(_clientes);

                        // Si es un reparto reanudado, volver a la vista anterior
                        if (_isResumedDelivery && mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    });
                  },
                  onDebugInteracciones: _controller.debugInteracciones,
                ),
                floatingActionButtonLocation: const _CustomFABLocation(
                  offsetY: 80,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Muestra un diálogo para preguntar el número de cajas
  Future<int?> _showBoxesDialog() async {
    final controller = TextEditingController(text: '0');

    return showDialog<int>(
      context: context,
      barrierDismissible: false, // Usuario debe responder
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Iniciar Reparto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Con cuántas cajas inicias el reparto?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Número de cajas',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                onSubmitted: (value) {
                  final boxes = int.tryParse(value) ?? 0;
                  Navigator.of(context).pop(boxes);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final boxes = int.tryParse(controller.text) ?? 0;
                Navigator.of(context).pop(boxes);
              },
              child: const Text('Iniciar'),
            ),
          ],
        );
      },
    );
  }
}

// Custom FAB location class
class _CustomFABLocation extends FloatingActionButtonLocation {
  final double offsetY;
  const _CustomFABLocation({this.offsetY = 80});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        (scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry.floatingActionButtonSize.width) /
        2;
    final double fabY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        offsetY;
    return Offset(fabX, fabY);
  }
}
