import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/database_service.dart';
import '../../data/database.dart';

class NuevoClientePage extends StatefulWidget {
  final String? nombreCliente;
  final Cliente? cliente;
  final bool focusOnNotas;

  const NuevoClientePage({
    super.key,
    this.nombreCliente,
    this.cliente,
    this.focusOnNotas = false,
  });

  @override
  _NuevoClientePageState createState() => _NuevoClientePageState();
}

class _NuevoClientePageState extends State<NuevoClientePage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _contactoController = TextEditingController();
  final _tipoNegocioController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _consumoController = TextEditingController();
  final _notasController = TextEditingController();
  final FocusNode _notasFocusNode = FocusNode();
  DateTime _ultimoContacto = DateTime.now();
  int _horaInicio = 8;
  int _horaCierre = 18;
  final List<bool> _diasSeleccionados = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    if (widget.cliente != null) {
      _nombreController.text = widget.cliente!.nombre;
      _contactoController.text = widget.cliente!.contacto ?? '';
      _tipoNegocioController.text = widget.cliente!.tipoNegocio ?? '';
      _ciudadController.text = widget.cliente!.ciudad ?? '';
      _domicilioController.text = widget.cliente!.domicilio ?? '';
      _ubicacionController.text = widget.cliente!.ubicacion ?? '';
      _telefonoController.text = widget.cliente!.telefono ?? '';
      _consumoController.text = widget.cliente!.consumo?.toString() ?? '';
      _ultimoContacto = widget.cliente!.ultimoContacto ?? DateTime.now();
      _horaInicio = widget.cliente!.horaInicio ?? 8;
      _horaCierre = widget.cliente!.horaCierre ?? 18;
      if (widget.cliente!.dias != null && widget.cliente!.dias!.isNotEmpty) {
        final dias = widget.cliente!.dias!
            .split(',')
            .map((d) => int.tryParse(d))
            .where((d) => d != null)
            .toList();
        for (var dia in dias) {
          if (dia != null && dia >= 0 && dia < 7) {
            _diasSeleccionados[dia] = true;
          }
        }
      }
    }
    if (widget.focusOnNotas) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_notasFocusNode);
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contactoController.dispose();
    _tipoNegocioController.dispose();
    _ciudadController.dispose();
    _domicilioController.dispose();
    _ubicacionController.dispose();
    _telefonoController.dispose();
    _consumoController.dispose();
    _notasController.dispose();
    _notasFocusNode.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ultimoContacto,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _ultimoContacto) {
      setState(() {
        _ultimoContacto = picked;
      });
    }
  }

  void _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, habilita los servicios de ubicación'),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permiso de ubicación denegado permanentemente. Habilítalo en ajustes.',
            ),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _ubicacionController.text =
            '${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al obtener ubicación: $e')));
    }
  }

  void _clearLocation() {
    setState(() {
      _ubicacionController.clear();
    });
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      // Guardar el cliente en la base de datos
      final String dias = _diasSeleccionados
          .asMap()
          .entries
          .where((entry) => entry.value)
          .map((entry) => entry.key.toString())
          .join(',');
      final databaseService = DatabaseService();
      databaseService
          .init()
          .then((_) {
            if (widget.cliente != null) {
              // Update the last contact date to current date when editing
              final DateTime currentDate = DateTime.now();
              setState(() {
                _ultimoContacto = currentDate;
              });
              databaseService
                  .updateCliente(
                    id: widget.cliente!.id!,
                    nombre: _nombreController.text,
                    contacto: _contactoController.text,
                    tipoNegocio: _tipoNegocioController.text,
                    ciudad: _ciudadController.text,
                    domicilio: _domicilioController.text,
                    ubicacion: _ubicacionController.text,
                    telefono: _telefonoController.text,
                    consumo: int.tryParse(_consumoController.text) ?? 0,
                    ultimoContacto: currentDate,
                    horaInicio: _horaInicio,
                    horaCierre: _horaCierre,
                    dias: dias,
                  )
                  .then((value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cliente actualizado con éxito'),
                      ),
                    );
                    Navigator.pop(context);
                  })
                  .catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al actualizar cliente: $error'),
                      ),
                    );
                  });
            } else {
              databaseService
                  .insertCliente(
                    nombre: _nombreController.text,
                    contacto: _contactoController.text,
                    tipoNegocio: _tipoNegocioController.text,
                    ciudad: _ciudadController.text,
                    domicilio: _domicilioController.text,
                    ubicacion: _ubicacionController.text,
                    telefono: _telefonoController.text,
                    consumo: int.tryParse(_consumoController.text) ?? 0,
                    ultimoContacto: _ultimoContacto,
                    horaInicio: _horaInicio,
                    horaCierre: _horaCierre,
                    notasId: null,
                    dias: dias,
                  )
                  .then((value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cliente guardado con éxito'),
                      ),
                    );
                    Navigator.pop(context);
                  })
                  .catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar cliente: $error'),
                      ),
                    );
                  });
            }
          })
          .catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al inicializar base de datos: $error'),
              ),
            );
          });
    }
  }

  void _debugPrintClientes() async {
    try {
      final databaseService = DatabaseService();
      await databaseService.init();
      final clientes = await databaseService.getAllClientes();
      print('Tabla de Clientes (Primeros 15):');
      for (var i = 0; i < clientes.length && i < 15; i++) {
        final cliente = clientes[i];
        print(
          'ID: ${cliente.id}, Nombre: ${cliente.nombre}, Contacto: ${cliente.contacto}, '
          'Tipo Negocio: ${cliente.tipoNegocio}, Ciudad: ${cliente.ciudad}, '
          'Domicilio: ${cliente.domicilio}, Ubicación: ${cliente.ubicacion}, '
          'Teléfono: ${cliente.telefono}, Consumo: ${cliente.consumo}, '
          'Último Contacto: ${cliente.ultimoContacto}, Hora Inicio: ${cliente.horaInicio}, '
          'Hora Cierre: ${cliente.horaCierre}, Días: ${cliente.dias}',
        );
      }
      if (clientes.length > 15) {
        print('... y ${clientes.length - 15} clientes más.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primeros 15 clientes impresos en consola'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al imprimir clientes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.cliente != null ? 'Editar Cliente' : 'Nuevo Cliente',
        ),
        leading: const BackButton(),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveForm),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa el nombre';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _contactoController,
                decoration: const InputDecoration(labelText: 'Contacto'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa el contacto';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _tipoNegocioController,
                decoration: const InputDecoration(labelText: 'Tipo de negocio'),
              ),
              TextFormField(
                controller: _ciudadController,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              TextFormField(
                controller: _domicilioController,
                decoration: const InputDecoration(labelText: 'Domicilio'),
              ),
              TextFormField(
                controller: _ubicacionController,
                decoration: InputDecoration(
                  labelText: 'Ubicación (GPS)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearLocation,
                  ),
                ),
                onTap: () {
                  if (_ubicacionController.text.isEmpty) {
                    _getCurrentLocation();
                  }
                },
              ),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _consumoController,
                decoration: const InputDecoration(labelText: 'Consumo (kg)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final num? consumo = num.tryParse(value);
                    if (consumo == null) {
                      return 'Por favor, ingresa un número válido';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _notasController,
                focusNode: _notasFocusNode,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 3,
              ),
              ListTile(
                title: Text(
                  'Último contacto: ${DateFormat('dd/MM/yyyy').format(_ultimoContacto)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              const Text('Horario de atención:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<int>(
                    value: _horaInicio,
                    items: List.generate(24, (index) => index)
                        .map(
                          (hour) => DropdownMenuItem(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _horaInicio = value;
                        });
                      }
                    },
                  ),
                  const Text('a'),
                  DropdownButton<int>(
                    value: _horaCierre,
                    items: List.generate(24, (index) => index)
                        .map(
                          (hour) => DropdownMenuItem(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _horaCierre = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Días de visita:'),
              Wrap(
                spacing: 8.0,
                children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                    .asMap()
                    .entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: _diasSeleccionados[entry.key],
                        onSelected: (selected) {
                          setState(() {
                            _diasSeleccionados[entry.key] = selected;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveForm,
                child: const Text('Guardar cliente'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _debugPrintClientes,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                child: const Text('Depuración: Imprimir Clientes en Consola'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
