import 'package:flutter/material.dart';
import '../../../data/database.dart';
import '../delivery_record.dart';
import 'cliente_info_card.dart';
import 'clientes_list.dart';
import 'delivery_progress_view.dart';

class ActiveDeliveryView extends StatefulWidget {
  final bool started;
  final bool paused;
  final String formattedTime;
  final List<Cliente> clientes;
  final List<bool> clientesContactados;
  final List<String> clientesEstado;
  final int? selectedClienteIndex;
  final Function(int) onClienteSelected;
  final Function(int) onShowInteraccionSheet;
  final VoidCallback onResumeDelivery;

  const ActiveDeliveryView({
    Key? key,
    required this.started,
    required this.paused,
    required this.formattedTime,
    required this.clientes,
    required this.clientesContactados,
    required this.clientesEstado,
    required this.selectedClienteIndex,
    required this.onClienteSelected,
    required this.onShowInteraccionSheet,
    required this.onResumeDelivery,
  }) : super(key: key);

  @override
  State<ActiveDeliveryView> createState() => _ActiveDeliveryViewState();
}

class _ActiveDeliveryViewState extends State<ActiveDeliveryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pestañas
        Material(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(
                icon: Icon(Icons.people),
                text: 'Clientes',
              ),
              Tab(
                icon: Icon(Icons.assessment),
                text: 'Progreso',
              ),
            ],
          ),
        ),

        // Contenido de las pestañas
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Primera pestaña: Vista original de clientes
              Column(
                children: [
                  // Tarjeta de información del cliente
                  ClienteInfoCard(
                    selectedClienteIndex: widget.selectedClienteIndex,
                    started: widget.started,
                    clientes: widget.clientes,
                  ),
                  // Lista de clientes (expandida)
                  Expanded(
                    child: ClientesList(
                      started: widget.started,
                      paused: widget.paused,
                      clientes: widget.clientes,
                      clientesContactados: widget.clientesContactados,
                      clientesEstado: widget.clientesEstado,
                      selectedClienteIndex: widget.selectedClienteIndex,
                      onClienteSelected: widget.onClienteSelected,
                      onShowInteraccionSheet: widget.onShowInteraccionSheet,
                      onResumeDelivery: widget.onResumeDelivery,
                    ),
                  ),
                ],
              ),

              // Segunda pestaña: Vista de progreso del reparto
              const DeliveryProgressView(),
            ],
          ),
        ),
      ],
    );
  }
}
