import 'package:dio/dio.dart';
import 'package:app_panaderia/data/services/storage_service.dart';

class ApiService {
  final Dio _dio = Dio();
  final StorageService _storageService = StorageService();

  ApiService() {
    // Configuración base
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.receiveTimeout = const Duration(seconds: 120);
    
    // Interceptor: Se ejecuta ANTES de cada petición
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 1. Leer configuración guardada
        final config = await _storageService.getConfig();
        
        // 2. Si la URL base cambió, actualizarla
        // Nota: Si la URL incluye 'http', úsala, si no, agrégalo
        String baseUrl = config['url']!;
        if (!baseUrl.startsWith('http')) baseUrl = 'http://$baseUrl';
        
        // Aseguramos que no termine en slash para evitar doble slash
        if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
        
        options.baseUrl = baseUrl;

        // 3. Inyectar Headers de Sucursal
        options.headers['bakery_prefix'] = config['prefix'];
        options.headers['branch_suffix'] = config['suffix'];
        
        print("📡 Petición a: ${options.baseUrl}${options.path}");
        print("🔐 Headers: ${options.headers}");

        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print("❌ Error API: ${e.message}");
        return handler.next(e);
      }
    ));
  }

  Dio get client => _dio;
}