import 'package:flutter/material.dart';

class Section1Page extends StatelessWidget {
  const Section1Page({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sección 1')),
      body: const Center(child: Text('Bienvenido a la Sección 1')),
    );
  }
}
