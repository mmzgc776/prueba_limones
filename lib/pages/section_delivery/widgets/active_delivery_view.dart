import 'package:flutter/material.dart';
import '../../../data/database.dart';
import '../delivery_record.dart';
import 'cliente_info_card.dart';
import 'clientes_list.dart';
import 'timer_display.dart';

class ActiveDeliveryView extends StatelessWidget {
  final bool started;
  final bool paused;
  final String formattedTime;
  final List<Cliente> clientes;
  final List<bool> clientesContactados;
  final List<String> clientesEstado;
  final int? selectedClienteIndex;
  final Function(int) onClienteSelected;
  final Function(int) onShowContactoSheet;
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
    required this.onShowContactoSheet,
    required this.onResumeDelivery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClienteInfoCard(
          selectedClienteIndex: selectedClienteIndex,
          started: started,
          clientes: clientes,
        ),
        ClientesList(
          started: started,
          paused: paused,
          clientes: clientes,
          clientesContactados: clientesContactados,
          clientesEstado: clientesEstado,
          selectedClienteIndex: selectedClienteIndex,
          onClienteSelected: onClienteSelected,
          onShowContactoSheet: onShowContactoSheet,
          onResumeDelivery: onResumeDelivery,
        ),
        TimerDisplay(started: started, formattedTime: formattedTime),
      ],
    );
  }
}
