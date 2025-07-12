import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SynchronizationPage extends StatelessWidget {
  const SynchronizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonColor = Colors.deepPurple;
    final buttonSize = MediaQuery.of(context).size.width * 0.44;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Sincronización'),
      ),
      body: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            _SyncSquareButton(
              label: 'Repartos',
              icon: Icons.local_shipping,
              color: buttonColor,
              size: buttonSize,
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    title: const Text('Sincronización de Repartos'),
                    content: const Text(
                      '¿Deseas realizar una sincronización unificada con Google Sheets o eliminar datos locales?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          navigator.pop(); // Close selection dialog

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              title: Text('Sincronizando Repartos'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Sincronizando datos con Google Sheets...',
                                  ),
                                ],
                              ),
                            ),
                          );

                          try {
                            final databaseService = DatabaseService();
                            await databaseService.init();

                            final syncFuture = databaseService
                                .syncDeliveriesUnified(
                                  context: context,
                                  spreadsheetId:
                                      '1f72gI91Qvz9a2wcakgLLiCgPTzWHauYen5cD4kJL4ys',
                                  range: 'Repartos!A1:I300',
                                )
                                .then((result) {
                                  print(
                                    'Sincronización unificada de repartos completada.',
                                  );
                                  return result;
                                })
                                .catchError((error) {
                                  print(
                                    'Error durante sincronización unificada de repartos: $error',
                                  );
                                  throw error;
                                });

                            await syncFuture.timeout(
                              const Duration(minutes: 2),
                            );

                            // Success
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Sincronización Completa'),
                                  content: const Text(
                                    'Repartos sincronizados con éxito con Google Sheets.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } on TimeoutException {
                            // Timeout
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error de Tiempo Excedido'),
                                  content: const Text(
                                    'La operación ha excedido el tiempo límite de 2 minutos. Por favor, intenta de nuevo más tarde.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            // Other error
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(
                                    'Error al sincronizar repartos: $e',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Sincronización Unificada'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          navigator.pop(); // Close selection dialog

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              title: Text('Eliminando Datos de Repartos'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Eliminando datos locales de repartos...',
                                  ),
                                ],
                              ),
                            ),
                          );

                          try {
                            final databaseService = DatabaseService();
                            await databaseService.init();
                            await databaseService.deleteAllDeliveries();

                            // Success
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Eliminación Completa'),
                                  content: const Text(
                                    'Datos de repartos eliminados con éxito de la base de datos local.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            // Error
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(
                                    'Error al eliminar datos de repartos: $e',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Eliminar Datos Locales'),
                      ),
                    ],
                  ),
                );
              },
            ),
            _SyncSquareButton(
              label: 'Ventas',
              icon: Icons.point_of_sale,
              color: buttonColor,
              size: buttonSize,
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    title: const Text('Sincronización de Ventas'),
                    content: const Text(
                      '¿Deseas realizar una sincronización unificada con Google Sheets o eliminar datos locales?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          navigator.pop(); // Close selection dialog

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              title: Text('Sincronizando Ventas'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Sincronizando datos con Google Sheets...',
                                  ),
                                ],
                              ),
                            ),
                          );

                          try {
                            final databaseService = DatabaseService();
                            await databaseService.init();

                            final syncFuture = databaseService
                                .syncSalesUnified(
                                  context: context,
                                  spreadsheetId:
                                      '1f72gI91Qvz9a2wcakgLLiCgPTzWHauYen5cD4kJL4ys',
                                  range: 'Ventas!A1:H300',
                                )
                                .then((result) {
                                  print(
                                    'Sincronización unificada de ventas completada.',
                                  );
                                  return result;
                                })
                                .catchError((error) {
                                  print(
                                    'Error durante sincronización unificada de ventas: $error',
                                  );
                                  throw error;
                                });

                            await syncFuture.timeout(
                              const Duration(minutes: 2),
                            );

                            // Success
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Sincronización Completa'),
                                  content: const Text(
                                    'Ventas sincronizadas con éxito con Google Sheets.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } on TimeoutException {
                            // Timeout
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error de Tiempo Excedido'),
                                  content: const Text(
                                    'La operación ha excedido el tiempo límite de 2 minutos. Por favor, intenta de nuevo más tarde.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            // Other error
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(
                                    'Error al sincronizar ventas: $e',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Sincronización Unificada'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          navigator.pop(); // Close selection dialog

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              title: Text('Eliminando Datos de Ventas'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Eliminando datos locales de ventas...'),
                                ],
                              ),
                            ),
                          );

                          try {
                            final databaseService = DatabaseService();
                            await databaseService.init();
                            await databaseService.deleteAllSales();

                            // Success
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Eliminación Completa'),
                                  content: const Text(
                                    'Datos de ventas eliminados con éxito de la base de datos local.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            // Error
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(
                                    'Error al eliminar datos de ventas: $e',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Eliminar Datos Locales'),
                      ),
                    ],
                  ),
                );
              },
            ),
            _SyncSquareButton(
              label: 'Clientes',
              icon: Icons.person,
              color: buttonColor,
              size: buttonSize,
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    title: const Text('Sincronización de Clientes'),
                    content: const Text(
                      '¿Deseas realizar una sincronización unificada con Google Sheets o eliminar datos locales?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          navigator.pop(); // Close selection dialog

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              title: Text('Sincronizando Clientes'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Sincronizando datos con Google Sheets...',
                                  ),
                                ],
                              ),
                            ),
                          );

                          try {
                            final databaseService = DatabaseService();
                            await databaseService.init();

                            final syncFuture = databaseService
                                .syncClientesUnified(
                                  context: context,
                                  spreadsheetId:
                                      '1f72gI91Qvz9a2wcakgLLiCgPTzWHauYen5cD4kJL4ys',
                                  range: 'Clientes!A1:N300',
                                )
                                .then((result) {
                                  print('Sincronización unificada completada.');
                                  return result;
                                })
                                .catchError((error) {
                                  print(
                                    'Error durante sincronización unificada: $error',
                                  );
                                  throw error;
                                });

                            await syncFuture.timeout(
                              const Duration(minutes: 2),
                            );

                            // Success
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Sincronización Completa'),
                                  content: const Text(
                                    'Clientes sincronizados con éxito con Google Sheets.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } on TimeoutException {
                            // Timeout
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error de Tiempo Excedido'),
                                  content: const Text(
                                    'La operación ha excedido el tiempo límite de 2 minutos. Por favor, intenta de nuevo más tarde.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            // Other error
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(
                                    'Error al sincronizar clientes: $e',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Sincronización Unificada'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          navigator.pop(); // Close selection dialog

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const AlertDialog(
                              title: Text('Eliminando Datos de Clientes'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Eliminando datos locales de clientes...',
                                  ),
                                ],
                              ),
                            ),
                          );

                          try {
                            final databaseService = DatabaseService();
                            await databaseService.init();
                            await databaseService.deleteAllClientes();

                            // Success
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Eliminación Completa'),
                                  content: const Text(
                                    'Datos de clientes eliminados con éxito de la base de datos local.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            // Error
                            if (navigator.context.mounted) {
                              navigator.pop(); // Close loading
                              showDialog(
                                context: navigator.context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(
                                    'Error al eliminar datos de clientes: $e',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Eliminar Datos Locales'),
                      ),
                    ],
                  ),
                );
              },
            ),
            _SyncSquareButton(
              label: 'Gastos',
              icon: Icons.attach_money,
              color: buttonColor,
              size: buttonSize,
              onTap: () {
                // TODO: Implement navigation or functionality for Gastos
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    title: const Text('Gastos'),
                    content: const Text(
                      'Funcionalidad de sincronización de gastos aún no implementada.',
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
            ),
            _SyncSquareButton(
              label: 'Limpiar Base de Datos',
              icon: Icons.delete_forever,
              color: Colors.redAccent,
              size: buttonSize,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmar Eliminación'),
                    content: const Text(
                      '¿Estás seguro de que deseas eliminar toda la base de datos? Esta acción no se puede deshacer.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Eliminar Todo'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      title: Text('Eliminando Base de Datos'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Eliminando todos los datos locales...'),
                        ],
                      ),
                    ),
                  );
                  try {
                    final databaseService = DatabaseService();
                    await databaseService.init();
                    await databaseService.deleteAllSales();
                    await databaseService.deleteAllDeliveries();
                    await databaseService.deleteAllClientes();
                    Navigator.of(context).pop(); // Close loading dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Base de Datos Limpiada'),
                        content: const Text(
                          'Todos los datos han sido eliminados con éxito.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    Navigator.of(context).pop(); // Close loading dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Error'),
                        content: Text('Error al limpiar la base de datos: $e'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncSquareButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _SyncSquareButton({
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
