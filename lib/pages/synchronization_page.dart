import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart'; // Importar el servicio
import '../services/sync_service.dart';
import '../services/database_service.dart';
import '../widgets/sync_action_button.dart';

class SynchronizationPage extends StatefulWidget {
  const SynchronizationPage({super.key});

  @override
  State<SynchronizationPage> createState() => _SynchronizationPageState();
}

class _SynchronizationPageState extends State<SynchronizationPage> {
  @override
  void initState() {
    super.initState();
    // Inicializar GoogleSheetsService cuando la página se carga
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GoogleSheetsService().init(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();
    final syncService = SyncService(databaseService);
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
            SyncActionButton(
              label: 'Repartos',
              icon: Icons.local_shipping,
              color: Colors.deepPurple,
              size: buttonSize,
              syncType: SyncType.deliveries,
              syncService: syncService,
            ),
            SyncActionButton(
              label: 'Ventas',
              icon: Icons.point_of_sale,
              color: Colors.deepPurple,
              size: buttonSize,
              syncType: SyncType.sales,
              syncService: syncService,
            ),
            SyncActionButton(
              label: 'Clientes',
              icon: Icons.person,
              color: Colors.deepPurple,
              size: buttonSize,
              syncType: SyncType.clients,
              syncService: syncService,
            ),
            SyncActionButton(
              label: 'Gastos',
              icon: Icons.attach_money,
              color: Colors.deepPurple,
              size: buttonSize,
              syncType: SyncType.expenses,
              syncService: syncService,
            ),
            SyncActionButton(
              label: 'Limpiar Base de Datos',
              icon: Icons.delete_forever,
              color: Colors.redAccent,
              size: buttonSize,
              syncType: SyncType.database,
              syncService: syncService,
            ),
            SyncActionButton(
              label: 'Puntuar Clientes',
              icon: Icons.star_rate,
              color: Colors.amber,
              size: buttonSize,
              syncType: SyncType.rateClients,
              syncService: syncService,
            ),
          ],
        ),
      ),
    );
  }
}
