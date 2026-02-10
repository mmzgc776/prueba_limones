import 'package:flutter/material.dart';
import 'nuevo_cliente_page.dart';
import '../data/database.dart';
import '../controllers/delivery_controller.dart';
import '../services/delivery_service.dart';
import '../services/database_service.dart';
import 'section_delivery/delivery_record.dart';
import 'section_delivery/widgets/active_delivery_view.dart';
import 'section_delivery/widgets/delivery_records_table.dart';
import 'section_delivery/widgets/history_view.dart';
import 'section_delivery/widgets/fabs.dart';
import 'section_delivery/widgets/interaccion_options_sheet.dart';
import 'section_delivery/widgets/timer_display.dart';
import '../widgets/venta_form.dart';

class SectionDeliveryPage extends StatefulWidget {
  final int? resumeDeliveryNumber;

  const SectionDeliveryPage({Key? key, this.resumeDeliveryNumber})
    : super(key: key);

  @override
  State<SectionDeliveryPage> createState() => _SectionDeliveryPageState();
}

class _SectionDeliveryPageState extends State<SectionDeliveryPage>
    with SingleTickerProviderStateMixin {
  late DeliveryController _controller;
  late DeliveryService _deliveryService;
  late DatabaseService _databaseService;
  List<Cliente> _clientes = [];
  late BuildContext rootContext;
  bool _isResumedDelivery = false;
  late TabController _tabController;
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _controller = DeliveryController();
    _deliveryService = DeliveryService();
    _databaseService = DatabaseService();
    _isResumedDelivery = widget.resumeDeliveryNumber != null;
    _tabController = TabController(length: 2, vsync: this);

    // Listener para detectar cambios de tab
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Registrar el observer del ciclo de vida
    WidgetsBinding.instance.addObserver(_controller);

    // Load data
    _loadData();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await _databaseService.getHistoryForLastDeliveries(4);
      setState(() {
        _historyData = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      // Obtener el número del delivery actual si hay uno activo
      final currentDeliveryNumber = _controller.started
          ? _controller.getCurrentDeliveryNumber()
          : widget.resumeDeliveryNumber;

      final clientes = await _deliveryService.loadClientes(
        excludeDeliveryNumber: currentDeliveryNumber,
      );
      setState(() {
        _clientes = clientes;
        _controller.initializeClients(clientes.length);
      });
      await _controller.loadDeliveryRecords();

      // Si se está reanudando un reparto, verificar si necesita cajas
      if (widget.resumeDeliveryNumber != null) {
        final existingDelivery = await _deliveryService.getDeliveryByNumber(
          widget.resumeDeliveryNumber!,
        );

        // Si el delivery tiene 0 cajas, pedir al usuario que las ingrese
        if (existingDelivery != null && existingDelivery.boxes == 0) {
          final boxes = await _showBoxesDialog(isResume: true);
          if (boxes != null && boxes > 0) {
            await _controller.resumeSpecificDelivery(
              widget.resumeDeliveryNumber!,
              boxesOverride: boxes,
            );
          } else {
            // Si el usuario cancela o ingresa 0, reanudar sin cajas
            await _controller.resumeSpecificDelivery(widget.resumeDeliveryNumber!);
          }
        } else {
          // Si el delivery tiene cajas, reanudar normalmente
          await _controller.resumeSpecificDelivery(widget.resumeDeliveryNumber!);
        }
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
    // Insertar la interacción de forma inmediata en la base de datos
    try {
      final deliveryNumber = _controller.getCurrentDeliveryNumber();
      _deliveryService.insertInteraccionImmediate(
        deliveryId: deliveryNumber,
        clientId: _clientes[index].id,
        result: action,
      );

      // Si el cliente rechazó, recargar la lista para excluirlo
      if (action == 'Rechazó') {
        _loadData();
      }
    } catch (e) {
      // No bloqueamos la navegación UX por errores de inserción; sólo logueamos
      debugPrint('Error al insertar interacción inmediata: $e');
    }
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
  void dispose() {
    // Remover el observer del ciclo de vida
    WidgetsBinding.instance.removeObserver(_controller);
    _tabController.dispose();
    super.dispose();
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
              child: Stack(
                children: [
                  Scaffold(
                    appBar: AppBar(
                      title: const Text('Iniciar Reparto'),
                      actions: _controller.started
                          ? [
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _controller.formattedTime,
                                      style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          : null,
                    ),
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
                    : Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            labelColor: Theme.of(context).primaryColor,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Theme.of(context).primaryColor,
                            tabs: const [
                              Tab(
                                icon: Icon(Icons.local_shipping),
                                text: 'Repartos',
                              ),
                              Tab(
                                icon: Icon(Icons.history),
                                text: 'Historial',
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                DeliveryRecordsTable(
                                  deliveryRecords: _controller.deliveryRecords,
                                  onLoadRecords: _controller.loadDeliveryRecords,
                                  onDeleteRecords: _controller.deleteDeliveryRecords,
                                  onDebugInteracciones: _controller.debugInteracciones,
                                ),
                                _isLoadingHistory
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : HistoryView(
                                        historyData: _historyData,
                                        onRefresh: _loadHistory,
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    floatingActionButton: (_controller.started || _tabController.index == 0)
                        ? FABs(
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
                          )
                        : null,
                    floatingActionButtonLocation: const _CustomFABLocation(
                      offsetY: 80,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Muestra un diálogo para preguntar el número de cajas
  /// [isResume] indica si se está reanudando un reparto existente
  Future<int?> _showBoxesDialog({bool isResume = false}) async {
    final controller = TextEditingController(text: '0');

    return showDialog<int>(
      context: context,
      barrierDismissible: false, // Usuario debe responder
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isResume ? 'Reanudar Reparto' : 'Iniciar Reparto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isResume
                    ? 'Este reparto no tiene cajas registradas.\n¿Con cuántas cajas iniciaste el reparto?'
                    : '¿Con cuántas cajas inicias el reparto?',
                style: const TextStyle(fontSize: 16),
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
              child: Text(isResume ? 'Reanudar' : 'Iniciar'),
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
