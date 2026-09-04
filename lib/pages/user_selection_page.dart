import 'package:flutter/material.dart';
import '../data/database.dart';
import '../services/database_service.dart';
import '../services/user_session_service.dart';
import '../services/google_sheets_service.dart';
import '../main.dart' show MyHomePage;

class UserSelectionPage extends StatefulWidget {
  const UserSelectionPage({super.key});

  @override
  State<UserSelectionPage> createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends State<UserSelectionPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Usuario> _usuarios = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _dbService.init();
      final usuarios = await _dbService.getAllUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading usuarios: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncUsuariosFromSheets() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      await _dbService.init();
      if (mounted) {
        GoogleSheetsService().init(context);
      }
      await _dbService.syncUsuariosUnified(
        context: context,
        spreadsheetId: '1f72gI91Qvz9a2wcakgLLiCgPTzWHauYen5cD4kJL4ys',
        range: 'Usuarios!A:D',
      );
      await _loadUsuarios();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuarios sincronizados desde Google Sheets')),
      );
    } catch (e) {
      debugPrint('Error syncing usuarios: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al sincronizar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _selectUsuario(Usuario usuario) async {
    try {
      final session = UserSessionService();
      await session.setCurrentSeller(usuario.id, usuario.nombre);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: 'Limones el Patito'),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error selecting usuario: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al seleccionar usuario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Seleccionar Repartidor'),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _syncUsuariosFromSheets,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            tooltip: 'Sincronizar usuarios',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _usuarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay usuarios registrados',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sincroniza desde Google Sheets o recarga',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _syncUsuariosFromSheets,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download),
                        label: Text(_isSyncing
                            ? 'Sincronizando...'
                            : 'Sincronizar desde Google Sheets'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadUsuarios,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recargar'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = _usuarios[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            usuario.nombre.isNotEmpty
                                ? usuario.nombre[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          usuario.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('ID: ${usuario.id}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectUsuario(usuario),
                      ),
                    );
                  },
                ),
    );
  }
}