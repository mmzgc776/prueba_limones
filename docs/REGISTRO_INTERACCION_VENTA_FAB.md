---
name: Registro de interacción al vender desde el botón "$" del FAB
severity: defecto funcional (pérdida de datos)
priority: alta
status: pendiente
created: 2026-08-06
category: delivery / ventas / interacciones-cliente
estimated-effort: media-baja
---

# Defecto: Al registrar venta desde el botón "$" del FAB no se guarda la interacción con el cliente

## Resumen

Cuando se registra una venta durante un reparto activo usando el **pequeño botón azul "$"** ubicado a la derecha al pie de la interfaz de reparto, la venta se inserta correctamente en `Sales` pero **no queda registrada ninguna interacción** (`Contactos`) vinculada al reparto ni al cliente.

## Comportamiento actual (incorrecto)

1. Usuario pulsa el botón **"$" mini FAB** (derecha inferior).
2. `fabs.dart :: onPressed` → `Navigator.push(MaterialPageRoute, builder: VentasPage(deliveryNumber: deliveryNumber))`.
3. `VentaForm._saveSale()` → inserta en tabla `Sales` y devuelve `Navigator.pop()`.
4. **Resultado**: Venta registrada ✅, interacción con cliente NO registrada ❌.

## Comportamiento esperado

1. Usuario pulsa el botón **"$" mini FAB**.
2. Se registra la venta (como hoy funciona).
3. **Inmediatamente después**, se inserta un registro de interacción tipo `"Venta"` en la tabla `Contactos` con:
   - `deliveryId = deliveryNumber` actual
   - `clientId = el cliente que compró`
   - `result = 'Venta'`
4. El flujo retorna al reparto manteniendo el estado del cliente seleccionado.

## Diagnóstico

### Flujo de referencia correcto (desde la sección de clientes)

En `section_delivery_page.dart` existe un flujo bien implementado:

```dart
_handleInteraccionAction(String action, int index) {
  _controller.updateContactoStatus(index, true, action);
  // ✅ Se inserta la interacción INMEDIATAMENTE antes de navegar
  final deliveryNumber = _controller.getCurrentDeliveryNumber();
  _deliveryService.insertInteraccionImmediate(
    deliveryId: deliveryNumber,
    clientId: _clientes[index].id,
    result: action,       // ← 'Venta', 'Rechazó', etc.
  );
  if (action == 'Venta') {
    Navigator.push(context, MaterialPageRoute(builder: ... VentaForm));
  } else if (action == 'Encargó') {
    Navigator.push(context, MaterialPageRoute(builder: ... NuevoClientePage));
  }
}
```

**Este flujo funciona perfectamente** porque llama explícitamente a `insertInteraccionImmediate()` antes de navegar.

### Flujo defectuoso (desde el botón "$")

En `fabs.dart` línea ~70-75:

```dart
FloatingActionButton(
  heroTag: 'registrar_venta',
  onPressed: () {
    if (paused) onResumeDelivery();
    final deliveryNumber = DeliveryStateManager().getCurrentDeliveryNumber();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VentasPage(deliveryNumber: deliveryNumber),
      ),
    );
  },
  ...
)
```

**Problema**: No hay llamada a `insertInteraccionImmediate()`. La venta se guarda pero no existe mecanismo para vincular la interacción con el reparto.

Adicionalmente, `VentaForm` al terminar usa `Navigator.pop()` (vuelve al contenedor padre), mientras que desde el flujo de interacciones usa `Navigator.push()` (nueva pantalla). Esto es inconsistente:
- Desde interacciones → nuevo route (`/ventas`)
- Desde FAB → pop directo al delivery

### Raíz del problema

El diseño actual separa conceptualmente "venta" y "interacción con cliente", pero en la práctica el usuario espera que registrar una venta durante un reparto **signifique** que hubo contacto. El botón "$" debería equivaler a pulsar "Venta" en la sección de interacciones del cliente.

## Plan de reparación

### Paso 1: Modificar `fabs.dart` — Insertar interacción antes de navegar al form de ventas

Ubicación: `lib/pages/section_delivery/widgets/fabs.dart`, método `onPressed` del FAB `heroTag: 'registrar_venta'`.

**Código actual:**
```dart
FloatingActionButton(
  heroTag: 'registrar_venta',
  onPressed: () {
    if (paused) onResumeDelivery();
    final deliveryNumber = DeliveryStateManager().getCurrentDeliveryNumber();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => VentasPage(deliveryNumber: deliveryNumber)),
    );
  },
  ...
)
```

**Código propuesto:**
```dart
FloatingActionButton(
  heroTag: 'registrar_venta',
  onPressed: () {
    if (paused) onResumeDelivery();
    
    // Guardar interacción con el cliente antes de abrir el form de venta
    final deliveryNumber = DeliveryStateManager().getCurrentDeliveryNumber();
    _registroInteraccionVenta(deliveryNumber);
    
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => VentasPage(deliveryNumber: deliveryNumber)),
    );
  },
  ...
)
```

### Paso 2: Añadir método `_registroInteraccionVenta()` a `FABs` widget

Debajo de la clase `FABs`, añadir el método auxiliar que inserta la interacción.

**Ubicación:** Al final del archivo `lib/pages/section_delivery/widgets/fabs.dart`.

```dart
/// Registra una interacción tipo 'Venta' para el cliente seleccionado
/// en el reparto actual, antes de abrir el form de venta.
Future<void> _registroInteraccionVenta(int deliveryNumber) async {
  try {
    final DeliveryStateManager stateManager = DeliveryStateManager();
    if (stateManager.isDeliveryActive && stateManager.selectedClienteIndex != null) {
      // Obtener los clientes activos del delivery para encontrar el cliente seleccionado
      // Nota: Necesitamos acceder a la lista de clientes del reparto.
      // Se puede obtener desde DatabaseService.getAllClientes() y filtrar por índice activo
      final clientes = await _dbService.getAllClientes();
      if (stateManager.selectedClienteIndex != null && 
          stateManager.selectedClienteIndex! < clientes.length) {
        final clienteSeleccionado = clientes[stateManager.selectedClienteIndex!];
        
        // Insertar la interacción en Contactos con resultado "Venta"
        await _dbService.insertInteraccion(
          clientId: clienteSeleccionado.id,
          deliveryId: deliveryNumber,
          result: 'Venta',
        );
      }
    }
  } catch (e) {
    debugPrint('Error registrando interacción de venta desde FAB: $e');
    // No bloquear la UX; la venta sigue siendo registrada
  }
}
```

### Paso 3: Alternativa más robusta — Pasar el cliente al botón

Para evitar dependencias del `DeliveryStateManager` (que no expone directamente la lista de clientes), se puede refinar así:

**Opción A:** Agregar un parámetro opcional al constructor de `FABs`:
```dart
final Cliente? clienteSeleccionada; // nuevo parámetro
```

Y pasar el cliente desde `section_delivery_page.dart` donde ya tiene acceso a `_clientes[index]`.

**Opción B:** Usar el `DeliveryStateManager` para obtener el cliente — más simple, pero requiere verificar que exponga la información necesaria.

### Paso 4: Verificar consistencia de navegación

El botón "$" debería comportarse igual que pulsar "Venta" en la sección de interacciones del cliente:
- ✅ Registrar la venta (ya funciona)
- ✅ Registrar la interacción (después de este fix)
- ⚠️ **Coherencia de navegación**: el flujo de interacciones usa `Navigator.push()` con un nuevo `MaterialPageRoute`. El botón "$" usa `Navigator.push()`. Ambos son consistentes.

**Nota:** Si en algún momento se desea que "registrar venta desde FAB" y "seleccionar cliente → pulsar Venta" tengan la misma ruta, esto ya es consistente actualmente (ambos van a `/ventas`).

### Paso 5: Consideración sobre `deliveryNumber`

El botón "$" usa `DeliveryStateManager().getCurrentDeliveryNumber()`. Esto funciona porque:
- Si hay un reparto activo, retorna su número.
- Si no hay reparto activo, retorna `null` o el siguiente disponible.

**Pregunta abierta:** ¿Qué debería pasar si se pulsa "$" cuando NO hay reparto activo?
- Opción 1: Ignorar (la venta queda sin deliveryNumber) — **actual comportamiento implícito**
- Opción 2: Pedir confirmar que no hay reparto → `showDialog` antes de proceder
- Opción 3: Abrir directamente el form de ventas sin vincular al delivery

## Implementación recomendada (mínima y segura)

Aplicar **Paso 1 + Paso 2** con la siguiente implementación limpia en `fabs.dart`:

```dart
class FABs extends StatelessWidget {
  // ... existing fields ...
  
  // NUEVO: campo para cliente seleccionado (opcional, nullable)
  final Cliente? clienteSeleccionada;
  
  const FABs({
    Key? key,
    required this.started,
    required this.paused,
    required this.elapsedSeconds,
    required this.clientesContactados,
    required this.selectedClienteIndex,
    required this.onStartDelivery,
    required this.onPauseDelivery,
    required this.onResumeDelivery,
    required this.onEndDelivery,
    required this.onDebugInteracciones,
    // NUEVO parámetro
    this.clienteSeleccionada, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (started)
          Positioned(
            right: 24, bottom: 14,
            child: FloatingActionButton(
              heroTag: 'registrar_venta',
              onPressed: () async {
                // Primero registrar la interacción
                if (clienteSeleccionada != null && started) {
                  await _insertInteraccionVenta(clienteSeleccionada);
                }
                
                if (paused) onResumeDelivery();
                final deliveryNumber = DeliveryStateManager().getCurrentDeliveryNumber();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VentasPage(deliveryNumber: deliveryNumber),
                  ),
                );
              },
              ... rest of existing code
            ),
          )
        // ... rest unchanged
      ],
    );
  }

  /// Inserta una interacción tipo "Venta" para el cliente seleccionado
  Future<void> _insertInteraccionVenta(Cliente cliente) async {
    try {
      final deliveryNumber = DeliveryStateManager().getCurrentDeliveryNumber();
      if (deliveryNumber != null) {
        await _dbService.insertInteraccion(
          clientId: cliente.id,
          deliveryId: deliveryNumber,
          result: 'Venta',
        );
      }
    } catch (e) {
      debugPrint('Error al insertar interacción de venta desde FAB: $e');
      // No bloquear la UX
    }
  }
}
```

Y en `section_delivery_page.dart`, pasar el cliente seleccionado al FABs:

```dart
floatingActionButton: (_controller.started || _tabController.index == 0)
    ? FABs(
        started: _controller.started,
        paused: _controller.paused,
        elapsedSeconds: _controller.elapsedSeconds,
        clientesContactados: List<bool>.from(_controller.clientesContactados),
        selectedClienteIndex: _controller.selectedClienteIndex,
        clienteSeleccionada: _controller.selectedClienteIndex != null 
            ? _clientes[_controller.selectedClienteIndex]  // ← NUEVO
            : null,
        onStartDelivery: () { ... },
        onPauseDelivery: _controller.pauseDelivery,
        onResumeDelivery: _controller.resumeDelivery,
        onEndDelivery: () { ... },
        onDebugInteracciones: _controller.debugInteracciones,
      )
    : null,
```

## Verificación post-implementación

1. **Ejecutar el reparto** con clientes en la lista.
2. **Seleccionar un cliente** (pulsar la ficha de información del cliente).
3. **Pulsar el botón "$" mini FAB**.
4. **Comprobar en los logs**: buscar `"Venta guardada"` y `"Interacción de venta registrada"`.
5. **Abrir LogsPage** → verificar que `Contactos` tabla tiene un registro con:
   - `result = 'Venta'`
   - `deliveryId = número del reparto actual`
6. **Verificar en la lista de clientes**: el cliente seleccionado debe mostrar estado "Venta" en la ficha de información (si está disponible).

## Dependencias

- No requiere cambios en `database_service.dart` o `delivery_service.dart`.
- Usa métodos existentes: `_dbService.insertInteraccion()`, `DeliveryStateManager().getCurrentDeliveryNumber()`.
