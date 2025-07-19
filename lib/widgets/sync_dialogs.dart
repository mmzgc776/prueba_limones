import 'package:flutter/material.dart';
import '../services/sync_service.dart';

/// Manejador centralizado para diálogos de sincronización
class SyncDialogs {
  /// Muestra un diálogo de confirmación para sincronización
  static Future<bool?> showSyncConfirmation(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sincronización Unificada'),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo de confirmación para eliminación
  static Future<bool?> showDeleteConfirmation(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar Datos Locales'),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo de carga
  static void showLoadingDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Muestra un diálogo de éxito
  static void showSuccessDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo de error
  static void showErrorDialog(
    BuildContext context,
    String title,
    String error,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Maneja el resultado de una operación de sincronización
  static void handleSyncResult(
    BuildContext context,
    SyncResult result,
    String successTitle,
  ) {
    Navigator.of(context).pop(); // Close loading dialog

    if (result.success) {
      showSuccessDialog(
        context,
        successTitle,
        result.message,
      );
    } else {
      showErrorDialog(
        context,
        'Error',
        result.message,
      );
    }
  }

  /// Maneja timeout de operaciones
  static void handleTimeout(BuildContext context) {
    Navigator.of(context).pop(); // Close loading dialog
    showErrorDialog(
      context,
      'Error de Tiempo Excedido',
      'La operación ha excedido el tiempo límite de 2 minutos. Por favor, intenta de nuevo más tarde.',
    );
  }
}
