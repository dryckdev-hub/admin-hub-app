import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/services/api_service.dart';

class TransfersProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Filtros
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();
  
  // Filtro de Tipo: 'Todos', 'Salida', 'Entrada'
  String filterType = 'Todos'; 

  // Ordenamiento
  String sortBy = 'fecha_full';
  String order = 'ASC';

  // Datos
  List<dynamic> movementsList = [];
  bool isLoading = false;
  
  // Totales
  double totalCosto = 0;
  int totalPiezas = 0;

  void setDateRange(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    fetchMovements();
  }

  void setFilterType(String type) {
    filterType = type;
    fetchMovements();
  }

  void setSort(String field) {
    if (sortBy == field) {
      order = (order == 'ASC') ? 'DESC' : 'ASC';
    } else {
      sortBy = field;
      order = 'DESC';
    }
    fetchMovements();
  }

  Future<void> fetchMovements() async {
    isLoading = true;
    notifyListeners();

    try {
      final params = {
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        'sortBy': sortBy,
        'order': order,
      };

      if (filterType != 'Todos') {
        params['type'] = filterType;
      }

      final response = await _api.client.get('/api/transfers/summary', queryParameters: params);

      if (response.data['success'] == true) {
        movementsList = response.data['data'];
        
        // Calcular totales locales
        totalCosto = 0;
        totalPiezas = 0;
        for (var m in movementsList) {
          totalCosto += double.tryParse(m['costo_total'].toString()) ?? 0;
          totalPiezas += double.tryParse(m['total_piezas'].toString())?.toInt() ?? 0;
        }
      }
    } catch (e) {
      print("Error Traslados: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}