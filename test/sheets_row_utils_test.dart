import 'package:flutter_test/flutter_test.dart';
import 'package:prueba_limones/services/sheets_row_utils.dart';

void main() {
  group('sellerIdOfRow', () {
    test('lee el id cuando la columna existe y es numérica', () {
      expect(sellerIdOfRow([1, 2, 3, '7'], 3), 7);
      expect(sellerIdOfRow([1, 2, 3, 7], 3), 7);
    });

    test(
      'devuelve null cuando la columna falta, está vacía o no es numérica',
      () {
        expect(sellerIdOfRow(['a', 'b'], 8), isNull);
        expect(sellerIdOfRow(['a', 'b', null], 2), isNull);
        expect(sellerIdOfRow(['a', 'b', ''], 2), isNull);
        expect(sellerIdOfRow(['a', 'b', '  '], 2), isNull);
        // Nombre del vendedor en el formato legacy de Repartos.
        expect(sellerIdOfRow([1, 'Moy'], 1), isNull);
        expect(sellerIdOfRow(['a'], -1), isNull);
      },
    );
  });

  group('rowsOwnedByOtherSellers', () {
    final sheetData = <List<Object?>>[
      ['id', 'total', 'seller_id'],
      ['1', '100', '1'],
      ['2', '200', '2'],
      ['3', '300', '3'],
      // Legacy: sin seller_id (3 columnas declaradas, 2 escritas).
      ['4', '400'],
      // Legacy con el nombre del vendedor en la columna del id.
      ['5', '500', 'Moy'],
      ['', '', ''],
    ];

    test('conserva las filas de los demás vendedores al hacer PUSH', () {
      // El vendedor 2 hace PUSH: se conservan 1, 3 y las legacy (del 1).
      final preserved = rowsOwnedByOtherSellers(
        sheetData: sheetData,
        sellerColumnIndex: 2,
        sellerId: 2,
      );
      expect(preserved.map((r) => r[0]), ['1', '3', '4', '5']);
    });

    test('el dueño legacy reemplaza las filas sin seller_id', () {
      final preserved = rowsOwnedByOtherSellers(
        sheetData: sheetData,
        sellerColumnIndex: 2,
        sellerId: kLegacySellerId,
      );
      // Solo se conservan las de otros ids explícitos.
      expect(preserved.map((r) => r[0]), ['2', '3']);
    });

    test('descarta filas totalmente vacías', () {
      final preserved = rowsOwnedByOtherSellers(
        sheetData: [
          ['id', 'seller_id'],
          [null, null],
          ['', ''],
        ],
        sellerColumnIndex: 1,
        sellerId: 1,
      );
      expect(preserved, isEmpty);
    });
  });

  group('normalizedHeaderRow', () {
    const defaults = ['id', 'date', 'total', 'seller_id'];

    test('completa las celdas faltantes con el nombre esperado', () {
      expect(normalizedHeaderRow(['id', 'date', 'total'], defaults: defaults), [
        'id',
        'date',
        'total',
        'seller_id',
      ]);
    });

    test('rellena celdas vacías sin sobrescribir nombres existentes', () {
      expect(
        normalizedHeaderRow(['ID', '', null, 'vendor'], defaults: defaults),
        ['ID', 'date', 'total', 'vendor'],
      );
    });

    test('crea el encabezado completo cuando la hoja está vacía', () {
      expect(normalizedHeaderRow(null, defaults: defaults), defaults);
    });
  });

  group('trailingRowsRange', () {
    test('devuelve el rango sobrante cuando el PUSH quedó más corto', () {
      expect(
        trailingRowsRange('Ventas!A:I', previousRows: 1412, newRows: 100),
        'Ventas!A101:I1412',
      );
    });

    test('devuelve null cuando no hay filas que limpiar', () {
      expect(
        trailingRowsRange('Ventas!A:I', previousRows: 10, newRows: 10),
        isNull,
      );
      expect(
        trailingRowsRange('Ventas!A:I', previousRows: 10, newRows: 12),
        isNull,
      );
      expect(
        trailingRowsRange('Ventas!A:I', previousRows: 0, newRows: 3),
        isNull,
      );
    });

    test('soporta rangos con fila inicial en el nombre de columna', () {
      expect(
        trailingRowsRange('Clientes!A:AD', previousRows: 527, newRows: 30),
        'Clientes!A31:AD527',
      );
    });
  });
}
