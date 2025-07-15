import 'package:flutter/material.dart';
import '../widgets/venta_form.dart';

class Section2Page extends StatelessWidget {
  final int? deliveryNumber;

  const Section2Page({super.key, this.deliveryNumber});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: VentaForm(deliveryNumber: deliveryNumber),
          ),
          Positioned(
            top: 8,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                deliveryNumber != null ? '( #$deliveryNumber )' : '( XX )',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
