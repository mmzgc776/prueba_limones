import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../data/database.dart';
import '../data/delivery_state.dart';
import '../pages/logs_page.dart';
import 'notes_container.dart';

// Edit VentaForm that extends the base VentaForm with edit functionality
class EditVentaForm extends VentaForm {
  final Sale sale;

  const EditVentaForm({
    super.key,
    required this.sale,
    super.cliente,
    super.deliveryNumber,
  }) : super();

  @override
  State<EditVentaForm> createState() => _EditVentaFormState();
}

class _EditVentaFormState extends State<EditVentaForm> {
  DateTime selectedDate = DateTime.now();
  Cliente? selectedClient;
  int? selectedButtonValue;
  int? pressedButtonValue;
  final TextEditingController numberController = TextEditingController();
  final TextEditingController customPriceController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final FocusNode customPriceFocusNode = FocusNode();
  List<Cliente> clients = [];
  String? selectedPrice;

  Map<String, double> get priceOptions {
    double? globalPrice = DeliveryStateManager().getCurrentPrice();
    if (globalPrice == null || globalPrice == 0.0) {
      return {'menudeo': 20.0, 'default': 10.0, 'mayoreo': 5.0};
    } else {
      return {
        'menudeo': (globalPrice * 1.20).ceilToDouble(),
        'default': globalPrice.ceilToDouble(),
        'mayoreo': (globalPrice * 0.9).ceilToDouble(),
      };
    }
  }

  String? lastEditedField;
  bool isSyncing = false;

  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    numberController.addListener(() => _onFieldChanged('cantidad'));
    customPriceController.addListener(() => _onFieldChanged('precio'));
    totalController.addListener(() => _onFieldChanged('total'));
    _initDb();
    _loadClients();
    // Pre-fill the form with existing sale data
    _loadSaleData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set the client from the widget parameter if available
    final editForm = widget as EditVentaForm;
    if (editForm.cliente != null && selectedClient == null) {
      setState(() {
        selectedClient = editForm.cliente;
        // Add the client to the list if it's not already there
        if (!clients.any((c) => c.id == editForm.cliente!.id)) {
          clients.add(editForm.cliente!);
        }
      });
    }
  }

  Future<void> _initDb() async {
    await _dbService.init();
  }

  Future<void> _loadClients() async {
    try {
      await _initDb(); // Ensure database is initialized before loading clients
      final fetchedClientes = await _dbService.getAllClientes();
      setState(() {
        clients = fetchedClientes;
      });
    } catch (e) {
      debugPrint('Error loading clients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar los clientes')),
      );
    }
  }

  void _onFieldChanged(String field) {
    if (isSyncing) return;
    isSyncing = true;
    try {
      final cantidad = double.tryParse(numberController.text) ?? 0.0;
      final precio =
          double.tryParse(
            selectedPrice == 'elegir'
                ? customPriceController.text
                : (selectedPrice != null
                      ? priceOptions[selectedPrice].toString()
                      : ''),
          ) ??
          0.0;
      final total = double.tryParse(totalController.text) ?? 0.0;

      final cantidadOk = cantidad > 0;
      final precioOk = precio > 0;
      final totalOk = total > 0;

      if (field == 'cantidad') lastEditedField = 'cantidad';
      if (field == 'precio') lastEditedField = 'precio';
      if (field == 'total') lastEditedField = 'total';

      if ((field == 'cantidad' && precioOk) ||
          (field == 'precio' && cantidadOk)) {
        final calcTotal = cantidad * precio;
        if (totalController.text != calcTotal.toStringAsFixed(2)) {
          totalController.text = calcTotal.toStringAsFixed(2);
        }
      } else if ((field == 'cantidad' && totalOk) ||
          (field == 'total' && cantidadOk)) {
        if (cantidad > 0) {
          final calcPrecio = total / cantidad;
          if (selectedPrice == 'elegir') {
            if (customPriceController.text != calcPrecio.toStringAsFixed(2)) {
              customPriceController.text = calcPrecio.toStringAsFixed(2);
            }
          }
        }
      } else if ((field == 'precio' && totalOk) ||
          (field == 'total' && precioOk)) {
        if (precio > 0) {
          final calcCantidad = total / precio;
          if (numberController.text != calcCantidad.toStringAsFixed(2)) {
            numberController.text = calcCantidad.toStringAsFixed(2);
          }
        }
      }
    } finally {
      isSyncing = false;
    }
  }

  Future<int?> _getClientId() async {
    if (selectedClient == null) return null;
    return selectedClient!.id;
  }

  @override
  void dispose() {
    numberController.dispose();
    customPriceController.dispose();
    totalController.dispose();
    notesController.dispose();
    customPriceFocusNode.dispose();
    super.dispose();
  }

  void _loadSaleData() {
    final editForm = widget as EditVentaForm;
    final sale = editForm.sale;

    // Pre-fill date
    selectedDate = sale.date;

    // Pre-fill quantity
    numberController.text = sale.quantity.toStringAsFixed(2);

    // Pre-fill price based on sale data
    customPriceController.text = sale.price.toStringAsFixed(2);
    selectedPrice = 'elegir'; // Use custom price

    // Pre-fill total
    totalController.text = sale.total.toStringAsFixed(2);

    // Load the client if not provided
    if (widget.cliente == null && sale.clientId > 0) {
      _loadClientById(sale.clientId);
    }
  }

  Future<void> _loadClientById(int clientId) async {
    try {
      final cliente = await _dbService.getClienteById(clientId);
      if (cliente != null) {
        setState(() {
          selectedClient = cliente;
        });
      }
    } catch (e) {
      debugPrint('Error loading client: $e');
    }
  }

  @override
  Future<void> _saveSale() async {
    final editForm = widget as EditVentaForm;
    final saleId = editForm.sale.id;

    final clientId = await _getClientId();
    if (clientId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }

    final cantidad = double.tryParse(numberController.text) ?? 0.0;
    final precio =
        double.tryParse(
          selectedPrice == 'elegir'
              ? customPriceController.text
              : (selectedPrice != null
                    ? priceOptions[selectedPrice].toString()
                    : ''),
        ) ??
        0.0;
    final total = double.tryParse(totalController.text) ?? 0.0;

    // Update the existing sale
    await _dbService.updateSale(
      id: saleId,
      quantity: cantidad,
      price: precio,
      total: total,
      date: selectedDate,
    );

    // Log the update
    final clientName = selectedClient?.nombre ?? 'Cliente ID $clientId';
    final deliveryNum = DeliveryStateManager().getCurrentDeliveryNumber();
    appLog(
      'Actualizando venta - ID: $saleId, Cliente: $clientName, Cantidad: $cantidad, Precio: \$$precio, Total: \$$total, Fecha: $selectedDate, Reparto: $deliveryNum',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venta actualizada en la base de datos')),
    );
    Navigator.of(context).pop(true); // Return true to indicate success
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date picker
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (picked != null && picked != selectedDate) {
                setState(() {
                  selectedDate = picked;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha',
                hintText: 'Fecha',
                border: OutlineInputBorder(),
              ),
              child: Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Client selection
          clients.isEmpty
              ? const Center(child: CircularProgressIndicator())
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
                  items: clients,
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Cliente',
                      hintText: 'Cliente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  dropdownBuilder: (context, selectedItem) {
                    return Text(selectedItem?.nombre ?? '');
                  },
                  itemAsString: (Cliente c) => '${c.nombre} - ${c.contacto}',
                  compareFn: (item, selectedItem) => item.id == selectedItem.id,
                  filterFn: (item, filter) {
                    return item.nombre.toLowerCase().contains(
                          filter.toLowerCase(),
                        ) ||
                        item.contacto.toLowerCase().contains(
                          filter.toLowerCase(),
                        );
                  },
                  onChanged: (value) {
                    setState(() {
                      selectedClient = value;
                    });
                  },
                  selectedItem: selectedClient,
                ),
          const SizedBox(height: 16),

          // Quantity buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var value in [1, 5, 10, 15, 20])
                GestureDetector(
                  onTapDown: (_) {
                    setState(() {
                      pressedButtonValue = value;
                    });
                  },
                  onTapUp: (_) {
                    setState(() {
                      pressedButtonValue = null;
                    });
                  },
                  onTapCancel: () {
                    setState(() {
                      pressedButtonValue = null;
                    });
                  },
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pressedButtonValue == value
                          ? Colors.deepPurple
                          : null,
                    ),
                    onPressed: () {
                      double current =
                          double.tryParse(numberController.text) ?? 0.0;
                      numberController.text = (current + value).toStringAsFixed(
                        2,
                      );
                    },
                    child: Text(value.toString()),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Quantity field
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: numberController,
            builder: (context, value, child) {
              return TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  hintText: 'Cantidad',
                  border: const OutlineInputBorder(),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            numberController.clear();
                          },
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Price selection (custom price for editing)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: customPriceController,
            builder: (context, value, child) {
              return TextField(
                controller: customPriceController,
                focusNode: customPriceFocusNode,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Precio',
                  hintText: 'Precio',
                  border: const OutlineInputBorder(),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              customPriceController.clear();
                              selectedPrice = null;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) {
                  FocusScope.of(context).unfocus();
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Total field
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: totalController,
            builder: (context, value, child) {
              return TextField(
                controller: totalController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Total',
                  hintText: 'Total',
                  border: const OutlineInputBorder(),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            totalController.clear();
                          },
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Notes container
          if (selectedClient != null)
            NotesContainer(
              clientId: selectedClient!.id!,
              saleId: (widget as EditVentaForm).sale.id,
              type: NotesContainerType.sale,
            ),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _saveSale,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Actualizar'),
          ),
          const SizedBox(height: 12),

          // Cancel button
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class VentaForm extends StatefulWidget {
  final Cliente? cliente;
  final int? deliveryNumber;
  const VentaForm({super.key, this.cliente, this.deliveryNumber});

  @override
  State<VentaForm> createState() => _VentaFormState();
}

class _VentaFormState extends State<VentaForm> {
  DateTime selectedDate = DateTime.now();
  Cliente? selectedClient;
  int? selectedButtonValue;
  int? pressedButtonValue;
  final TextEditingController numberController = TextEditingController();
  final TextEditingController customPriceController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final FocusNode customPriceFocusNode = FocusNode();
  List<Cliente> clients = [];
  String? selectedPrice;

  Map<String, double> get priceOptions {
    double? globalPrice = DeliveryStateManager().getCurrentPrice();
    if (globalPrice == null || globalPrice == 0.0) {
      return {'menudeo': 20.0, 'default': 10.0, 'mayoreo': 5.0};
    } else {
      return {
        'menudeo': (globalPrice * 1.20).ceilToDouble(),
        'default': globalPrice.ceilToDouble(),
        'mayoreo': (globalPrice * 0.9).ceilToDouble(),
      };
    }
  }

  String? lastEditedField;
  bool isSyncing = false;

  final DatabaseService _dbService = DatabaseService();
  late final SyncService _syncService = SyncService(_dbService);

  @override
  void initState() {
    super.initState();
    numberController.addListener(() => _onFieldChanged('cantidad'));
    customPriceController.addListener(() => _onFieldChanged('precio'));
    totalController.addListener(() => _onFieldChanged('total'));
    _initDb();
    _loadClients();
    if (widget.cliente != null) {
      selectedClient = widget.cliente;
    }
  }

  Future<void> _initDb() async {
    await _dbService.init();
  }

  Future<void> _loadClients() async {
    try {
      await _initDb(); // Ensure database is initialized before loading clients
      final fetchedClientes = await _dbService.getAllClientes();
      setState(() {
        clients = fetchedClientes;
      });
    } catch (e) {
      debugPrint('Error loading clients: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar los clientes')),
      );
    }
  }

  @override
  void dispose() {
    numberController.dispose();
    customPriceController.dispose();
    totalController.dispose();
    customPriceFocusNode.dispose();
    super.dispose();
  }

  void _onFieldChanged(String field) {
    if (isSyncing) return;
    isSyncing = true;
    try {
      final cantidad = double.tryParse(numberController.text) ?? 0.0;
      final precio =
          double.tryParse(
            selectedPrice == 'elegir'
                ? customPriceController.text
                : (selectedPrice != null
                      ? priceOptions[selectedPrice].toString()
                      : ''),
          ) ??
          0.0;
      final total = double.tryParse(totalController.text) ?? 0.0;

      final cantidadOk = cantidad > 0;
      final precioOk = precio > 0;
      final totalOk = total > 0;

      if (field == 'cantidad') lastEditedField = 'cantidad';
      if (field == 'precio') lastEditedField = 'precio';
      if (field == 'total') lastEditedField = 'total';

      if ((field == 'cantidad' && precioOk) ||
          (field == 'precio' && cantidadOk)) {
        final calcTotal = cantidad * precio;
        if (totalController.text != calcTotal.toStringAsFixed(2)) {
          totalController.text = calcTotal.toStringAsFixed(2);
        }
      } else if ((field == 'cantidad' && totalOk) ||
          (field == 'total' && cantidadOk)) {
        if (cantidad > 0) {
          final calcPrecio = total / cantidad;
          if (selectedPrice == 'elegir') {
            if (customPriceController.text != calcPrecio.toStringAsFixed(2)) {
              customPriceController.text = calcPrecio.toStringAsFixed(2);
            }
          }
        }
      } else if ((field == 'precio' && totalOk) ||
          (field == 'total' && precioOk)) {
        if (precio > 0) {
          final calcCantidad = total / precio;
          if (numberController.text != calcCantidad.toStringAsFixed(2)) {
            numberController.text = calcCantidad.toStringAsFixed(2);
          }
        }
      }
    } finally {
      isSyncing = false;
    }
  }

  Future<int?> _getClientId() async {
    if (selectedClient == null) return null;
    return selectedClient!.id;
  }

  bool _isSaving = false;

  Future<void> _saveSale() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _persistSale();
    } catch (e) {
      appLog('Error al guardar la venta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la venta. Intenta nuevamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _persistSale() async {
    final clientId = await _getClientId();
    if (!mounted) return;
    if (clientId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }
    final cantidad = double.tryParse(numberController.text) ?? 0.0;
    final precio =
        double.tryParse(
          selectedPrice == 'elegir'
              ? customPriceController.text
              : (selectedPrice != null
                    ? priceOptions[selectedPrice].toString()
                    : ''),
        ) ??
        0.0;
    final total = double.tryParse(totalController.text) ?? 0.0;

    // Registrar la venta en los logs antes de guardar
    final clientName = selectedClient?.nombre ?? 'Cliente ID $clientId';
    final deliveryNum = DeliveryStateManager().getCurrentDeliveryNumber();
    appLog(
      'Registrando venta - Cliente: $clientName, Cantidad: $cantidad, Precio: \$$precio, Total: \$$total, Fecha: $selectedDate, Reparto: $deliveryNum',
    );

    // El flujo desde candidatos ya registra su interacción antes de navegar.
    // Por búsqueda, el comprador solo se conoce al confirmar el formulario.
    final int saleId;
    if (widget.cliente == null) {
      saleId = await _dbService.insertSaleWithInteraction(
        date: selectedDate,
        clientId: clientId,
        quantity: cantidad,
        price: precio,
        total: total,
        deliveryNumber: deliveryNum,
      );
      if (deliveryNum != null) {
        appLog(
          'Interacción Venta guardada por búsqueda - '
          'Venta: $saleId, Cliente: $clientId, Reparto: $deliveryNum',
        );
      }
    } else {
      saleId = await _dbService.insertSale(
        date: selectedDate,
        clientId: clientId,
        quantity: cantidad,
        price: precio,
        total: total,
        notesId: null,
        deliveryNumber: deliveryNum,
      );
      await _dbService.updateNotasVentaId(clientId, saleId);
    }

    // Estrategia A: actualizar puntuación del cliente en background
    unawaited(_syncService.refreshSingleClientScore(clientId));

    // Confirmar que la venta fue guardada
    appLog('Venta guardada exitosamente - ID: $saleId');

    // Store the price in global state
    DeliveryStateManager().setCurrentPrice(precio);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venta guardada en la base de datos')),
    );
    Navigator.of(context).pop();
    // Opcional: limpiar campos
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (picked != null && picked != selectedDate) {
                setState(() {
                  selectedDate = picked;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha',
                hintText: 'Fecha',
                border: OutlineInputBorder(),
              ),
              child: Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          clients.isEmpty
              ? const Center(child: CircularProgressIndicator())
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
                  items: clients,
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Cliente',
                      hintText: 'Cliente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  dropdownBuilder: (context, selectedItem) {
                    return Text(selectedItem?.nombre ?? '');
                  },
                  itemAsString: (Cliente c) => '${c.nombre} - ${c.contacto}',
                  compareFn: (item, selectedItem) => item.id == selectedItem.id,
                  filterFn: (item, filter) {
                    return item.nombre.toLowerCase().contains(
                          filter.toLowerCase(),
                        ) ||
                        item.contacto.toLowerCase().contains(
                          filter.toLowerCase(),
                        );
                  },
                  onChanged: (value) {
                    setState(() {
                      selectedClient = value;
                    });
                  },
                  selectedItem: selectedClient,
                ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var value in [1, 5, 10, 15, 20])
                GestureDetector(
                  onTapDown: (_) {
                    setState(() {
                      pressedButtonValue = value;
                    });
                  },
                  onTapUp: (_) {
                    setState(() {
                      pressedButtonValue = null;
                    });
                  },
                  onTapCancel: () {
                    setState(() {
                      pressedButtonValue = null;
                    });
                  },
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pressedButtonValue == value
                          ? Colors.deepPurple
                          : null,
                    ),
                    onPressed: () {
                      double current =
                          double.tryParse(numberController.text) ?? 0.0;
                      numberController.text = (current + value).toStringAsFixed(
                        2,
                      );
                    },
                    child: Text(value.toString()),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: numberController,
            builder: (context, value, child) {
              return TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  hintText: 'Cantidad',
                  border: const OutlineInputBorder(),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            numberController.clear();
                          },
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          selectedPrice == 'elegir'
              ? ValueListenableBuilder<TextEditingValue>(
                  valueListenable: customPriceController,
                  builder: (context, value, child) {
                    return TextField(
                      controller: customPriceController,
                      focusNode: customPriceFocusNode,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Precio personalizado',
                        hintText: 'Precio personalizado',
                        border: const OutlineInputBorder(),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    customPriceController.clear();
                                    selectedPrice = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                )
              : DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    hintText: 'Precio',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedPrice,
                  items: [
                    DropdownMenuItem(
                      value: 'menudeo',
                      child: Text(
                        'Menudeo (${priceOptions['menudeo']!.toStringAsFixed(2)})',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'default',
                      child: Text(
                        'Default (${priceOptions['default']!.toStringAsFixed(2)})',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'mayoreo',
                      child: Text(
                        'Mayoreo (${priceOptions['mayoreo']!.toStringAsFixed(2)})',
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'elegir',
                      child: Text('Elegir'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedPrice = value;
                      if (value == 'elegir') {
                        Future.delayed(const Duration(seconds: 1), () {
                          if (mounted && selectedPrice == 'elegir') {
                            customPriceFocusNode.requestFocus();
                          }
                        });
                      } else {
                        customPriceController.clear();
                        _onFieldChanged('precio');
                      }
                    });
                  },
                ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: totalController,
            builder: (context, value, child) {
              return TextField(
                controller: totalController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Total',
                  hintText: 'Total',
                  border: const OutlineInputBorder(),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            totalController.clear();
                          },
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Notes container
          if (selectedClient != null)
            NotesContainer(
              clientId: selectedClient!.id!,
              saleId: null, // No sale ID yet for new sales
              type: NotesContainerType.sale,
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSale,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Guardar'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // Aquí puedes manejar la lógica para nuevo cliente
            },
            child: const Text('Nuevo cliente'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final ventas = await _dbService.getAllSales();
              debugPrint('Ventas en la base de datos:');
              appLog('=== INICIO DE LISTADO DE VENTAS ===');
              appLog('Total de ventas encontradas: ${ventas.length}');

              for (final v in ventas) {
                debugPrint(v.toString());
                appLog(
                  'Venta ID: ${v.id}, Cliente ID: ${v.clientId}, Cantidad: ${v.quantity}, Precio: \$${v.price}, Total: \$${v.total}, Fecha: ${v.date}, Reparto: ${v.deliveryNumber ?? "N/A"}',
                );
              }

              appLog('=== FIN DE LISTADO DE VENTAS ===');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ventas impresas en consola y logs'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            child: const Text('Ver ventas (debug)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await _dbService.deleteAllSales();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ventas eliminadas')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Limpiar ventas'),
          ),
        ],
      ),
    );
  }
}
