import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import '../../providers/app_provider.dart';
import '../../providers/inventory_provider.dart';
import '../screens/config_screen.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;

  const CustomAppBar({super.key, required this.title, this.showBack = false});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  void _handleSecretTap() {
    // EN WEB BLOQUEAMOS EL ACCESO A CONFIGURACIÓN
    if (kIsWeb) return; 

    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _secretTapCount = 0;
    }
    _lastTapTime = now;
    _secretTapCount++;

    if (_secretTapCount >= 3) {
      _secretTapCount = 0;
      _showSecurityDialog();
    }
  }

  void _showSecurityDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Configuración Avanzada"),
        content: TextField(
          controller: passController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Contraseña Admin", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (passController.text == "config123") {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acceso Denegado")));
              }
            },
            child: const Text("Entrar"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return AppBar(
      centerTitle: false,
      leading: widget.showBack 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) 
          : null,
      
      // Título con Detector de Toques (Secreto)
      title: GestureDetector(
        onTap: _handleSecretTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (appProvider.currentSuffix.isNotEmpty)
              Text(
                appProvider.currentSuffix.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      
      actions: [
        if (appProvider.availableBranches.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.store_mall_directory),
            tooltip: "Cambiar Sucursal",
            onSelected: (String newBranch) async {
              if (newBranch != appProvider.currentSuffix) {
                await appProvider.setBranch(newBranch);
                if (context.mounted) {
                   final inv = Provider.of<InventoryProvider>(context, listen: false);
                   inv.dashboardData = null;
                   inv.fetchDashboard();
                   inv.fetchProducts();
                   
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text("Cambiando a: ${newBranch.toUpperCase()}"))
                   );
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return appProvider.availableBranches.map((String branch) {
                final isSelected = branch == appProvider.currentSuffix;
                return PopupMenuItem<String>(
                  value: branch,
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                        size: 20,
                      ),
                      const Gap(10),
                      Text(
                        branch.toUpperCase(),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).primaryColor : Colors.black87
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          )
        else
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.cloud_off, color: Colors.grey),
          )
      ],
    );
  }
}