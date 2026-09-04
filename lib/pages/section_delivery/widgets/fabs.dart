import 'package:flutter/material.dart';
import '../../nuevo_cliente_page.dart';
import '../../../data/delivery_state.dart';
import '../../ventas_page.dart';

class FABs extends StatelessWidget {
  final bool started;
  final bool paused;
  final int elapsedSeconds;
  final List<bool> clientesContactados;
  final int? selectedClienteIndex;
  final Function() onStartDelivery;
  final Future<void> Function() onPauseDelivery;
  final Function() onResumeDelivery;
  final Function() onEndDelivery;
  final Function() onDebugInteracciones;

  /// Callback que registra la interacción "Venta" para el cliente
  /// seleccionado antes de navegar al formulario de ventas.
  /// Si no hay cliente seleccionado, no hace nada (no-op).
  final Future<void> Function()? onRegistrarVenta;

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
    this.onRegistrarVenta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (started)
          Positioned(
            left: 24,
            bottom: 14,
            child: FloatingActionButton(
              heroTag: 'nuevo_cliente',
              onPressed: () {
                if (paused) onResumeDelivery();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NuevoClientePage(),
                  ),
                );
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              mini: true,
              tooltip: 'Nuevo cliente',
              child: const Icon(Icons.add, size: 32, color: Colors.white),
            ),
          ),
        if (started)
          Positioned(
            right: 24,
            bottom: 14,
            child: FloatingActionButton(
              heroTag: 'registrar_venta',
              onPressed: () async {
                if (paused) onResumeDelivery();

                // Registrar la interacción "Venta" para el cliente
                // seleccionado antes de abrir el formulario de ventas,
                // consistente con el flujo de _handleInteraccionAction.
                if (onRegistrarVenta != null) {
                  await onRegistrarVenta!();
                }

                // Navigate to sales form with current delivery number
                final deliveryNumber = DeliveryStateManager()
                    .getCurrentDeliveryNumber();
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          VentasPage(deliveryNumber: deliveryNumber),
                    ),
                  );
                }
              },
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              mini: true,
              tooltip: 'Registrar venta',
              child: const Text(
                '\$',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: (!started)
              ? SizedBox(
                  width: 120,
                  height: 120,
                  child: FloatingActionButton(
                    heroTag: 'iniciar_reparto',
                    onPressed: onStartDelivery,
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: const CircleBorder(),
                    tooltip: 'Iniciar reparto',
                    child: const Icon(Icons.play_arrow, size: 64),
                  ),
                )
              : (started && !paused)
              ? SizedBox(
                  width: 120,
                  height: 120,
                  child: FloatingActionButton(
                    heroTag: 'pausar_reparto',
                    onPressed: onPauseDelivery,
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shape: const CircleBorder(),
                    tooltip: 'Detener reparto',
                    child: const Icon(Icons.pause, size: 64),
                  ),
                )
              : (started && paused)
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: FloatingActionButton(
                        heroTag: 'reanudar_reparto',
                        onPressed: onResumeDelivery,
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shape: const CircleBorder(),
                        tooltip: 'Reanudar reparto',
                        child: const Icon(Icons.play_arrow, size: 64),
                      ),
                    ),
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: FloatingActionButton(
                        heroTag: 'terminar_reparto',
                        onPressed: onEndDelivery,
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shape: const CircleBorder(),
                        tooltip: 'Terminar reparto',
                        child: const Icon(Icons.stop, size: 64),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}
