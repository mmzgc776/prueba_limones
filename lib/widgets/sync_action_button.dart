import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../widgets/sync_dialogs.dart';

/// Widget reutilizable para acciones de sincronización
class SyncActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double size;
  final SyncType syncType;
  final SyncService syncService;

  const SyncActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.size,
    required this.syncType,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: () => _handleSyncAction(context),
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

  Future<void> _handleSyncAction(BuildContext context) async {
    final navigator = Navigator.of(context);

    if (syncType == SyncType.expenses) {
      SyncDialogs.showErrorDialog(
        context,
        'Función no implementada',
        'Funcionalidad de $label aún no implementada.',
      );
      return;
    }

    if (syncType == SyncType.database || syncType == SyncType.rateClients) {
      await _handleSpecialActions(context);
      return;
    }

    final confirm = await SyncDialogs.showSyncConfirmation(
      context,
      'Sincronización de $label',
      '¿Deseas realizar una sincronización unificada con Google Sheets o eliminar datos locales?',
    );

    if (confirm == null) return;

    if (confirm) {
      // Sincronización unificada
      SyncDialogs.showLoadingDialog(
        context,
        'Sincronizando $label',
        'Sincronizando datos con Google Sheets...',
      );

      try {
        final result = await syncService
            .syncData(syncType, context)
            .timeout(const Duration(minutes: 2));

        SyncDialogs.handleSyncResult(
          context,
          result,
          'Sincronización Completa',
        );
      } on TimeoutException {
        SyncDialogs.handleTimeout(context);
      } catch (e) {
        SyncDialogs.handleSyncResult(
          context,
          SyncResult.error('Error al sincronizar $label: $e'),
          'Error',
        );
      }
    } else {
      // Eliminar datos locales
      final deleteConfirm = await SyncDialogs.showDeleteConfirmation(
        context,
        'Eliminar Datos de $label',
        '¿Estás seguro de que deseas eliminar todos los datos locales de $label?',
      );

      if (deleteConfirm == true) {
        SyncDialogs.showLoadingDialog(
          context,
          'Eliminando Datos de $label',
          'Eliminando datos locales de $label...',
        );

        try {
          final result = await syncService.deleteData(syncType, context);
          SyncDialogs.handleSyncResult(context, result, 'Eliminación Completa');
        } catch (e) {
          SyncDialogs.handleSyncResult(
            context,
            SyncResult.error('Error al eliminar datos: $e'),
            'Error',
          );
        }
      }
    }
  }

  Future<void> _handleSpecialActions(BuildContext context) async {
    if (syncType == SyncType.database) {
      final confirm = await SyncDialogs.showDeleteConfirmation(
        context,
        'Confirmar Eliminación',
        '¿Estás seguro de que deseas eliminar toda la base de datos? Esta acción no se puede deshacer.',
      );

      if (confirm == true) {
        SyncDialogs.showLoadingDialog(
          context,
          'Eliminando Base de Datos',
          'Eliminando todos los datos locales...',
        );

        try {
          final result = await syncService.clearDatabase();
          SyncDialogs.handleSyncResult(
            context,
            result,
            'Base de Datos Limpiada',
          );
        } catch (e) {
          SyncDialogs.handleSyncResult(
            context,
            SyncResult.error('Error al limpiar la base de datos: $e'),
            'Error',
          );
        }
      }
    } else if (syncType == SyncType.rateClients) {
      SyncDialogs.showLoadingDialog(
        context,
        'Puntuando Clientes',
        'Contando ventas por cliente...',
      );

      try {
        final result = await syncService.updateClientScores();
        SyncDialogs.handleSyncResult(context, result, 'Puntuación Completada');
      } catch (e) {
        SyncDialogs.handleSyncResult(
          context,
          SyncResult.error('Error al puntuar clientes: $e'),
          'Error',
        );
      }
    }
  }
}
