import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryView extends StatefulWidget {
  final List<Map<String, dynamic>> historyData;
  final VoidCallback onRefresh;
  final bool showSearchBox;
  final bool showRefreshButton;

  const HistoryView({
    Key? key,
    required this.historyData,
    required this.onRefresh,
    this.showSearchBox = true,
    this.showRefreshButton = true,
  }) : super(key: key);

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_searchQuery.isEmpty) {
      return widget.historyData;
    }

    final query = _searchQuery.toLowerCase();
    return widget.historyData.where((entry) {
      final clientName = (entry['clientName'] as String).toLowerCase();
      final contactName = (entry['contactName'] as String).toLowerCase();
      final businessName = (entry['businessName'] as String).toLowerCase();
      return clientName.contains(query) ||
             contactName.contains(query) ||
             businessName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de búsqueda - solo mostrar si showSearchBox es true
        if (widget.showSearchBox)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente, contacto o negocio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

        // Contador de resultados y botón de refresh
        if (widget.showSearchBox || widget.showRefreshButton)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: widget.showSearchBox ? 0 : 8.0,
            ),
            child: Row(
              children: [
                if (widget.showSearchBox)
                  Text(
                    '${_filteredHistory.length} ${_filteredHistory.length == 1 ? 'resultado' : 'resultados'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                const Spacer(),
                if (widget.showRefreshButton)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: widget.onRefresh,
                    tooltip: 'Actualizar historial',
                  ),
              ],
            ),
          ),

        // Lista de historial
        Expanded(
          child: _filteredHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.history
                            : Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No hay historial disponible'
                            : 'No se encontraron resultados',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredHistory.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredHistory[index];
                    return _buildHistoryCard(entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final isSale = entry['type'] == 'sale';
    final clientName = entry['clientName'] as String;
    final businessName = entry['businessName'] as String;
    final deliveryNumber = entry['deliveryNumber'] as int;
    final timestamp = entry['timestamp'] as DateTime;
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        onTap: isSale ? () => _navigateToSale(entry) : null,
        leading: CircleAvatar(
          backgroundColor: isSale ? Colors.green[100] : Colors.blue[100],
          child: Icon(
            isSale ? Icons.shopping_cart : Icons.person,
            color: isSale ? Colors.green[700] : Colors.blue[700],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clientName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              businessName,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (isSale)
              Text(
                'Venta: ${entry['quantity']} kg',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                entry['interactionType'] as String,
                style: TextStyle(
                  color: _getInteractionColor(
                    entry['interactionType'] as String,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      dateFormatter.format(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Reparto #$deliveryNumber',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: isSale
            ? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400])
            : null,
      ),
    );
  }

  void _navigateToSale(Map<String, dynamic> entry) {
    final saleId = entry['saleId'] as int;
    Navigator.pushNamed(
      context,
      '/edit_sale',
      arguments: saleId,
    );
  }

  Color _getInteractionColor(String interactionType) {
    switch (interactionType) {
      case 'Venta':
        return Colors.green[700]!;
      case 'Rechazó':
        return Colors.red[700]!;
      case 'No estaba':
        return Colors.orange[700]!;
      case 'Encargó':
        return Colors.purple[700]!;
      default:
        return Colors.blue[700]!;
    }
  }
}
