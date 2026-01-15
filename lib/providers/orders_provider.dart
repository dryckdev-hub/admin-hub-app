import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../data/services/api_service.dart';

class OrdersProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Filtros
  DateTime startDate = DateTime.now(); 
  DateTime endDate = DateTime.now().add(const Duration(days: 7));
  
  String? filterStatusEntrega; 
  String? filterPago;          
  String searchQuery = "";     

  // NUEVO: Ordenamiento
  String sortBy = 'fechaentrega'; // Campo por defecto
  String order = 'ASC';           // Orden por defecto

  // Datos
  List<dynamic> ordersList = [];
  Map<String, dynamic> summary = {};
  bool isLoading = false;
  
  Timer? _debounce;

  void setDateRange(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    fetchOrders();
  }

  // NUEVO: Método para cambiar el orden
  void setSort(String field) {
    if (sortBy == field) {
      // Si ya estaba seleccionado, invertimos el orden
      order = (order == 'ASC') ? 'DESC' : 'ASC';
    } else {
      // Si es campo nuevo, por defecto descendente (ej. ver los que deben más primero)
      sortBy = field;
      order = 'DESC';
    }
    fetchOrders();
  }

  void toggleEntregaFilter(String status) {
    if (filterStatusEntrega == status) {
      filterStatusEntrega = null; 
    } else {
      filterStatusEntrega = status; 
    }
    fetchOrders();
  }

  void togglePagoFilter(String status) {
    if (filterPago == status) {
      filterPago = null; 
    } else {
      filterPago = status; 
    }
    fetchOrders();
  }

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchQuery = query;
      fetchOrders();
    });
  }

  Future<void> fetchOrders() async {
    isLoading = true;
    notifyListeners();

    try {
      final params = {
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        // Enviamos el ordenamiento al servidor
        'sortBy': sortBy,
        'order': order,
      };

      if (filterStatusEntrega != null) params['statusEntrega'] = filterStatusEntrega!;
      if (filterPago != null) params['paymentStatus'] = filterPago!;
      if (searchQuery.isNotEmpty) params['search'] = searchQuery;

      final response = await _api.client.get('/api/orders', queryParameters: params);

      if (response.data['success'] == true) {
        ordersList = response.data['data'];
        summary = response.data['summary'];
      }
    } catch (e) {
      print("Error Pedidos: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}