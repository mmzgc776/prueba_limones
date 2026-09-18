/// Reglas puras (sin red ni base de datos) que aplican el modo multi-vendedor
/// a las hojas de Google Sheets. Se aíslan aquí para poder probarlas.
library;

/// Vendedor dueño de las filas escritas antes de que existiera `seller_id`
/// en las hojas (id 1 = "Moy", el único vendedor del modo mono-usuario).
///
/// Tratar esas filas como suyas evita duplicarlas al sincronizar y permite
/// que su dueño las recupere desde la hoja.
const int kLegacySellerId = 1;

/// Devuelve el `seller_id` de una fila, o `null` si la columna no existe,
/// está vacía o no es numérica (filas legacy, encabezados o filas sueltas).
int? sellerIdOfRow(List<Object?> row, int sellerColumnIndex) {
  if (sellerColumnIndex < 0 || row.length <= sellerColumnIndex) return null;
  final raw = row[sellerColumnIndex];
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

/// `true` si la fila no tiene ningún valor (fila totalmente vacía).
bool isBlankRow(List<Object?> row) =>
    row.every((cell) => cell == null || cell.toString().trim().isEmpty);

/// Filas de la hoja que NO pertenecen al vendedor actual y que por tanto deben
/// conservarse cuando ese vendedor hace PUSH.
///
/// Las filas sin `seller_id` se atribuyen a [legacySellerId], de modo que el
/// PUSH de ese vendedor las reemplaza (sin duplicarlas) y el de los demás
/// vendedores las respeta.
List<List<Object?>> rowsOwnedByOtherSellers({
  required List<List<Object?>> sheetData,
  required int sellerColumnIndex,
  required int sellerId,
  int legacySellerId = kLegacySellerId,
}) {
  final preserved = <List<Object?>>[];
  for (final row in sheetData.skip(1)) {
    if (isBlankRow(row)) continue;
    final owner = sellerIdOfRow(row, sellerColumnIndex) ?? legacySellerId;
    if (owner != sellerId) preserved.add(row);
  }
  return preserved;
}

/// Encabezado normalizado a [defaults].length celdas: completa las celdas
/// faltantes y rellena con el nombre esperado las que están vacías, para que
/// el PUSH nunca escriba datos encima de la fila 1.
List<Object?> normalizedHeaderRow(
  List<Object?>? current, {
  required List<String> defaults,
}) {
  final header = <Object?>[...?current];
  while (header.length < defaults.length) {
    header.add('');
  }
  for (var i = 0; i < defaults.length; i++) {
    final value = header[i];
    if (value == null || value.toString().trim().isEmpty) {
      header[i] = defaults[i];
    }
  }
  return header;
}

/// Rango A1 de las filas sobrantes a limpiar cuando el PUSH quedó más corto
/// que el contenido previo de la hoja. Devuelve `null` si no hay nada que
/// limpiar. [range] usa el formato `Hoja!A:Z`.
String? trailingRowsRange(
  String range, {
  required int previousRows,
  required int newRows,
}) {
  if (previousRows <= 0 || newRows >= previousRows) return null;
  final parts = range.split('!');
  final sheetName = parts.first;
  final columns = parts.length > 1 ? parts[1] : 'A:Z';
  final lastColumn = columns.split(':').last.replaceAll(RegExp(r'[0-9]'), '');
  return '$sheetName!A${newRows + 1}:$lastColumn$previousRows';
}
