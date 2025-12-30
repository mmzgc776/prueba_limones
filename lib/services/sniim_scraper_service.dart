import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

class PrecioData {
  final String fecha;
  final String origen;
  final String mercado;
  final String producto;
  final String presentacion; // Ej: "Caja de 25 kg."
  final double precioMin;
  final double precioMax;
  final double precioFrecuente;
  final double precioPorKg; // Precio convertido a pesos/kg

  PrecioData({
    required this.fecha,
    required this.origen,
    required this.mercado,
    required this.producto,
    required this.presentacion,
    required this.precioMin,
    required this.precioMax,
    required this.precioFrecuente,
    required this.precioPorKg,
  });

  @override
  String toString() {
    return 'PrecioData{fecha: $fecha, origen: $origen, mercado: $mercado, producto: $producto, presentacion: $presentacion, precioPorKg: \$${precioPorKg.toStringAsFixed(2)}}';
  }

  // Función para convertir precio según presentación a pesos/kg
  static double convertirAPrecioKg(double precioPromedio, String presentacion) {
    final presentacionLower = presentacion.toLowerCase();

    if (presentacionLower.contains('30 kg')) {
      return precioPromedio / 30;
    } else if (presentacionLower.contains('25 kg')) {
      return precioPromedio / 25;
    } else if (presentacionLower.contains('20 kg')) {
      return precioPromedio / 20;
    } else if (presentacionLower.contains('18 kg')) {
      return precioPromedio / 18;
    } else if (presentacionLower.contains('15 kg')) {
      return precioPromedio / 15;
    } else if (presentacionLower.contains('14 kg')) {
      return precioPromedio / 14;
    } else if (presentacionLower.contains('kilogramo') || presentacionLower.contains('kg.') && !presentacionLower.contains('de')) {
      return precioPromedio; // Ya está en kg
    }

    // Si no reconocemos la presentación, asumimos que es por kg
    return precioPromedio;
  }
}

class SniimScraperService {
  static const String baseUrl = 'https://www.economia-sniim.gob.mx/nuevo';
  static const String iframeRelativePath = 'Consultas/MercadosNacionales/PreciosDeMercado/Agricolas/ConsultaFrutasYHortalizas.aspx';

  final http.Client client = http.Client();

  Map<String, String> _buildHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'es-MX,es;q=0.9,en;q=0.8',
      'Connection': 'keep-alive',
    };
  }

  /// Obtiene precios usando URL GET directa (método simplificado)
  Future<List<PrecioData>> obtenerPreciosDirecto({
    int dias = 7,
    int productoId = 426, // Limón s/semilla - Primera
  }) async {
    final DateTime hoy = DateTime.now();
    final DateTime fechaInicio = hoy.subtract(Duration(days: dias));

    final String fechaInicioStr = _formatearFecha(fechaInicio);
    final String fechaFinalStr = _formatearFecha(hoy);

    print('Consultando precios desde $fechaInicioStr hasta $fechaFinalStr...');

    // Construir URL con parámetros GET
    final url = Uri.parse(
      'https://www.economia-sniim.gob.mx/nuevo/Consultas/MercadosNacionales/PreciosDeMercado/Agricolas/ResultadosConsultaFechaFrutasYHortalizas.aspx'
    ).replace(queryParameters: {
      'fechaInicio': fechaInicioStr,
      'fechaFinal': fechaFinalStr,
      'ProductoId': productoId.toString(),
      'OrigenId': '-1',
      'Origen': 'Todos',
      'DestinoId': '-1',
      'Destino': 'Todos',
      'PreciosPorId': '1',
      'RegistrosPorPagina': '500',
    });

    print('URL: $url');

    try {
      final response = await client.get(url, headers: _buildHeaders());

      if (response.statusCode != 200) {
        throw Exception('Error HTTP: ${response.statusCode}');
      }

      final document = html.parse(response.body);
      final precios = _parsearTablaPrecios(document, fechaInicioStr);

      print('Total de registros obtenidos: ${precios.length}');
      return precios;
    } catch (e) {
      print('Error al obtener precios: $e');
      rethrow;
    }
  }

  Future<List<PrecioData>> obtenerPrecios7Dias({
    String producto = 'Limón',
  }) async {
    final List<PrecioData> todosLosPrecios = [];
    final DateTime hoy = DateTime.now();

    print('Iniciando scraping para los últimos 7 días...');

    // Obtener datos de los últimos 7 días
    for (int i = 0; i < 7; i++) {
      final DateTime fecha = hoy.subtract(Duration(days: i));
      final String fechaStr = _formatearFecha(fecha);

      print('Consultando fecha: $fechaStr');

      try {
        final preciosDia = await _obtenerPreciosPorFecha(fechaStr, producto);
        todosLosPrecios.addAll(preciosDia);

        if (preciosDia.isNotEmpty) {
          print('  Encontrados ${preciosDia.length} registros');
        }

        // Pausa para no saturar el servidor
        await Future.delayed(Duration(milliseconds: 800));
      } catch (e) {
        print('  Error en fecha $fechaStr: $e');
      }
    }

    print('Total de registros obtenidos: ${todosLosPrecios.length}');
    return todosLosPrecios;
  }

  Future<List<PrecioData>> _obtenerPreciosPorFecha(
    String fecha,
    String producto,
  ) async {
    final List<PrecioData> precios = [];

    try {
      // Paso 1: Cargar el iframe inicial
      final iframeUrl = '$baseUrl/$iframeRelativePath?SubOpcion=4';
      print('  Cargando: $iframeUrl');

      final response = await client.get(
        Uri.parse(iframeUrl),
        headers: _buildHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Error HTTP: ${response.statusCode}');
      }

      final document = html.parse(response.body);

      // Extraer ViewState y otros campos necesarios para POST
      final viewState = _extractValue(document, '__VIEWSTATE');
      final viewStateGenerator = _extractValue(document, '__VIEWSTATEGENERATOR');
      final eventValidation = _extractValue(document, '__EVENTVALIDATION');

      if (viewState == null) {
        // Si no hay ViewState, intentar parsear directamente
        return _parsearTablaPrecios(document, fecha);
      }

      // Paso 2: Hacer POST para buscar datos con filtros
      final postData = {
        '__VIEWSTATE': viewState,
        '__VIEWSTATEGENERATOR': viewStateGenerator ?? '',
        '__EVENTVALIDATION': eventValidation ?? '',
        'ctl00\$ContentPlaceHolder1\$txtFechaBusqueda': fecha,
        'ctl00\$ContentPlaceHolder1\$btnBuscar': 'Buscar',
      };

      print('  Haciendo petición POST con fecha: $fecha');

      final postResponse = await client.post(
        Uri.parse(iframeUrl),
        headers: {
          ..._buildHeaders(),
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': iframeUrl,
        },
        body: postData,
      );

      if (postResponse.statusCode == 200) {
        final postDocument = html.parse(postResponse.body);
        precios.addAll(_parsearTablaPrecios(postDocument, fecha));
      }
    } catch (e) {
      print('  Error en _obtenerPreciosPorFecha: $e');
    }

    // Filtrar solo limones
    return precios.where((p) =>
      p.producto.toLowerCase().contains('limón') ||
      p.producto.toLowerCase().contains('limon')
    ).toList();
  }

  String? _extractValue(dom.Document document, String fieldName) {
    final element = document.querySelector('input[name="$fieldName"]');
    return element?.attributes['value'];
  }

  List<PrecioData> _parsearTablaPrecios(dom.Document document, String fecha) {
    final List<PrecioData> precios = [];

    // Buscar todas las tablas
    final tables = document.querySelectorAll('table');

    for (final table in tables) {
      // Buscar si tiene la clase o ID específico de la tabla de precios
      final tableId = table.attributes['id'] ?? '';

      if (tableId.contains('grvPrecios') || tableId.contains('GridView')) {
        precios.addAll(_procesarTabla(table, fecha));
      }
    }

    // Si no encontramos con ID específico, buscar en todas las tablas
    if (precios.isEmpty) {
      for (final table in tables) {
        final tablasPrecios = _procesarTabla(table, fecha);
        if (tablasPrecios.isNotEmpty) {
          precios.addAll(tablasPrecios);
        }
      }
    }

    return precios;
  }

  List<PrecioData> _procesarTabla(dom.Element table, String fecha) {
    final List<PrecioData> precios = [];
    final rows = table.querySelectorAll('tr');

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final cells = row.querySelectorAll('td');

      // La estructura real de la tabla SNIIM es:
      // Fecha, Presentación, Origen, Destino, PrecioMin, PrecioMax, PrecioFrec, [Observaciones]
      if (cells.length >= 7) {
        try {
          final fechaCell = cells[0].text.trim();
          final presentacion = cells[1].text.trim();
          final origen = cells[2].text.trim();
          final destino = cells[3].text.trim();

          final precioMinStr = _limpiarPrecio(cells[4].text.trim());
          final precioMaxStr = _limpiarPrecio(cells[5].text.trim());
          final precioFrecStr = _limpiarPrecio(cells[6].text.trim());

          final precioMin = double.tryParse(precioMinStr) ?? 0.0;
          final precioMax = double.tryParse(precioMaxStr) ?? 0.0;
          final precioFrec = double.tryParse(precioFrecStr) ?? 0.0;

          // Solo agregar si tiene datos válidos
          if (precioFrec > 0 || precioMin > 0 || precioMax > 0) {
            final precioFinal = precioFrec > 0 ? precioFrec : (precioMin + precioMax) / 2;
            final precioPorKg = PrecioData.convertirAPrecioKg(precioFinal, presentacion);

            // Extraer solo el nombre del mercado del destino (formato: "Estado: Mercado")
            String mercado = destino;
            if (destino.contains(':')) {
              mercado = destino.split(':').last.trim();
            }

            precios.add(PrecioData(
              fecha: fechaCell.isNotEmpty ? fechaCell : fecha,
              origen: origen,
              mercado: mercado,
              producto: 'Limón s/semilla - Primera', // Producto fijo ya que filtramos por ProductoId
              presentacion: presentacion,
              precioMin: precioMin,
              precioMax: precioMax,
              precioFrecuente: precioFinal,
              precioPorKg: precioPorKg,
            ));
          }
        } catch (e) {
          // Ignorar filas con formato incorrecto
          continue;
        }
      }
    }

    return precios;
  }

  String _limpiarPrecio(String precio) {
    // Remover todo excepto dígitos y punto decimal
    return precio.replaceAll(RegExp(r'[^\d.]'), '');
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  double calcularMediaGeneral(List<PrecioData> precios) {
    if (precios.isEmpty) return 0.0;
    final suma = precios.fold<double>(0.0, (sum, p) => sum + p.precioPorKg);
    return suma / precios.length;
  }

  double calcularMediaPorOrigen(List<PrecioData> precios, String origen) {
    final preciosFiltrados = precios.where((p) =>
      p.origen.toLowerCase().contains(origen.toLowerCase()) ||
      p.mercado.toLowerCase().contains(origen.toLowerCase())
    ).toList();

    if (preciosFiltrados.isEmpty) return 0.0;

    final suma = preciosFiltrados.fold<double>(0.0, (sum, p) => sum + p.precioPorKg);
    return suma / preciosFiltrados.length;
  }

  Map<String, int> contarRegistrosPorOrigen(List<PrecioData> precios) {
    final Map<String, int> conteo = {};

    for (final precio in precios) {
      conteo[precio.origen] = (conteo[precio.origen] ?? 0) + 1;
    }

    return conteo;
  }

  void dispose() {
    client.close();
  }
}
