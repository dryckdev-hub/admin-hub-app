import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../data/services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  String _currentSuffix = "";
  String get currentSuffix => _currentSuffix;
  
  String _currentUrl = "";
  String get currentUrl => _currentUrl; 
  
  String _currentPrefix = "";
  String get currentPrefix => _currentPrefix;

  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  bool _isWebLoggedIn = false;
  bool get isWebLoggedIn => _isWebLoggedIn;

  List<String> availableBranches = [];

  AppProvider() {
    loadConfig();
  }

  void webLogin(bool status) {
    _isWebLoggedIn = status;
    notifyListeners();
  }

  Future<void> loadConfig() async {
    final config = await _storage.getConfig();
    _currentUrl = config['url'] ?? "";
    _currentPrefix = config['prefix'] ?? "";
    _currentSuffix = config['suffix'] ?? "";
    
    _isConfigured = _currentUrl.isNotEmpty && _currentPrefix.isNotEmpty;
    
    // 1. Notificamos primero para que la app inicie rápido con los datos guardados
    notifyListeners();

    // 2. CORRECCIÓN IMPORTANTE:
    // Si ya hay configuración, buscamos las sucursales disponibles en segundo plano.
    // Esto asegura que la lista 'availableBranches' se llene y aparezca el menú.
    if (_isConfigured) {
      fetchAvailableBranches();
    }
  }

  // Función maestra de inicialización
  Future<bool> ensureBranchSelected() async {
    // 1. Cargar lo que tengamos guardado
    await loadConfig();

    if (!_isConfigured) return false;

    // 2. Si YA tenemos sucursal, todo perfecto (loadConfig ya disparó la búsqueda de las demás)
    if (_currentSuffix.isNotEmpty) return true;

    // 3. Si NO tenemos sucursal, buscamos y seleccionamos la primera (Auto-Connect)
    try {
      await fetchAvailableBranches();
      
      if (availableBranches.isNotEmpty) {
        availableBranches.sort(); // Orden alfabético
        final firstBranch = availableBranches.first;
        print("⚡ Auto-conectando a: $firstBranch");
        await setBranch(firstBranch);
        return true;
      }
    } catch (e) {
      print("Error en auto-conexión: $e");
    }
    
    return false;
  }

  Future<void> setBranch(String newSuffix) async {
    _currentSuffix = newSuffix;
    await _storage.saveConfig(
      url: _currentUrl, 
      prefix: _currentPrefix, 
      suffix: newSuffix
    );
    notifyListeners();
  }

  Future<void> fetchAvailableBranches() async {
    if (_currentUrl.isEmpty || _currentPrefix.isEmpty) return;

    try {
      String baseUrl = _currentUrl;
      if (!baseUrl.startsWith('http')) baseUrl = 'http://$baseUrl';
      
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/api/branches',
        queryParameters: {'prefix': _currentPrefix}
      );

      if (response.data['success'] == true) {
        final List<dynamic> list = response.data['branches'];
        availableBranches = list.map((e) => e.toString()).toList();
        // Notificamos de nuevo para que el AppBar se entere que ya llegaron las sucursales
        notifyListeners();
      }
    } catch (e) {
      print("❌ Error cargando sucursales: $e");
    }
  }

  Future<void> updateConfig(String url, String prefix, String suffix) async {
    _currentUrl = url;
    _currentPrefix = prefix;
    _currentSuffix = suffix;
    await _storage.saveConfig(url: url, prefix: prefix, suffix: suffix);
    _isConfigured = true;
    await fetchAvailableBranches(); 
    notifyListeners();
  }
}