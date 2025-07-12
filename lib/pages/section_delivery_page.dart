import 'package:flutter/material.dart';
import 'dart:async';
import 'nuevo_cliente_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../data/database.dart';
import 'section_delivery/delivery_record.dart';
import 'section_delivery/widgets/cliente_info_card.dart';
import 'section_delivery/widgets/clientes_list.dart';
import 'section_delivery/widgets/fabs.dart';
import 'section_delivery/widgets/timer_display.dart';
import 'section_delivery/widgets/delivery_records_table.dart';
import 'section_delivery/widgets/contacto_section.dart';
import '../widgets/venta_form.dart';
import '../data/delivery_state.dart';

class DeliveryState {
  final bool started;
  final bool paused;
  final int elapsedSeconds;
  final List<bool> clientesContactados;
  final int? selectedClienteIndex;
  DeliveryState({
    required this.started,
    required this.paused,
    required this.elapsedSeconds,
    required this.clientesContactados,
    required this.selectedClienteIndex,
  });
}

class SectionDeliveryPage extends StatefulWidget {
  final DeliveryState? initialState;
  const SectionDeliveryPage({super.key, this.initialState});
  @override
  State<SectionDeliveryPage> createState() => _SectionDeliveryPageState();
}

class _SectionDeliveryPageState extends State<SectionDeliveryPage> {
  bool started = false;
  bool paused = false;
  Timer? _timer;
  int elapsedSeconds = 0;
  List<bool> clientesContactados = [];
  List<String> clientesEstado =
      []; // Estado: 'Venta', 'Rechazó', 'Pendiente', or 'Encargó'
  int? selectedClienteIndex;
  final List<DeliveryRecord> deliveryRecords = [];
  List<Cliente> clientes = [];
  late BuildContext rootContext;

  @override
  void initState() {
    super.initState();
    if (widget.initialState != null) {
      started = widget.initialState!.started;
      paused = widget.initialState!.paused;
      elapsedSeconds = widget.initialState!.elapsedSeconds;
      clientesContactados = List<bool>.from(
        widget.initialState!.clientesContactados,
      );
      selectedClienteIndex = widget.initialState!.selectedClienteIndex;
      if (started && !paused) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            elapsedSeconds++;
          });
        });
      }
    }
    // Cargar los registros de reparto y clientes automáticamente al iniciar la página
    _loadDeliveryRecords();
    _loadClientes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showContactoSheet(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.phone_outlined,
                  color: Colors.deepPurple,
                ),
                title: const Text('Llamada'),
                onTap: () async {
                  setState(() => clientesContactados[index] = true);
                  final phoneNumber = (clientes[index].telefono.isNotEmpty)
                      ? clientes[index].telefono
                      : '3333333333';
                  final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
                  if (await canLaunchUrl(telUri)) {
                    await launchUrl(telUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo iniciar la llamada.'),
                      ),
                    );
                  }
                  Navigator.pop(context);
                  // Mostrar sección de contacto después de llamada
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => ContactoSection(
                      onActionSelected: (action) {
                        Navigator.pop(context);
                        _handleContactoAction(action, index);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.deepPurple,
                ),
                title: const Text('Visita'),
                onTap: () async {
                  setState(() => clientesContactados[index] = true);
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  // Solicitar permisos y obtener la localización
                  try {
                    LocationPermission permission =
                        await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) {
                        debugPrint('Permiso de localización denegado');
                        return;
                      }
                    }
                    if (permission == LocationPermission.deniedForever) {
                      debugPrint(
                        'Permiso de localización denegado permanentemente',
                      );
                      return;
                    }
                    Position position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                    );
                    debugPrint(
                      'Localización obtenida: ${position.latitude}, ${position.longitude}',
                    );
                  } catch (e) {
                    debugPrint('Error al obtener la localización: $e');
                  }
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Localización obtenida. Seleccione una acción de contacto en la próxima pantalla.',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  // Mostrar sección de contacto después de Visita usando rootContext
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showModalBottomSheet(
                      context: rootContext,
                      builder: (context) => ContactoSection(
                        onActionSelected: (action) {
                          Navigator.pop(context);
                          _handleContactoAction(action, index);
                        },
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.message_outlined,
                  color: Colors.deepPurple,
                ),
                title: const Text('Mensaje'),
                onTap: () async {
                  setState(() => clientesContactados[index] = true);
                  final phoneNumber = (clientes[index].telefono.isNotEmpty)
                      ? clientes[index].telefono
                      : '3333333333';
                  final Uri whatsappUri = Uri.parse(
                    'whatsapp://send?phone=$phoneNumber',
                  );
                  if (await canLaunchUrl(whatsappUri)) {
                    await launchUrl(whatsappUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo abrir WhatsApp.'),
                      ),
                    );
                  }
                  Navigator.pop(context);
                  // Mostrar sección de contacto después de mensaje
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => ContactoSection(
                      onActionSelected: (action) {
                        Navigator.pop(context);
                        _handleContactoAction(action, index);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleContactoAction(String action, int index) {
    setState(() {
      clientesEstado[index] = action;
      clientesContactados[index] = true; // Ensure the contact flag is set
      debugPrint(
        'Estado actualizado para cliente $index: $action, Contactado: ${clientesContactados[index]}',
      );
    });
    debugPrint('Acción de contacto para cliente $index: $action');

    if (action == 'Venta') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Registrar Venta')),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: VentaForm(cliente: clientes[index]),
            ),
          ),
        ),
      );
    } else if (action == 'Encargó') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NuevoClientePage(
            cliente: clientes[index],
            started: started,
            paused: paused,
            elapsedSeconds: elapsedSeconds,
            clientesContactados: List<bool>.from(clientesContactados),
            selectedClienteIndex: selectedClienteIndex,
            focusOnNotas: true,
          ),
        ),
      );
      debugPrint('Redirigiendo a sección de Nuevo Cliente con foco en notas');
    }
  }

  void _startDelivery() {
    setState(() {
      started = true;
      paused = false;
      elapsedSeconds = 0;
    });
    DeliveryStateManager().startDelivery(deliveryRecords.length + 1);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        elapsedSeconds++;
      });
    });
  }

  void _pauseDelivery() {
    setState(() {
      paused = true;
    });
    DeliveryStateManager().pauseDelivery();
    _timer?.cancel();
  }

  void _resumeDelivery() {
    setState(() {
      paused = false;
    });
    DeliveryStateManager().resumeDelivery();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        elapsedSeconds++;
      });
    });
  }

  void _endDelivery() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(
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
    );
    if (confirm == true) {
      setState(() {
        started = false;
        paused = false;
        // Save delivery record locally
        final record = DeliveryRecord(
          deliveryNumber:
              DeliveryStateManager().getCurrentDeliveryNumber() ??
              (deliveryRecords.length + 1),
          date: DateTime.now(),
          duration: Duration(seconds: elapsedSeconds),
          avgPrice: 0.0, // Placeholder
          kilograms: 0.0, // Placeholder
          boxes: 0, // Placeholder
          remaining: 0.0, // Placeholder
          seller: "Default Seller", // Placeholder
          total: 0.0, // Placeholder
        );
        deliveryRecords.add(record);
        // Save to database using DatabaseService
        _saveDeliveryToDatabase(record);
        // Debug current state before saving contact results
        debugPrint('Antes de guardar resultados de contacto:');
        for (int i = 0; i < clientes.length; i++) {
          if (clientesEstado[i].isNotEmpty || clientesContactados[i]) {
            debugPrint(
              'Cliente $i: Contactado: ${clientesContactados[i]}, Estado: "${clientesEstado[i]}"',
            );
          }
        }
        // Save contact results to database using current state
        _saveContactResultsToDatabase(record.deliveryNumber);
        elapsedSeconds = 0; // Resetear cronómetro
        // Limpiar estado de clientes contactados después de guardar
        clientesContactados = List.generate(clientes.length, (_) => false);
        clientesEstado = List.generate(clientes.length, (_) => '');
        selectedClienteIndex = null; // Limpiar cliente seleccionado
      });
      DeliveryStateManager().endDelivery();
      _timer?.cancel();
    }
  }

  Future<void> _saveContactResultsToDatabase(int deliveryId) async {
    // Este método ya no se usa directamente, pero se mantiene por si hay referencias previas
    return _saveContactResultsToDatabaseWithState(
      deliveryId,
      clientesContactados,
      clientesEstado,
    );
  }

  Future<void> _saveContactResultsToDatabaseWithState(
    int deliveryId,
    List<bool> contactados,
    List<String> estados,
  ) async {
    try {
      final dbService = DatabaseService();
      await dbService.init();
      debugPrint(
        'Guardando resultados de contacto para deliveryId: $deliveryId',
      );
      int savedCount = 0;
      for (int i = 0; i < clientes.length; i++) {
        debugPrint(
          'Verificando cliente $i: Contactado: ${contactados[i]}, Estado: "${estados[i]}"',
        );
        if (contactados[i] && estados[i].isNotEmpty) {
          debugPrint(
            'Guardando contacto: Cliente ID ${clientes[i].id}, Resultado: ${estados[i]}',
          );
          await dbService.insertContacto(
            clientId: clientes[i].id,
            result: estados[i],
            deliveryId: deliveryId,
          );
          savedCount++;
        }
      }
      debugPrint('Total de contactos guardados: $savedCount');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resultados de contacto guardados')),
      );
    } catch (e) {
      debugPrint('Error saving contact results to database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar los resultados de contacto'),
        ),
      );
    }
  }

  Future<void> _debugContactos() async {
    try {
      final dbService = DatabaseService();
      await dbService.init();
      final contactos = await dbService.getLast10Contactos();
      debugPrint('Últimos 10 registros de Contactos:');
      if (contactos.isEmpty) {
        debugPrint('No hay registros de contactos.');
      } else {
        for (var contacto in contactos) {
          debugPrint('ID: ${contacto.id}');
          debugPrint('Client ID: ${contacto.clientId}');
          debugPrint('Resultado: ${contacto.result}');
          debugPrint('Delivery ID: ${contacto.deliveryId}');
          debugPrint('---');
        }
      }
      debugPrint('Estado actual de clientesEstado:');
      for (int i = 0; i < clientesEstado.length; i++) {
        if (clientesEstado[i].isNotEmpty) {
          debugPrint(
            'Cliente index $i: ${clientesEstado[i]} (Contactado: ${clientesContactados[i]})',
          );
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registros de contactos impresos en consola'),
        ),
      );
    } catch (e) {
      debugPrint('Error fetching contact records: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al obtener los registros de contactos'),
        ),
      );
    }
  }

  Future<void> _loadClientes() async {
    try {
      final dbService = DatabaseService();
      await dbService.init();
      final fetchedClientes = await dbService.getAllClientes();
      setState(() {
        clientes = fetchedClientes;
        clientesContactados = List.generate(
          fetchedClientes.length,
          (_) => false,
        );
        clientesEstado = List.generate(fetchedClientes.length, (_) => '');
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clientes cargados')));
    } catch (e) {
      debugPrint('Error loading clientes from database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar los clientes')),
      );
    }
  }

  Future<void> _loadDeliveryRecords() async {
    try {
      final dbService = DatabaseService();
      await dbService.init();
      final deliveries = await dbService.getAllDeliveries();
      setState(() {
        deliveryRecords.clear();
        deliveryRecords.addAll(
          deliveries.map(
            (delivery) => DeliveryRecord(
              deliveryNumber: delivery.deliveryNumber,
              date: delivery.date,
              duration: Duration(seconds: delivery.durationSeconds),
              avgPrice: delivery.avgPrice,
              kilograms: delivery.kilograms,
              boxes: delivery.boxes,
              remaining: delivery.remaining,
              seller: delivery.seller,
              total: delivery.total,
            ),
          ),
        );
      });
      debugPrint('Mostrando repartos:');
      if (deliveryRecords.isEmpty) {
        debugPrint('No hay registros de repartos.');
      } else {
        for (var record in deliveryRecords) {
          debugPrint('Reparto Nº: ${record.deliveryNumber}');
          debugPrint(
            'Fecha: ${record.date.day}/${record.date.month}/${record.date.year}',
          );
          debugPrint('Duración: ${record.duration.toString().split('.')[0]}');
          debugPrint('Precio Promedio: ${record.avgPrice.toStringAsFixed(2)}');
          debugPrint('Kilogramos: ${record.kilograms.toStringAsFixed(2)}');
          debugPrint('Cajas: ${record.boxes}');
          debugPrint('Restante: ${record.remaining.toStringAsFixed(2)}');
          debugPrint('Vendedor: ${record.seller}');
          debugPrint('Total: ${record.total.toStringAsFixed(2)}');
          debugPrint('---');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registros de reparto cargados')),
      );
    } catch (e) {
      debugPrint('Error loading deliveries from database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar los registros de reparto'),
        ),
      );
    }
  }

  Future<void> _deleteDeliveryRecords() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text(
            '¿Estás seguro que deseas eliminar todos los registros de reparto? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final dbService = DatabaseService();
        await dbService.init();
        await dbService.deleteAllDeliveries();
        setState(() {
          deliveryRecords.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registros de reparto eliminados')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting deliveries from database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al eliminar los registros de reparto'),
        ),
      );
    }
  }

  Future<void> _saveDeliveryToDatabase(DeliveryRecord record) async {
    try {
      final dbService = DatabaseService();
      await dbService.init();
      await dbService.insertDelivery(
        deliveryNumber: record.deliveryNumber,
        date: record.date,
        durationSeconds: record.duration.inSeconds,
        avgPrice: record.avgPrice,
        kilograms: record.kilograms,
        boxes: record.boxes,
        remaining: record.remaining,
        seller: record.seller,
        total: record.total,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reparto guardado en la base de datos')),
      );
    } catch (e) {
      debugPrint('Error saving delivery to database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar el reparto en la base de datos'),
        ),
      );
    }
  }

  String get formattedTime {
    final hours = (elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        rootContext = ctx;
        return WillPopScope(
          onWillPop: () async {
            if (started && !paused) {
              _pauseDelivery();
            }
            // Devuelve el estado actual al salir
            Navigator.of(context).pop(
              DeliveryState(
                started: started,
                paused: paused,
                elapsedSeconds: elapsedSeconds,
                clientesContactados: List<bool>.from(clientesContactados),
                selectedClienteIndex: selectedClienteIndex,
              ),
            );
            return false; // Prevenimos el pop automático, ya lo hicimos manualmente
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Iniciar Reparto')),
            body: started
                ? Stack(
                    children: [
                      ClienteInfoCard(
                        selectedClienteIndex: selectedClienteIndex,
                        started: started,
                        clientes: clientes,
                      ),
                      ClientesList(
                        started: started,
                        paused: paused,
                        clientes: clientes,
                        clientesContactados: clientesContactados,
                        clientesEstado: clientesEstado,
                        selectedClienteIndex: selectedClienteIndex,
                        onClienteSelected: (index) {
                          setState(() {
                            selectedClienteIndex = index;
                          });
                        },
                        onShowContactoSheet: _showContactoSheet,
                        onResumeDelivery: _resumeDelivery,
                      ),
                      TimerDisplay(
                        started: started,
                        formattedTime: formattedTime,
                      ),
                    ],
                  )
                : DeliveryRecordsTable(
                    deliveryRecords: deliveryRecords,
                    onLoadRecords: _loadDeliveryRecords,
                    onDeleteRecords: _deleteDeliveryRecords,
                    onDebugContactos: _debugContactos,
                  ),
            floatingActionButton: FABs(
              started: started,
              paused: paused,
              elapsedSeconds: elapsedSeconds,
              clientesContactados: clientesContactados,
              selectedClienteIndex: selectedClienteIndex,
              onStartDelivery: _startDelivery,
              onPauseDelivery: _pauseDelivery,
              onResumeDelivery: _resumeDelivery,
              onEndDelivery: _endDelivery,
              onDebugContactos: _debugContactos,
            ),
            floatingActionButtonLocation: const _CustomFABLocation(offsetY: 80),
          ),
        );
      },
    );
  }
}

// Al final del archivo, agrega la clase para la ubicación personalizada del FAB
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
