import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/services/api_service.dart';

class ReportsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Filtros
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // NUEVO: Variables de ordenamiento
  String _sortBy = 'fecha'; // 'fecha', 'venta', 'tickets', 'cancelados'
  String _order = 'ASC';    // 'ASC', 'DESC'

  // Getters
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get sortBy => _sortBy;
  String get order => _order;

  // Datos Tabla
  List<dynamic> reportData = [];
  Map<String, dynamic> totals = {'sales': 0.0, 'tickets': 0, 'cancelled': 0.0};
  
  // Datos Comparativa
  double comparisonPercent = 0.0;
  double currentMonthTotal = 0.0;
  
  bool isLoading = false;

  ReportsProvider() {
    // Cargar datos iniciales
    fetchReport();
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    fetchReport(); // Recargar automático al cambiar fechas
  }

  // Método para cambiar el orden desde la UI
  void setSort(String field) {
    if (_sortBy == field) {
      // Si tocan el mismo, invertimos el orden
      _order = (_order == 'ASC') ? 'DESC' : 'ASC';
    } else {
      // Si es nuevo campo, empezamos en DESC (mayor a menor es lo usual)
      _sortBy = field;
      _order = 'DESC';
    }
    fetchReport(); // Recargamos con el nuevo orden
  }

  Future<void> fetchReport() async {
    isLoading = true;
    notifyListeners();

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final response = await _api.client.get(
        '/api/reports/range',
        queryParameters: {
          'startDate': startStr, 
          'endDate': endStr,
          'sortBy': _sortBy, // Enviamos el criterio
          'order': _order    // Enviamos la dirección
        }
      );

      if (response.data['success'] == true) {
        reportData = response.data['data'];
        totals = response.data['totals'];
      }

      // 2. Obtener Comparativa (Basado en el mes de la fecha fin)
      final compResponse = await _api.client.get(
        '/api/reports/comparison',
        queryParameters: {
          'month': _endDate.month,
          'year': _endDate.year
        }
      );

      if (compResponse.data['success'] == true) {
        comparisonPercent = double.tryParse(compResponse.data['percentage'].toString()) ?? 0.0;
        currentMonthTotal = double.tryParse(compResponse.data['currentTotal'].toString()) ?? 0.0;
      }

    } catch (e) {
      print("Error reportes: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}