import 'package:flutter/material.dart';
import 'pages/section1_page.dart';
import 'pages/ventas_page.dart';
import 'pages/section_delivery_page.dart';
import 'pages/nuevo_cliente_page.dart';
import 'pages/synchronization_page.dart';
import 'pages/editar_clientes_page.dart';
import 'pages/logs_page.dart';
import 'pages/edit_sale_page.dart';
import 'data/delivery_state.dart';
import 'widgets/notes_overview_widget.dart';
import 'services/sniim_scraper_service.dart';
import 'services/database_service.dart';

// Global RouteObserver to track navigation changes
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() {
  appLog('Application started');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
      navigatorObservers: [routeObserver], // Add RouteObserver
      routes: {
        '/section1': (context) => const Section1Page(),
        '/ventas': (context) => const VentasPage(),
        '/section_delivery': (context) => const SectionDeliveryPage(),
        '/nuevo_cliente': (context) => const NuevoClientePage(),
        '/synchronization': (context) => const SynchronizationPage(),
        '/editar_clientes': (context) => const EditarClientesPage(),
        '/logs': (context) => const LogsPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/edit_sale') {
          final saleId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (context) => EditSalePage(saleId: saleId),
          );
        }
        return null;
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _repartoStarted = false;
  bool _repartoPaused = false;
  int _repartoElapsedSeconds = 0;
  List<bool> _repartoClientesContactados = [];
  int? _repartoSelectedClienteIndex;
  bool _clientesExpanded = false;

  // SNIIM Scraper
  final SniimScraperService _scraperService = SniimScraperService();
  double? _mediaNacional;
  double? _mediaLocal;
  bool _isLoadingPrecios = false;
  String _errorMessage = '';

  // Database service
  final DatabaseService _databaseService = DatabaseService();

  // Precio calculado
  int _precioAnterior = 0; // Precio del último reparto
  int? _precioCalculado; // Precio4 calculado
  bool _precioGuardado = false; // Indica si ya se guardó el precio en esta sesión

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _goToReparto(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SectionDeliveryPage()),
    );
    // Since SectionDeliveryPage no longer returns a state object, we don't update state here
  }

  final TextEditingController _precioSugeridoController = TextEditingController(
    text: "0.00",
  );

  @override
  void initState() {
    super.initState();
    _precioSugeridoController.addListener(() {
      setState(() {
        // Update the value when the text changes
      });
    });
    _cargarPrecioAnterior();
  }

  Future<void> _cargarPrecioAnterior() async {
    try {
      // Obtener todos los repartos y tomar el último
      final deliveries = await _databaseService.getAllDeliveries();
      if (deliveries.isNotEmpty) {
        // Ordenar por número de reparto descendente
        deliveries.sort((a, b) => b.deliveryNumber.compareTo(a.deliveryNumber));
        final lastDelivery = deliveries.first;

        setState(() {
          // Convertir avgPrice a entero y guardarlo como precio anterior
          _precioAnterior = lastDelivery.avgPrice.round();
        });

        debugPrint(
          'Precio anterior cargado: $_precioAnterior (del reparto ${lastDelivery.deliveryNumber})',
        );
      }
    } catch (e) {
      debugPrint('Error al cargar precio anterior: $e');
    }
  }

  @override
  void dispose() {
    _precioSugeridoController.dispose();
    _scraperService.dispose();
    super.dispose();
  }

  void _calcularPrecio4() {
    // Calcular Precio4 = media(Media nacional, Media nacional*0.7, Media local, Media local*0.8, Precio anterior, Precio deseado)
    List<double> valores = [];

    // Agregar Media Nacional y Media Nacional * 0.7
    if (_mediaNacional != null && _mediaNacional! > 0) {
      valores.add(_mediaNacional!);
      valores.add(_mediaNacional! * 0.7);
    }

    // Agregar Media Local y Media Local * 0.8
    if (_mediaLocal != null && _mediaLocal! > 0) {
      valores.add(_mediaLocal!);
      valores.add(_mediaLocal! * 0.8);
    }

    // Agregar Precio Anterior (si es mayor a 0)
    if (_precioAnterior > 0) {
      valores.add(_precioAnterior.toDouble());
    }

    // Agregar Precio Deseado
    final precioDeseado =
        double.tryParse(_precioSugeridoController.text) ?? 0.0;
    if (precioDeseado > 0) {
      valores.add(precioDeseado);
    }

    // Calcular la media si hay valores
    if (valores.isNotEmpty) {
      final suma = valores.fold<double>(0.0, (sum, val) => sum + val);
      final media = suma / valores.length;
      final precioCalculado = media.round(); // Sin decimales

      setState(() {
        _precioCalculado = precioCalculado;
        _precioGuardado = true; // Marcar como guardado
      });

      // Actualizar el precio en el DeliveryStateManager para usarlo en el próximo reparto
      DeliveryStateManager().setCurrentPrice(precioCalculado.toDouble());

      debugPrint(
        'Precio calculado: $precioCalculado (guardado para próximo reparto)',
      );
    } else {
      setState(() {
        _precioCalculado = null;
      });
    }
  }

  Future<void> _consultarPrecios() async {
    setState(() {
      _isLoadingPrecios = true;
      _errorMessage = '';
      _mediaNacional = null;
      _mediaLocal = null;
    });

    try {
      debugPrint('=== CONSULTANDO PRECIOS SNIIM ===');

      final allData = await _scraperService.obtenerPreciosDirecto(
        dias: 7,
        productoId: 426, // Limón s/semilla - Primera
      );

      debugPrint('Total de registros obtenidos: ${allData.length}');

      if (allData.isNotEmpty) {
        // Calcular medias
        final mediaGen = _scraperService.calcularMediaGeneral(allData);
        final mediaGdl = _scraperService.calcularMediaPorOrigen(
          allData,
          'Guadalajara',
        );

        setState(() {
          _mediaNacional = mediaGen;
          _mediaLocal = mediaGdl > 0 ? mediaGdl : null;
        });
      } else {
        setState(() {
          _errorMessage =
              'No se encontraron datos de limón en los últimos 7 días';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al consultar datos: ${e.toString()}';
      });
      debugPrint('ERROR: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingPrecios = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double precioSugerido =
        double.tryParse(_precioSugeridoController.text) ?? 0.0;
    final buttonColor = Colors.deepPurple;
    final buttonTextStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    final buttonSize = MediaQuery.of(context).size.width * 0.418;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),

                if (_isLoadingPrecios) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                ],

                if (_errorMessage.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tarjeta unificada de precios
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    elevation: 2,
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Gestión de Precios',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Fila de precios de referencia
                          Row(
                            children: [
                              // Media Nacional
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.deepPurple.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Media Nacional',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _mediaNacional != null
                                            ? '\$${_mediaNacional!.toStringAsFixed(2)}'
                                            : '-- --',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _mediaNacional != null
                                              ? Colors.deepPurple
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Media Local
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Media GDL',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _mediaLocal != null
                                            ? '\$${_mediaLocal!.toStringAsFixed(2)}'
                                            : '-- --',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _mediaLocal != null
                                              ? Colors.green.shade700
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          // Segunda fila: Precio deseado y Precio calculado
                          Row(
                            children: [
                              // Precio deseado
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Precio Deseado',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      TextField(
                                        controller: _precioSugeridoController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: '0.00',
                                          isDense: true,
                                          contentPadding: EdgeInsets.only(
                                            top: 4,
                                          ),
                                        ),
                                        onSubmitted: (value) {
                                          FocusScope.of(context).unfocus();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Precio calculado
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Precio sugerido',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _precioCalculado != null
                                            ? '\$$_precioCalculado'
                                            : _precioAnterior > 0
                                            ? '\$$_precioAnterior'
                                            : '-- --',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _precioCalculado != null
                                              ? Colors.blue.shade700
                                              : (_precioAnterior > 0
                                                    ? Colors.grey.shade600
                                                    : Colors.grey),
                                        ),
                                      ),
                                      if (_precioAnterior > 0 &&
                                          _precioCalculado == null)
                                        Text(
                                          '(Anterior)',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botones en fila horizontal (solo si no se ha guardado el precio)
                if (!_precioGuardado) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingPrecios
                                ? null
                                : _consultarPrecios,
                            icon: const Icon(
                              Icons.sync,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              _isLoadingPrecios
                                  ? 'Consultando...'
                                  : 'Consultar SNIIM',
                              style: buttonTextStyle.copyWith(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Calcular Precio4 después de guardar el precio deseado
                              _calcularPrecio4();
                            },
                            icon: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              'Guardar Precio',
                              style: buttonTextStyle.copyWith(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Notes Overview Widget
                const NotesOverviewWidget(),

                const SizedBox(height: 32),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _HomeSquareButton(
                      label: 'Reparto',
                      icon: Icons.local_shipping,
                      color: buttonColor,
                      size: buttonSize,
                      onTap: () => _goToReparto(context),
                    ),
                    _HomeSquareButton(
                      label: 'Registrar venta',
                      icon: Icons.point_of_sale,
                      color: buttonColor,
                      size: buttonSize,
                      onTap: () => Navigator.pushNamed(context, '/ventas'),
                    ),
                    _clientesExpanded
                        ? SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/nuevo_cliente',
                                      );
                                      setState(() {
                                        _clientesExpanded = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: buttonColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          bottomLeft: Radius.circular(16),
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: SizedBox(
                                      height: buttonSize,
                                      child: Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 8,
                                ), // Small separation between buttons
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/editar_clientes',
                                      );
                                      setState(() {
                                        _clientesExpanded = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: buttonColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: SizedBox(
                                      height: buttonSize,
                                      child: Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _HomeSquareButton(
                            label: 'Clientes',
                            icon: Icons.people,
                            color: buttonColor,
                            size: buttonSize,
                            onTap: () {
                              setState(() {
                                _clientesExpanded = true;
                              });
                            },
                          ),
                    _HomeSquareButton(
                      label: 'Registrar gastos',
                      icon: Icons.attach_money,
                      color: buttonColor,
                      size: buttonSize,
                      onTap: () {},
                    ),
                    _HomeSquareButton(
                      label: 'Sincronización',
                      icon: Icons.sync,
                      color: buttonColor,
                      size: buttonSize,
                      onTap: () =>
                          Navigator.pushNamed(context, '/synchronization'),
                    ),
                    _HomeSquareButton(
                      label: 'Logs',
                      icon: Icons.assessment,
                      color: buttonColor,
                      size: buttonSize,
                      onTap: () => Navigator.pushNamed(context, '/logs'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSquareButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _HomeSquareButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
