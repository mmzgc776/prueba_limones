import 'package:flutter/material.dart';
import 'nuevo_cliente_page.dart';
import '../data/database.dart';
import '../controllers/delivery_controller.dart';
import '../services/delivery_service.dart';
import 'section_delivery/delivery_record.dart';
import 'section_delivery/widgets/active_delivery_view.dart';
import 'section_delivery/widgets/delivery_records_table.dart';
import 'section_delivery/widgets/fabs.dart';
import 'section_delivery/widgets/contacto_options_sheet.dart';
import '../widgets/venta_form.dart';

class SectionDeliveryPage extends StatefulWidget {
  final bool started;
  final bool paused;
  final int elapsedSeconds;
  final List<bool> clientesContactados;
  final int? selectedClienteIndex;

  const SectionDeliveryPage({
    Key? key,
    this.started = false,
    this.paused = false,
    this.elapsedSeconds = 0,
    this.clientesContactados = const [],
    this.selectedClienteIndex,
  }) : super(key: key);

  @override
  State<SectionDeliveryPage> createState() => _SectionDeliveryPageState();
}

class _SectionDeliveryPageState extends State<SectionDeliveryPage> {
  late DeliveryController _controller;
  late DeliveryService _deliveryService;
  List<Cliente> _clientes = [];
  late BuildContext rootContext;

  @override
  void initState() {
    super.initState();
    _controller = DeliveryController(
      started: widget.started,
      paused: widget.paused,
      elapsedSeconds: widget.elapsedSeconds,
      clientesContactados: widget.clientesContactados,
      selectedClienteIndex: widget.selectedClienteIndex,
    );
    _deliveryService = DeliveryService();
    // Load data
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final clientes = await _deliveryService.loadClientes();
      setState(() {
        _clientes = clientes;
        _controller.initializeClients(clientes.length);
      });
      await _controller.loadDeliveryRecords();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos cargados correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    }
  }

  void _showContactoSheet(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ContactoOptionsSheet(
        cliente: _clientes[index],
        index: index,
        onContactoUpdated: (contactado, estado) {
          _controller.updateContactoStatus(index, contactado, estado);
        },
        onActionSelected: (action) {
          _handleContactoAction(action, index);
        },
        deliveryService: _deliveryService,
      ),
    );
  }

  void _handleContactoAction(String action, int index) {
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
          builder: (context) => NuevoClientePage(
            cliente: _clientes[index],
            started: _controller.started,
            paused: _controller.paused,
            elapsedSeconds: _controller.elapsedSeconds,
            clientesContactados: List<bool>.from(
              _controller.clientesContactados,
            ),
            selectedClienteIndex: _controller.selectedClienteIndex,
            focusOnNotas: true,
          ),
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
                  _controller.pauseDelivery();
                }
                Navigator.of(context).pop();
                return false;
              },
              child: Scaffold(
                appBar: AppBar(title: const Text('Iniciar Reparto')),
                body: _controller.started
                    ? ActiveDeliveryView(
                        started: _controller.started,
                        paused: _controller.paused,
                        formattedTime: _controller.formattedTime,
                        clientes: _clientes,
                        clientesContactados: _controller.clientesContactados,
                        clientesEstado: _controller.clientesEstado,
                        selectedClienteIndex: _controller.selectedClienteIndex,
                        onClienteSelected: _controller.selectCliente,
                        onShowContactoSheet: _showContactoSheet,
                        onResumeDelivery: _controller.resumeDelivery,
                      )
                    : DeliveryRecordsTable(
                        deliveryRecords: _controller.deliveryRecords,
                        onLoadRecords: _controller.loadDeliveryRecords,
                        onDeleteRecords: _controller.deleteDeliveryRecords,
                        onDebugContactos: _controller.debugContactos,
                      ),
                floatingActionButton: FABs(
                  started: _controller.started,
                  paused: _controller.paused,
                  elapsedSeconds: _controller.elapsedSeconds,
                  clientesContactados: _controller.clientesContactados,
                  selectedClienteIndex: _controller.selectedClienteIndex,
                  onStartDelivery: () {
                    _controller.startDelivery(
                      _controller.deliveryRecords.length + 1,
                    );
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
                    ).then((confirm) {
                      if (confirm == true) {
                        _controller.endDelivery(_clientes);
                      }
                    });
                  },
                  onDebugContactos: _controller.debugContactos,
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
