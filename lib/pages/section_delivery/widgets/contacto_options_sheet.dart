import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/database.dart';
import '../../../services/delivery_service.dart';
import 'contacto_section.dart';

class ContactoOptionsSheet extends StatelessWidget {
  final Cliente cliente;
  final int index;
  final Function(bool, String) onContactoUpdated;
  final Function(String) onActionSelected;
  final DeliveryService deliveryService;

  const ContactoOptionsSheet({
    Key? key,
    required this.cliente,
    required this.index,
    required this.onContactoUpdated,
    required this.onActionSelected,
    required this.deliveryService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.phone_outlined, color: Colors.deepPurple),
            title: const Text('Llamada'),
            onTap: () async {
              onContactoUpdated(true, '');
              final phoneNumber = (cliente.telefono.isNotEmpty)
                  ? cliente.telefono
                  : '3333333333';
              final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);

              // Request CALL_PHONE permission
              var status = await Permission.phone.status;
              if (!status.isGranted) {
                status = await Permission.phone.request();
              }

              if (status.isGranted) {
                bool canLaunch = await canLaunchUrl(telUri);
                if (canLaunch) {
                  await launchUrl(telUri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No se pudo iniciar la llamada. Por favor, marque manualmente: $phoneNumber',
                      ),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Permiso de llamada denegado. Por favor, habilite el permiso en la configuración de la aplicación.',
                    ),
                  ),
                );
              }
              Navigator.pop(context);
              // Mostrar sección de contacto después de llamada
              showModalBottomSheet(
                context: context,
                builder: (context) => ContactoSection(
                  onActionSelected: (action) {
                    Navigator.pop(context);
                    onActionSelected(action);
                  },
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.location_on_outlined,
              color: Colors.deepPurple,
            ),
            title: const Text('Visita'),
            onTap: () async {
              onContactoUpdated(true, '');
              final messenger = ScaffoldMessenger.of(context);
              // Solicitar permisos y obtener la localización
              try {
                await deliveryService.getCurrentLocation();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Localización obtenida. Seleccione una acción de contacto en la próxima pantalla.',
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
                Navigator.pop(context);
                // Mostrar sección de contacto después de Visita
                showModalBottomSheet(
                  context: context,
                  builder: (context) => ContactoSection(
                    onActionSelected: (action) {
                      Navigator.pop(context);
                      onActionSelected(action);
                    },
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al obtener la localización: $e'),
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.message_outlined,
              color: Colors.deepPurple,
            ),
            title: const Text('Mensaje'),
            onTap: () async {
              onContactoUpdated(true, '');
              final phoneNumber = (cliente.telefono.isNotEmpty)
                  ? cliente.telefono
                  : '3333333333';
              final Uri whatsappUri = Uri.parse(
                'whatsapp://send?phone=$phoneNumber',
              );
              if (await canLaunchUrl(whatsappUri)) {
                await launchUrl(whatsappUri);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
                );
              }
              Navigator.pop(context);
              // Mostrar sección de contacto después de mensaje
              showModalBottomSheet(
                context: context,
                builder: (context) => ContactoSection(
                  onActionSelected: (action) {
                    Navigator.pop(context);
                    onActionSelected(action);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
