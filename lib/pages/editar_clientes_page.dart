import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../services/database_service.dart';
import 'nuevo_cliente_page.dart';
import 'logs_page.dart';
import '../widgets/notes_container.dart';

class EditarClientesPage extends StatefulWidget {
  const EditarClientesPage({Key? key}) : super(key: key);

  @override
  _EditarClientesPageState createState() => _EditarClientesPageState();
}

class _EditarClientesPageState extends State<EditarClientesPage> {
  List<Cliente> _clientes = [];
  bool _isLoading = true;
  Cliente? _selectedClient;

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
  DateTime _ultimoContacto = DateTime.now();
  int _horaInicio = 8;
  int _horaCierre = 18;
  final List<bool> _diasSeleccionados = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final databaseService = DatabaseService();
    await databaseService.init();
    final clientes = await databaseService.getAllClientes();
    setState(() {
      _clientes = clientes;
      _isLoading = false;
      appLog("Loaded clientes: ${clientes.length}");
    });
  }

  void _onClientSelected(Cliente? client) {
    if (client != null) {
      setState(() {
        _selectedClient = client;
        _nombreController.text = client.nombre;
        _contactoController.text = client.contacto ?? '';
        _tipoNegocioController.text = client.tipoNegocio ?? '';
        _ciudadController.text = client.ciudad ?? '';
        _domicilioController.text = client.domicilio ?? '';
        _ubicacionController.text = client.ubicacion ?? '';
        _telefonoController.text = client.telefono ?? '';
        _consumoController.text = client.consumo?.toString() ?? '';
        _ultimoContacto = client.ultimoContacto ?? DateTime.now();
        _horaInicio = client.horaInicio ?? 8;
        _horaCierre = client.horaCierre ?? 18;
        _diasSeleccionados.fillRange(0, 7, false);
        if (client.dias != null && client.dias!.isNotEmpty) {
          final dias = client.dias!
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
      });
    }
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un cliente para editar')),
        );
        return;
      }
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
            databaseService
                .updateCliente(
                  id: _selectedClient!.id!,
                  nombre: _nombreController.text,
                  contacto: _contactoController.text,
                  tipoNegocio: _tipoNegocioController.text,
                  ciudad: _ciudadController.text,
                  domicilio: _domicilioController.text,
                  ubicacion: _ubicacionController.text,
                  telefono: _telefonoController.text,
                  consumo: int.tryParse(_consumoController.text) ?? 0,
                  ultimoContacto: DateTime.now(),
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
    // Implementation for getting current location can be added if needed
  }

  void _clearLocation() {
    setState(() {
      _ubicacionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Clientes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveForm),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _clientes.isEmpty
                        ? const Center(
                            child: Text('No hay clientes para editar.'),
                          )
                        : DropdownSearch<Cliente>(
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: const InputDecoration(
                                  hintText: 'Buscar cliente...',
                                  border: InputBorder.none,
                                ),
                              ),
                              emptyBuilder: (context, searchEntry) {
                                return const Center(
                                  child: Text('No se encontraron clientes'),
                                );
                              },
                            ),
                            items: _clientes,
                            dropdownDecoratorProps:
                                const DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    labelText: 'Cliente',
                                    hintText: 'Cliente',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                            dropdownBuilder: (context, selectedItem) {
                              return Text(selectedItem?.nombre ?? '');
                            },
                            itemAsString: (Cliente c) =>
                                '${c.nombre} - ${c.contacto}',
                            compareFn: (item, selectedItem) =>
                                item.id == selectedItem.id,
                            filterFn: (item, filter) {
                              return item.nombre.toLowerCase().contains(
                                    filter.toLowerCase(),
                                  ) ||
                                  item.contacto.toLowerCase().contains(
                                    filter.toLowerCase(),
                                  );
                            },
                            onChanged: _onClientSelected,
                            selectedItem: _selectedClient,
                          ),
                    const SizedBox(height: 16),
                    if (_selectedClient != null) ...[
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
                        decoration: const InputDecoration(
                          labelText: 'Contacto',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingresa el contacto';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _tipoNegocioController,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de negocio',
                        ),
                      ),
                      TextFormField(
                        controller: _ciudadController,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                      ),
                      TextFormField(
                        controller: _domicilioController,
                        decoration: const InputDecoration(
                          labelText: 'Domicilio',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: _consumoController,
                        decoration: const InputDecoration(
                          labelText: 'Consumo (kg)',
                        ),
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
                      // Notes container
                      NotesContainer(
                        clientId: _selectedClient!.id!,
                        saleId: null,
                        type: NotesContainerType.client,
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
                        children:
                            ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                                .asMap()
                                .entries
                                .map(
                                  (entry) => ChoiceChip(
                                    label: Text(entry.value),
                                    selected: _diasSeleccionados[entry.key],
                                    onSelected: (selected) {
                                      setState(() {
                                        _diasSeleccionados[entry.key] =
                                            selected;
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
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
