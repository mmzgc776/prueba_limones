import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'sniim_scraper_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web Scraper - SNIIM Limones',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: WebScraperPage(),
    );
  }
}

class WebScraperPage extends StatefulWidget {
  const WebScraperPage({Key? key}) : super(key: key);

  @override
  State<WebScraperPage> createState() => _WebScraperPageState();
}

class _WebScraperPageState extends State<WebScraperPage> {
  WebViewController? _webViewController;
  List<PrecioData> scrapedData = [];
  bool isLoading = false;
  String errorMessage = '';
  bool showWebView = false;

  double? mediaGeneral;
  double? mediaGuadalajara;
  int diasEncontrados = 0;
  int registrosGuadalajara = 0;

  @override
  void initState() {
    super.initState();
    // Inicializar WebView de forma lazy cuando se necesite
  }

  WebViewController _getOrCreateWebViewController() {
    if (_webViewController == null) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('Página iniciada: $url');
            },
            onPageFinished: (String url) {
              debugPrint('Página cargada: $url');
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('Error de recurso web: ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse(
          'https://www.economia-sniim.gob.mx/nuevo/Consultas/MercadosNacionales/PreciosDeMercado/Agricolas/ConsultaFrutasYHortalizas.aspx',
        ));
    }
    return _webViewController!;
  }

  Future<void> _scrapeDataWithWebView() async {
    setState(() {
      isLoading = true;
      scrapedData.clear();
      errorMessage = '';
      mediaGeneral = null;
      mediaGuadalajara = null;
      diasEncontrados = 0;
      registrosGuadalajara = 0;
      showWebView = true;
    });

    try {
      // Inicializar WebViewController si no existe
      _getOrCreateWebViewController();

      final List<PrecioData> allData = [];
      final DateTime today = DateTime.now();
      final DateTime fechaInicio = today.subtract(Duration(days: 7));

      // Esperar a que la página cargue completamente
      await Future.delayed(Duration(seconds: 4));

      debugPrint('=== INICIANDO PROCESO DE SCRAPING ===');

      // PASO 1: Seleccionar producto "Limón s/semilla - Primera"
      debugPrint('PASO 1: Seleccionando producto...');
      final productoSeleccionado = await _seleccionarProducto();
      if (!productoSeleccionado) {
        throw Exception('No se pudo seleccionar el producto');
      }

      // Pequeña espera después de seleccionar producto
      await Future.delayed(Duration(seconds: 1));

      // PASO 2: Establecer fecha de inicio (7 días atrás)
      debugPrint('PASO 2: Estableciendo fecha de inicio: ${_formatearFecha(fechaInicio)}');
      final fechaEstablecida = await _establecerFechaInicio(fechaInicio);
      if (!fechaEstablecida) {
        throw Exception('No se pudo establecer la fecha de inicio');
      }

      // PASO 3: Click en Buscar
      debugPrint('PASO 3: Haciendo click en Buscar...');
      final busquedaExitosa = await _clickBuscar();
      if (!busquedaExitosa) {
        throw Exception('No se pudo hacer click en Buscar');
      }

      // PASO 4: Esperar a que cargue la tabla
      debugPrint('PASO 4: Esperando que cargue la tabla...');
      await Future.delayed(Duration(seconds: 5));

      // PASO 5: Extraer datos de la tabla
      debugPrint('PASO 5: Extrayendo datos de la tabla...');
      allData.addAll(await _extraerDatosTabla());

      debugPrint('=== PROCESO COMPLETADO ===');
      debugPrint('Total de registros encontrados: ${allData.length}');

      // Calcular estadísticas
      setState(() {
        scrapedData = allData;
        showWebView = false;

        if (allData.isNotEmpty) {
          diasEncontrados = 7; // Consultamos últimos 7 días

          // Calcular medias usando precioPorKg
          mediaGeneral = _calcularMediaGeneral(allData);
          mediaGuadalajara = _calcularMediaPorOrigen(allData, 'Guadalajara');

          // Contar registros de Guadalajara
          registrosGuadalajara = allData
              .where((p) => p.origen.toLowerCase().contains('guadalajara'))
              .length;
        } else {
          errorMessage = 'No se encontraron datos de limón en los últimos 7 días';
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error al consultar datos: ${e.toString()}';
        showWebView = false;
      });
      debugPrint('ERROR: ${e.toString()}');
    }

    setState(() {
      isLoading = false;
    });
  }

  // PASO 1: Seleccionar producto del dropdown
  Future<bool> _seleccionarProducto() async {
    final jsCode = '''
      (function() {
        try {
          var select = document.getElementById('ddlProducto');
          if (!select) {
            return 'SELECT_NOT_FOUND';
          }

          // Buscar la opción "Limón s/semilla - Primera"
          var options = select.options;
          for (var i = 0; i < options.length; i++) {
            var optionText = options[i].text.trim().toLowerCase();
            if (optionText.indexOf('limón') >= 0 &&
                optionText.indexOf('semilla') >= 0 &&
                optionText.indexOf('primera') >= 0) {
              select.selectedIndex = i;
              select.value = options[i].value;
              // Disparar evento change
              select.dispatchEvent(new Event('change', { bubbles: true }));
              return 'SUCCESS:' + options[i].text;
            }
          }

          return 'OPTION_NOT_FOUND';
        } catch (e) {
          return 'ERROR:' + e.toString();
        }
      })();
    ''';

    try {
      final controller = _getOrCreateWebViewController();
      final result = await controller.runJavaScriptReturningResult(jsCode);
      final resultStr = result.toString().replaceAll('"', '');
      debugPrint('   Resultado: $resultStr');
      return resultStr.startsWith('SUCCESS');
    } catch (e) {
      debugPrint('   Error: $e');
      return false;
    }
  }

  // PASO 2: Establecer fecha de inicio
  Future<bool> _establecerFechaInicio(DateTime fecha) async {
    final fechaStr = _formatearFecha(fecha);
    final jsCode = '''
      (function() {
        try {
          var input = document.getElementById('txtFechaInicio');
          if (!input) {
            return 'INPUT_NOT_FOUND';
          }

          input.value = '$fechaStr';
          input.dispatchEvent(new Event('change', { bubbles: true }));
          return 'SUCCESS';
        } catch (e) {
          return 'ERROR:' + e.toString();
        }
      })();
    ''';

    try {
      final controller = _getOrCreateWebViewController();
      final result = await controller.runJavaScriptReturningResult(jsCode);
      final resultStr = result.toString().replaceAll('"', '');
      debugPrint('   Resultado: $resultStr');
      return resultStr == 'SUCCESS';
    } catch (e) {
      debugPrint('   Error: $e');
      return false;
    }
  }

  // PASO 3: Click en botón Buscar
  Future<bool> _clickBuscar() async {
    final jsCode = '''
      (function() {
        try {
          var btn = document.getElementById('btnBuscar');
          if (!btn) {
            return 'BUTTON_NOT_FOUND';
          }

          btn.click();
          return 'SUCCESS';
        } catch (e) {
          return 'ERROR:' + e.toString();
        }
      })();
    ''';

    try {
      final controller = _getOrCreateWebViewController();
      final result = await controller.runJavaScriptReturningResult(jsCode);
      final resultStr = result.toString().replaceAll('"', '');
      debugPrint('   Resultado: $resultStr');
      return resultStr == 'SUCCESS';
    } catch (e) {
      debugPrint('   Error: $e');
      return false;
    }
  }

  // PASO 5: Extraer datos de la tabla
  Future<List<PrecioData>> _extraerDatosTabla() async {
    final jsCode = '''
      (function() {
        try {
          var results = [];

          // Buscar todas las tablas en la página
          var tables = document.getElementsByTagName('table');

          for (var t = 0; t < tables.length; t++) {
            var table = tables[t];
            var rows = table.getElementsByTagName('tr');

            // Analizar filas (saltar encabezado)
            for (var i = 1; i < rows.length; i++) {
              var cells = rows[i].getElementsByTagName('td');

              // La tabla debe tener al menos: Producto, Origen, Mercado, Presentación, Preciomin, Preciomax, Preciofrecuente
              if (cells.length >= 7) {
                var producto = (cells[0].innerText || cells[0].textContent || '').trim();

                // Filtrar solo limones
                if (producto.toLowerCase().indexOf('lim') >= 0) {
                  var origen = (cells[1].innerText || cells[1].textContent || '').trim();
                  var mercado = (cells[2].innerText || cells[2].textContent || '').trim();
                  var presentacion = (cells[3].innerText || cells[3].textContent || '').trim();
                  var precioMin = (cells[4].innerText || cells[4].textContent || '0').replace(/[^0-9.]/g, '');
                  var precioMax = (cells[5].innerText || cells[5].textContent || '0').replace(/[^0-9.]/g, '');
                  var precioFrec = (cells[6].innerText || cells[6].textContent || '0').replace(/[^0-9.]/g, '');

                  if (precioFrec && parseFloat(precioFrec) > 0) {
                    results.push({
                      producto: producto,
                      origen: origen,
                      mercado: mercado,
                      presentacion: presentacion,
                      precioMin: precioMin,
                      precioMax: precioMax,
                      precioFrec: precioFrec
                    });
                  }
                }
              }
            }
          }

          return JSON.stringify(results);
        } catch (e) {
          return JSON.stringify({error: e.toString()});
        }
      })();
    ''';

    try {
      final controller = _getOrCreateWebViewController();
      final result = await controller.runJavaScriptReturningResult(jsCode);
      final resultString = result.toString();

      debugPrint('   Datos raw (primeros 300 chars): ${resultString.substring(0, resultString.length > 300 ? 300 : resultString.length)}');

      return _parseTableResult(resultString);
    } catch (e) {
      debugPrint('   Error extrayendo datos: $e');
      return [];
    }
  }

  List<PrecioData> _parseTableResult(String jsonString) {
    final List<PrecioData> precios = [];

    try {
      // Limpiar el string JSON
      jsonString = jsonString.trim();
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString.substring(1, jsonString.length - 1);
      }

      // Decodificar caracteres escapados
      jsonString = jsonString
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '')
          .replaceAll(r'\r', '')
          .replaceAll(r'\t', ' ');

      if (jsonString.startsWith('[') && jsonString.endsWith(']')) {
        final List<dynamic> items = json.decode(jsonString);

        for (final item in items) {
          if (item is Map) {
            final producto = item['producto']?.toString() ?? '';
            final origen = item['origen']?.toString() ?? '';
            final mercado = item['mercado']?.toString() ?? '';
            final presentacion = item['presentacion']?.toString() ?? '';
            final precioMinStr = item['precioMin']?.toString() ?? '0';
            final precioMaxStr = item['precioMax']?.toString() ?? '0';
            final precioFrecStr = item['precioFrec']?.toString() ?? '0';

            final precioMin = double.tryParse(precioMinStr) ?? 0.0;
            final precioMax = double.tryParse(precioMaxStr) ?? 0.0;
            final precioFrec = double.tryParse(precioFrecStr) ?? 0.0;

            if (precioFrec > 0) {
              // Calcular precio por kg según presentación
              final precioPorKg = PrecioData.convertirAPrecioKg(precioFrec, presentacion);

              precios.add(PrecioData(
                fecha: _formatearFecha(DateTime.now().subtract(Duration(days: 7))),
                origen: origen,
                mercado: mercado,
                producto: producto,
                presentacion: presentacion,
                precioMin: precioMin,
                precioMax: precioMax,
                precioFrecuente: precioFrec,
                precioPorKg: precioPorKg,
              ));

              debugPrint('   + $origen - $presentacion: \$${precioFrec.toStringAsFixed(2)} -> \$${precioPorKg.toStringAsFixed(2)}/kg');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parseando JSON: $e\nJSON: $jsonString');
    }

    return precios;
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  double _calcularMediaGeneral(List<PrecioData> precios) {
    if (precios.isEmpty) return 0.0;
    final suma = precios.fold<double>(0.0, (sum, p) => sum + p.precioPorKg);
    return suma / precios.length;
  }

  double _calcularMediaPorOrigen(List<PrecioData> precios, String origen) {
    final preciosFiltrados = precios
        .where((p) => p.origen.toLowerCase().contains(origen.toLowerCase()))
        .toList();

    if (preciosFiltrados.isEmpty) return 0.0;

    final suma =
        preciosFiltrados.fold<double>(0.0, (sum, p) => sum + p.precioPorKg);
    return suma / preciosFiltrados.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Precios Limón - SNIIM'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (showWebView)
            IconButton(
              icon: Icon(Icons.visibility_off),
              onPressed: () {
                setState(() {
                  showWebView = false;
                });
              },
              tooltip: 'Ocultar navegador',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Contenido principal
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!showWebView) ...[
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consulta: Limón s/semilla - Primera',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Últimos 7 días de datos del SNIIM',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Esta consulta usa WebView para obtener datos dinámicos',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _scrapeDataWithWebView,
                    icon: Icon(Icons.search),
                    label: Text('Consultar Precios'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                if (isLoading && !showWebView)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Consultando datos del SNIIM...'),
                        SizedBox(height: 8),
                        Text(
                          'Esto puede tomar 30-60 segundos',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                if (errorMessage.isNotEmpty && !showWebView)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ),
                if (!isLoading && mediaGeneral != null && !showWebView)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resultados - Últimos 7 días',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Días con datos:'),
                              Text(
                                '$diasEncontrados días',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total de registros:'),
                              Text(
                                '${scrapedData.length}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          Text(
                            'MEDIAS DE PRECIO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Media General',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      '(Todos los orígenes)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '\$${mediaGeneral!.toStringAsFixed(2)} / kg',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          if (mediaGuadalajara != null && registrosGuadalajara > 0)
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.shade300, width: 2),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Media Guadalajara',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      Text(
                                        '($registrosGuadalajara registros)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '\$${mediaGuadalajara!.toStringAsFixed(2)} / kg',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: Colors.orange.shade700),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No se encontraron datos de Guadalajara',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                if (!isLoading && scrapedData.isNotEmpty && !showWebView)
                  Expanded(
                    child: Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Detalle de precios',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Divider(height: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: scrapedData.length,
                              itemBuilder: (context, index) {
                                final item = scrapedData[index];
                                final isGuadalajara = item.origen
                                    .toLowerCase()
                                    .contains('guadalajara');

                                return ListTile(
                                  leading: isGuadalajara
                                      ? Icon(Icons.location_city,
                                          color: Colors.green.shade700)
                                      : Icon(Icons.place,
                                          color: Colors.grey.shade600),
                                  title: Text(
                                    item.origen,
                                    style: TextStyle(
                                      fontWeight: isGuadalajara
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${item.mercado}'),
                                      Text(
                                        item.presentacion,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      Text(
                                        'Precio total: \$${item.precioFrecuente.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${item.precioPorKg.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isGuadalajara
                                              ? Colors.green.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        'por kg',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!isLoading &&
                    scrapedData.isEmpty &&
                    errorMessage.isEmpty &&
                    !showWebView)
                  Center(
                    child: Text('Presiona el botón para consultar los precios'),
                  ),
              ],
            ),
          ),
          // WebView oculto o visible
          if (showWebView)
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.blue.shade100,
                    child: Row(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Cargando datos del SNIIM...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: WebViewWidget(controller: _getOrCreateWebViewController()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
