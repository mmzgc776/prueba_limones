import 'package:flutter/material.dart';
import 'pages/section1_page.dart';
import 'pages/section2_page.dart';
import 'pages/section_delivery_page.dart';
import 'pages/nuevo_cliente_page.dart';
import 'pages/synchronization_page.dart';
import 'data/delivery_state.dart';

void main() {
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
      routes: {
        '/section1': (context) => const Section1Page(),
        '/section2': (context) => const Section2Page(),
        '/section_delivery': (context) => const SectionDeliveryPage(),
        '/nuevo_cliente': (context) => const NuevoClientePage(),
        '/synchronization': (context) => const SynchronizationPage(),
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
  }

  @override
  void dispose() {
    _precioSugeridoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double mediaNacional = 0.0; // Valor dinámico, puedes actualizarlo
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
                const Text(
                  'Media nacional:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '4${mediaNacional.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Precio sugerido:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _precioSugeridoController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                  ),
                  onSubmitted: (value) {
                    FocusScope.of(context).unfocus();
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          DeliveryStateManager().setCurrentPrice(
                            precioSugerido,
                          );
                        });
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Precio agregado'),
                            content: Text(
                              'Precio sugerido de ${precioSugerido.toStringAsFixed(2)} ha sido guardado.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Agregar precio', style: buttonTextStyle),
                    ),
                  ),
                ),
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
                      onTap: () => Navigator.pushNamed(context, '/section2'),
                    ),
                    _HomeSquareButton(
                      label: 'Nuevo cliente',
                      icon: Icons.person_add,
                      color: buttonColor,
                      size: buttonSize,
                      onTap: () =>
                          Navigator.pushNamed(context, '/nuevo_cliente'),
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
