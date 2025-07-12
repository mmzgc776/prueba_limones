import 'package:flutter/material.dart';

class ContactoSection extends StatelessWidget {
  final void Function(String) onActionSelected;
  const ContactoSection({super.key, required this.onActionSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Contacto',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _ContactoButton(
                label: 'Venta',
                color: Colors.green,
                onTap: () => onActionSelected('Venta'),
              ),
              _ContactoButton(
                label: 'Rechazó',
                color: Colors.red,
                onTap: () => onActionSelected('Rechazó'),
              ),
              _ContactoButton(
                label: 'Encargó',
                color: Colors.orange,
                onTap: () => onActionSelected('Encargó'),
              ),
              _ContactoButton(
                label: 'Pendiente',
                color: Colors.blue,
                onTap: () => onActionSelected('Pendiente'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactoButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactoButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
