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
  List<bool> _clientesEsRelleno = [];
  List<String> _clientesMotivos = [];
  int _loadGeneration = 0;
  late BuildContext rootContext;
  bool _isResumedDelivery = false;
  bool _resumeHandled = false;
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
    final generation = ++_loadGeneration;
    try {
      // Si la app se cerró con un reparto en curso, recuperarlo (B5).
      await _controller.restoreSession();
      if (!mounted || generation != _loadGeneration) return;

      // Obtener el número del delivery actual si hay uno activo
      final currentDeliveryNumber = _controller.started
          ? _controller.getCurrentDeliveryNumber()
          : widget.resumeDeliveryNumber;

      final result = await _deliveryService.loadClientes(
        excludeDeliveryNumber: currentDeliveryNumber,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _clientes = result.clientes;
        _clientesEsRelleno = result.esRelleno;
        _clientesMotivos = result.motivos;
        _controller.resetPendingClients(result.clientes.length);
      });
      await _controller.loadDeliveryRecords();

      // Si se está reanudando un reparto, verificar si necesita cajas.
      // Sólo una vez por página: _loadData se repite tras cada interacción
      // y reanudar de nuevo repetía el diálogo de cajas (B3).
      if (widget.resumeDeliveryNumber != null && !_resumeHandled) {
        _resumeHandled = true;
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

  /// Registra una interacción tipo "Venta" para el cliente seleccionado
  /// actualmente en el reparto activo. Se usa desde el botón "$" del FAB
  /// para mantener la consistencia con el flujo de _handleInteraccionAction.
  Future<void> _registrarInteraccionVenta() async {
    final selectedIndex = _controller.selectedClienteIndex;
    if (selectedIndex == null || selectedIndex >= _clientes.length) {
      debugPrint(
        'registrarInteraccionVenta: no hay cliente seleccionado, '
        'se omite el registro de interacción',
      );
      return;
    }

    try {
      final deliveryNumber = _controller.getCurrentDeliveryNumber();
      final cliente = _clientes[selectedIndex];

      // Marcar al cliente como contactado con estado "Venta"
      _controller.updateContactoStatus(selectedIndex, true, 'Venta');

      // Insertar la interacción inmediatamente en la base de datos
      await _deliveryService.insertInteraccionImmediate(
        deliveryId: deliveryNumber,
        clientId: cliente.id,
        result: 'Venta',
      );
      debugPrint(
        'Interacción de venta registrada desde FAB: '
        'delivery #$deliveryNumber, cliente ${cliente.id}',
      );
    } catch (e) {
      // No bloqueamos la navegación UX por errores de inserción; sólo logueamos
      debugPrint('Error al insertar interacción de venta desde FAB: $e');
    }
  }

  Future<void> _handleInteraccionAction(String action, int index) async {
    final cliente = _clientes[index];
    _controller.updateContactoStatus(index, true, action);
    // Insertar la interacción de forma inmediata en la base de datos
    try {
      final deliveryNumber = _controller.getCurrentDeliveryNumber();
      await _deliveryService.insertInteraccionImmediate(
        deliveryId: deliveryNumber,
        clientId: cliente.id,
        result: action,
      );
      if (!mounted) return;

      // Esperar la escritura antes de recargar, para que no reaparezca.
      if (action != 'Venta' && action != 'Encargó') {
        await _loadData();
      }
    } catch (e) {
      // No bloqueamos la navegación UX por errores de inserción; sólo logueamos
      debugPrint('Error al insertar interacción inmediata: $e');
    }
    if (!mounted) return;
    if (action == 'Venta') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Registrar Venta')),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: VentaForm(cliente: cliente),
            ),
          ),
        ),
      );
      if (mounted) await _loadData();
    } else if (action == 'Encargó') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              NuevoClientePage(cliente: cliente, focusOnNotas: true),
        ),
      );
      if (mounted) await _loadData();
    }
  }

  @override
  void dispose() {
    // Remover el observer del ciclo de vida
    WidgetsBinding.instance.removeObserver(_controller);
    _controller.dispose();
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
            // Salir de la pantalla no pausa: la sesión sigue corriendo y
            // persistida hasta que el usuario la pause o la detenga (B6).
            return Stack(
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
                        esRelleno: _clientesEsRelleno,
                        motivos: _clientesMotivos,
                        clientesContactados: List<bool>.from(
                          _controller.clientesContactados,
                        ),
                        clientesEstado: _controller.clientesEstado,
                        selectedClienteIndex: _controller.selectedClienteIndex,
                        onClienteSelected: _controller.selectCliente,
                        onShowInteraccionSheet: _showInteraccionSheet,
                        onResumeDelivery: _controller.resumeDelivery,
                        onDeselectCliente: _controller.deselectCliente,
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
                            onRegistrarVenta: _registrarInteraccionVenta,
                            onSalesReturned: _loadData,
                            onStartDelivery: () async {
                        // Mostrar diálogo para preguntar número de cajas
                        final boxes = await _showBoxesDialog();
                        if (boxes != null) {
                          await _controller.startDelivery(
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
