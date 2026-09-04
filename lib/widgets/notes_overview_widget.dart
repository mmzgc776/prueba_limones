import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../services/database_service.dart';
import '../pages/section_delivery/delivery_record.dart';
import '../pages/section_delivery/widgets/delivery_detail_view.dart';
import '../pages/editar_clientes_page.dart';
import '../main.dart' show routeObserver;

class NotesOverviewWidget extends StatefulWidget {
  const NotesOverviewWidget({super.key});

  @override
  State<NotesOverviewWidget> createState() => _NotesOverviewWidgetState();
}

class _NotesOverviewWidgetState extends State<NotesOverviewWidget> with RouteAware {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _allNotes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  String _selectedColorFilter = 'all';
  Set<int> _expandedClients = {};
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when this route has been popped off, and the current route shows up
    // This is called when you navigate back to this screen
    refresh();
  }

  /// Public method to refresh the notes list
  void refresh() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _dbService.init();
      final notes = await _dbService.getAllNotasWithClientInfo();
      setState(() {
        _allNotes = notes;
        _isLoading = false;
      });
      // Apply current filter after loading
      _filterNotes();
    } catch (e) {
      debugPrint('Error loading notes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterNotes() {
    setState(() {
      _filteredNotes = _allNotes.where((noteData) {
        final Nota note = noteData['nota'];

        // Filter by color
        final colorMatch = _selectedColorFilter == 'all' ||
            note.color == _selectedColorFilter;

        return colorMatch;
      }).toList();
    });
  }

  Color _getColorFromString(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconFromColor(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'red':
        return Icons.attach_money;
      case 'blue':
        return Icons.info;
      case 'yellow':
        return Icons.warning;
      case 'orange':
        return Icons.notifications;
      default:
        return Icons.note;
    }
  }

  Map<int, List<Map<String, dynamic>>> _groupNotesByClient() {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final noteData in _filteredNotes) {
      final Nota note = noteData['nota'];
      grouped.putIfAbsent(note.clientId, () => []).add(noteData);
    }
    return grouped;
  }

  Future<void> _deleteNote(int noteId) async {
    try {
      await _dbService.deleteNota(noteId);
      await _loadNotes();
      _filterNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota eliminada')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar nota')),
        );
      }
    }
  }

  void _showDeleteConfirmation(int noteId, String noteText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: Text('¿Seguro que deseas eliminar esta nota?\n\n"$noteText"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteNote(noteId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNoteTap(Map<String, dynamic> noteData) async {
    final Nota note = noteData['nota'];

    if (note.ventaId != null && noteData['deliveryNumber'] != null) {
      // Si tiene ventaId, navegar al detalle del reparto
      final deliveryNumber = noteData['deliveryNumber'] as int;

      // Obtener los datos completos del delivery
      try {
        final delivery = await _dbService.getAllDeliveries();
        final targetDelivery = delivery.firstWhere(
          (d) => d.deliveryNumber == deliveryNumber,
        );

        final deliveryRecord = DeliveryRecord(
          deliveryNumber: targetDelivery.deliveryNumber,
          date: targetDelivery.date,
          duration: Duration(seconds: targetDelivery.durationSeconds),
          avgPrice: targetDelivery.avgPrice,
          kilograms: targetDelivery.kilograms,
          boxes: targetDelivery.boxes,
          remaining: targetDelivery.remaining,
          sellerId: targetDelivery.sellerId,
          total: targetDelivery.total,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryDetailView(
                deliveryRecord: deliveryRecord,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error navigating to delivery detail: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al abrir el detalle del reparto'),
            ),
          );
        }
      }
    } else {
      // Si no tiene ventaId, navegar a editar cliente con el clientId precargado
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditarClientesPage(
              preloadClientId: note.clientId,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final groupedNotes = _groupNotesByClient();
    final totalNotes = _filteredNotes.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.sticky_note_2,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$totalNotes nota${totalNotes != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Color filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ColorFilterChip(
                          label: 'Todas',
                          color: Colors.grey,
                          isSelected: _selectedColorFilter == 'all',
                          onSelected: () {
                            setState(() {
                              _selectedColorFilter = 'all';
                              _filterNotes();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ColorFilterChip(
                          label: 'Pendiente',
                          color: Colors.red,
                          isSelected: _selectedColorFilter == 'red',
                          onSelected: () {
                            setState(() {
                              _selectedColorFilter = 'red';
                              _filterNotes();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ColorFilterChip(
                          label: 'Info',
                          color: Colors.blue,
                          isSelected: _selectedColorFilter == 'blue',
                          onSelected: () {
                            setState(() {
                              _selectedColorFilter = 'blue';
                              _filterNotes();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ColorFilterChip(
                          label: 'Alerta',
                          color: Colors.orange,
                          isSelected: _selectedColorFilter == 'orange',
                          onSelected: () {
                            setState(() {
                              _selectedColorFilter = 'orange';
                              _filterNotes();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _ColorFilterChip(
                          label: 'Éxito',
                          color: Colors.green,
                          isSelected: _selectedColorFilter == 'green',
                          onSelected: () {
                            setState(() {
                              _selectedColorFilter = 'green';
                              _filterNotes();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes list
                  if (_filteredNotes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No hay notas',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groupedNotes.length,
                      itemBuilder: (context, index) {
                          final clientId = groupedNotes.keys.elementAt(index);
                          final clientNotes = groupedNotes[clientId]!;
                          final clientName = clientNotes.first['clientName'] as String;
                          final isExpanded = _expandedClients.contains(clientId);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepPurple,
                                    child: Text(
                                      clientName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    clientName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${clientNotes.length} nota${clientNotes.length != 1 ? 's' : ''}',
                                  ),
                                  trailing: Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedClients.remove(clientId);
                                      } else {
                                        _expandedClients.add(clientId);
                                      }
                                    });
                                  },
                                ),
                                if (isExpanded)
                                  ...clientNotes.map((noteData) {
                                    final Nota note = noteData['nota'];
                                    final color = _getColorFromString(
                                      note.color,
                                    );
                                    final icon = _getIconFromColor(note.color);
                                    final ventaTotal = noteData['ventaTotal'] as double?;
                                    final deliveryNumber = noteData['deliveryNumber'] as int?;
                                    final ventaDate = noteData['ventaDate'] as DateTime?;
                                    final ventaQuantity = noteData['ventaQuantity'] as double?;

                                    return InkWell(
                                      onTap: () => _handleNoteTap(noteData),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: color.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              icon,
                                              color: color,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    note.nota,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (note.ventaId != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                      child: Wrap(
                                                        spacing: 8,
                                                        runSpacing: 4,
                                                        children: [
                                                          if (ventaDate != null)
                                                            Container(
                                                              padding: const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green[100],
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                  4,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                DateFormat('dd/MM/yyyy').format(ventaDate),
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.green[900],
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          Container(
                                                            padding: const EdgeInsets
                                                                .symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.grey[300],
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                4,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Venta #${note.ventaId}',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.grey[700],
                                                              ),
                                                            ),
                                                          ),
                                                          if (deliveryNumber != null)
                                                            Container(
                                                              padding: const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.blue[100],
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                  4,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                'Reparto #$deliveryNumber',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.blue[900],
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          if (ventaQuantity != null)
                                                            Container(
                                                              padding: const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.teal[100],
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                  4,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                '${ventaQuantity.toStringAsFixed(1)} kg',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.teal[900],
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          if (ventaTotal != null)
                                                            Container(
                                                              padding: const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.red[100],
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                  4,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                '\$${ventaTotal.toStringAsFixed(2)}',
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.red[900],
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                              ),
                                              color: Colors.red,
                                              onPressed: () =>
                                                  _showDeleteConfirmation(
                                                note.id,
                                                note.nota,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColorFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onSelected;

  const _ColorFilterChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color.withOpacity(0.9) : color.withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
