import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../data/services/api_service.dart';

class ProductionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // Filtros
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();
  
  // Por defecto ordenamos por fecha descendente
  String sortBy = 'fecha';
  String order = 'ASC'; 
  
  String searchQuery = "";
  String selectedArea = 'Todos';

  // Datos
  List<dynamic> _allProductionList = [];
  List<dynamic> displayList = [];
  Map<String, double> totals = {'piezas': 0, 'costo': 0, 'venta': 0};

  bool isLoading = false;
  Timer? _debounce;
  List<String> availableAreas = ['Todos'];

  // --- GETTER AGRUPADO (Mantiene la corrección de nulls) ---
  List<Map<String, dynamic>> get groupedDays {
    if (displayList.isEmpty) return [];

    Map<String, Map<String, dynamic>> groups = {};

    for (var item in displayList) {
      try {
        String rawDate = item['fecha']?.toString() ?? DateTime.now().toString();
        String dateKey = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

        if (!groups.containsKey(dateKey)) {
          groups[dateKey] = {
            'fecha': dateKey,
            'total_piezas': 0.0,
            'total_costo': 0.0,
            'total_venta': 0.0,
            'areas': <String, dynamic>{}
          };
        }

        final qty = num.tryParse(item['cantidad'].toString()) ?? 0;
        final cost = num.tryParse(item['costo_mo'].toString()) ?? 0;
        final sale = num.tryParse(item['valor_venta'].toString()) ?? 0;

        var currentDay = groups[dateKey]!;
        currentDay['total_piezas'] = (currentDay['total_piezas'] as num) + qty;
        currentDay['total_costo'] = (currentDay['total_costo'] as num) + cost;
        currentDay['total_venta'] = (currentDay['total_venta'] as num) + sale;

        String area = item['area']?.toString() ?? 'Sin Área';
        var dayAreas = currentDay['areas'] as Map<String, dynamic>;

        if (!dayAreas.containsKey(area)) {
          dayAreas[area] = {'piezas': 0.0, 'costo': 0.0};
        }

        dayAreas[area]['piezas'] = (dayAreas[area]['piezas'] as num) + qty;
        dayAreas[area]['costo'] = (dayAreas[area]['costo'] as num) + cost;

      } catch (e) {
        print("⚠️ Error procesando fila: $e");
      }
    }

    List<Map<String, dynamic>> result = groups.values.toList();
    // Ordenamos los grupos también según la lógica principal si es por fecha
    if (sortBy == 'fecha') {
      if (order == 'ASC') {
        result.sort((a, b) => a['fecha'].compareTo(b['fecha']));
      } else {
        result.sort((a, b) => b['fecha'].compareTo(a['fecha']));
      }
    } else {
      // Si ordenan por otra cosa (ej. Valor), mantenemos fecha descendente en la vista agrupada
      result.sort((a, b) => b['fecha'].compareTo(a['fecha']));
    }
    
    return result;
  }

  void setDateRange(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    fetchProduction();
  }

  // --- LÓGICA DE ORDENAMIENTO TIPO TOGGLE (COMO PEDIDOS) ---
  void setSort(String field) {
    if (sortBy == field) {
      // Si ya estaba seleccionado, invertimos el orden
      order = (order == 'ASC') ? 'DESC' : 'ASC';
    } else {
      // Si es nuevo, seleccionamos y por defecto DESC (mayor a menor)
      sortBy = field;
      order = 'DESC';
    }
    fetchProduction();
  }

  void setAreaFilter(String area) {
    selectedArea = area;
    _applyLocalFilters();
  }

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchQuery = query;
      fetchProduction();
    });
  }

  Future<void> fetchProduction() async {
    isLoading = true;
    notifyListeners();

    try {
      final params = {
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        'sortBy': sortBy,
        'order': order,
      };

      if (searchQuery.isNotEmpty) params['search'] = searchQuery;

      print("🔵 [FLUTTER] Prod Params: $params");

      final response = await _api.client.get('/api/production/summary', queryParameters: params);

      if (response.data['success'] == true) {
        _allProductionList = response.data['data'];
        
        // Refrescar lista de áreas disponibles
        final Set<String> areas = {'Todos'};
        for (var item in _allProductionList) {
          if (item['area'] != null) {
            areas.add(item['area'].toString());
          }
        }
        availableAreas = areas.toList();
        availableAreas.sort();

        _applyLocalFilters();
      }
    } catch (e) {
      print("❌ Error fetchProduction: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _applyLocalFilters() {
    if (selectedArea == 'Todos') {
      displayList = List.from(_allProductionList);
    } else {
      displayList = _allProductionList.where((item) => item['area'] == selectedArea).toList();
    }
    _calculateTotals();
    notifyListeners();
  }

  void _calculateTotals() {
    num p = 0, c = 0, v = 0;
    for (var item in displayList) {
      p += num.tryParse(item['cantidad'].toString()) ?? 0;
      c += num.tryParse(item['costo_mo'].toString()) ?? 0;
      v += num.tryParse(item['valor_venta'].toString()) ?? 0;
    }
    totals = {
      'piezas': p.toDouble(),
      'costo': c.toDouble(),
      'venta': v.toDouble()
    };
  }
}