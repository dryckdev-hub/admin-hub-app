import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import '../../providers/app_provider.dart';
import '../../providers/inventory_provider.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _urlCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Cargamos los datos guardados al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentConfig();
    });
  }

  void _loadCurrentConfig() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // AQUÍ ESTÁ LA SOLUCIÓN: Llenamos los controladores con lo que tiene el provider
    setState(() {
      _urlCtrl.text = appProvider.currentUrl;
      _prefixCtrl.text = appProvider.currentPrefix;
    });
  }

  void _save() async {
    if (_urlCtrl.text.isEmpty || _prefixCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La URL y el Prefijo son obligatorios")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // 1. Guardar Config
    await appProvider.updateConfig(
      _urlCtrl.text.trim(),
      _prefixCtrl.text.trim(),
      "" 
    );

    // 2. Verificar resultados
    if (appProvider.availableBranches.isNotEmpty) {
      final firstBranch = appProvider.availableBranches.first;
      await appProvider.setBranch(firstBranch);
      
      if (mounted) {
        final inventory = Provider.of<InventoryProvider>(context, listen: false);
        inventory.dashboardData = null; 
        inventory.fetchDashboard();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("¡Conectado! Sucursal: ${firstBranch.toUpperCase()}"))
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        // Mostramos alerta si no encontró nada
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Sin Sucursales"),
            content: Text("Se conectó al servidor pero no se encontraron bases de datos que empiecen con '${_prefixCtrl.text}_'.\n\nVerifica el prefijo o revisa la consola del servidor."),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Ok"))],
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración Maestra")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.admin_panel_settings, size: 60, color: Colors.grey),
            const Gap(20),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: "Host API",
                hintText: "Ej. 192.168.1.X:3000",
                prefixIcon: Icon(Icons.cloud),
              ),
            ),
            const Gap(20),
            TextField(
              controller: _prefixCtrl,
              decoration: const InputDecoration(
                labelText: "Prefijo BD",
                hintText: "Ej. marquez",
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const Gap(40),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Icon(Icons.save),
              label: Text(_isLoading ? "Buscando..." : "GUARDAR Y CONECTAR"),
            ),
          ],
        ),
      ),
    );
  }
}