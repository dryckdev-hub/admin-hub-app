import 'package:flutter/material.dart';
import '../data/services/api_service.dart';
import '../data/models/product_model.dart';

class InventoryProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  // --- ESTADO DASHBOARD ---
  bool isLoadingDashboard = false;
  Map<String, dynamic>? dashboardData;
  String? error;

  // --- ESTADO INVENTARIO ---
  List<Product> products = [];
  bool isLoadingProducts = false;
  
  // Lista de categorías para el dropdown de "Agregar Producto"
  List<String> categories = [];

  // --- CARRITO DE CAMBIOS (La "Lista de Ajustes") ---
  final Map<int, Map<String, dynamic>> _changes = {};
  Map<int, Map<String, dynamic>> get changes => _changes;

  // =========================================================
  // LÓGICA DASHBOARD
  // =========================================================
  
  Future<void> fetchDashboard() async {
    // Protección simple para no llamar si ya está cargando
    if (isLoadingDashboard) return;

    isLoadingDashboard = true;
    error = null;
    notifyListeners();

    try {
      final response = await _api.client.get('/api/dashboard');
      if (response.data['success'] == true) {
        dashboardData = response.data['data'];
      }
    } catch (e) {
      error = "Error conectando al servidor.";
      print("Error Dashboard: $e");
    } finally {
      isLoadingDashboard = false;
      notifyListeners();
    }
  }

  // =========================================================
  // LÓGICA INVENTARIO (Lectura)
  // =========================================================

  Future<void> fetchProducts() async {
    isLoadingProducts = true;
    notifyListeners();

    try {
      final response = await _api.client.get('/api/products');
      if (response.data['success'] == true) {
        final List list = response.data['data'];
        products = list.map((e) => Product.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error productos: $e");
    } finally {
      isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await _api.client.get('/api/categories');
      if (response.data['success'] == true) {
        final List list = response.data['data'];
        categories = list.map((e) => e.toString()).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error cargando categorías: $e");
    }
  }

  // =========================================================
  // LÓGICA CREACIÓN DE PRODUCTOS
  // =========================================================

  Future<bool> createProduct(
    String name, 
    String category, 
    double price, 
    int stock,
    bool isProduccion,
    bool isRegistradora
  ) async {
    try {
      final response = await _api.client.post('/api/products/add', data: {
        'name': name,
        'category': category,
        'price': price,
        'initialStock': stock,
        'isProduccion': isProduccion,
        'isRegistradora': isRegistradora
      });

      if (response.data['success'] == true) {
        await fetchProducts();
        await fetchCategories();
        return true;
      }
      return false;
    } catch (e) {
      print("Error creando producto: $e");
      return false;
    }
  }

  // =========================================================
  // LÓGICA CARRITO DE AJUSTES
  // =========================================================

  void addChange(int productId, String productName, int quantityDelta, double? newPrice) {
    if (!_changes.containsKey(productId)) {
      _changes[productId] = {'name': productName, 'quantity': 0, 'newPrice': null};
    }

    _changes[productId]!['quantity'] = (_changes[productId]!['quantity'] ?? 0) + quantityDelta;
    
    if (newPrice != null) {
      _changes[productId]!['newPrice'] = newPrice;
    }

    if (_changes[productId]!['quantity'] == 0 && _changes[productId]!['newPrice'] == null) {
      _changes.remove(productId);
    }
    notifyListeners();
  }

  void removeChange(int productId) {
    if (_changes.containsKey(productId)) {
      _changes.remove(productId);
      notifyListeners();
    }
  }

  void clearAllChanges() {
    _changes.clear();
    notifyListeners();
  }

  // =========================================================
  // GUARDAR CAMBIOS
  // =========================================================

  Future<bool> commitChanges() async {
    if (_changes.isEmpty) return true;

    try {
      List<Map<String, dynamic>> payload = [];
      _changes.forEach((key, value) {
        payload.add({
          'id': key,
          'quantity_delta': value['quantity'],
          'new_price': value['newPrice']
        });
      });

      await _api.client.post('/api/products/update', data: {'changes': payload});
      
      _changes.clear();
      await fetchProducts();
      return true;
    } catch (e) {
      print("Error guardando cambios: $e");
      return false;
    }
  }
}