import 'package:flutter/material.dart';
import '../data/database.dart';
import '../services/database_service.dart';

enum NotesContainerType { client, sale }

class NotesContainer extends StatefulWidget {
  final int clientId;
  final int? saleId;
  final NotesContainerType type;

  const NotesContainer({
    super.key,
    required this.clientId,
    this.saleId,
    required this.type,
  });

  @override
  State<NotesContainer> createState() => _NotesContainerState();
}

class _NotesContainerState extends State<NotesContainer> {
  List<Nota> _notas = [];
  bool _isLoading = true;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadNotas();
  }

  Future<void> _loadNotas() async {
    try {
      await _dbService.init();
      final notas = await _dbService.getNotasByClientId(widget.clientId);
      // Filter notes based on context
      final filteredNotas = widget.type == NotesContainerType.sale
          ? notas
                .where(
                  (nota) =>
                      nota.ventaId == null || nota.ventaId == widget.saleId,
                )
                .toList()
          : notas.where((nota) => nota.ventaId == null).toList();

      setState(() {
        _notas = filteredNotas;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNota(String notaText, String color) async {
    try {
      await _dbService.init();
      await _dbService.insertNota(
        nota: notaText,
        clientId: widget.clientId,
        ventaId: widget.saleId,
        color: color,
      );
      _loadNotas(); // Reload notas
    } catch (e) {
      debugPrint('Error adding nota: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al agregar la nota')));
    }
  }

  Future<void> _deleteNota(int notaId) async {
    try {
      await _dbService.init();
      await _dbService.deleteNota(notaId);
      _loadNotas(); // Reload notas
    } catch (e) {
      debugPrint('Error deleting nota: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar la nota')),
      );
    }
  }

  void _showAddNoteDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar nota'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Escribe la nota...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Descartar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addNota(controller.text.trim(), 'blue'); // Default color
                Navigator.of(context).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showSaleNoteOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar nota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                _addNota('Pendiente de pago', 'red');
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Pendiente de pago'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAddNoteDialog();
              },
              child: const Text('Agregar nota'),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        if (widget.type == NotesContainerType.client) {
          _showAddNoteDialog();
        } else {
          _showSaleNoteOptions();
        }
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _notas.isEmpty
              ? const Center(
                  child: Text(
                    'Toca aquí para agregar una nota',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _notas.map((nota) {
                    return Chip(
                      label: Text(nota.nota),
                      backgroundColor: _getColorFromString(
                        nota.color,
                      ).withOpacity(0.2),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _deleteNota(nota.id),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}
