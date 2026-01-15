import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/app_provider.dart';
import '../widgets/custom_appbar.dart';
import 'inventory_screen.dart';
import 'reports_menu_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  
  @override
  void initState() {
    super.initState();
    // Esto estaba bien, espera al primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoad();
    });
  }

  // CORRECCIÓN CRÍTICA AQUÍ:
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Antes llamabas directo a _checkAndLoad(), lo que causaba el crash.
    // Ahora le decimos: "Espera a terminar de dibujar antes de verificar datos".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoad();
    });
  }

  Future<void> _checkAndLoad() async {
    // Verificamos que el widget siga montado para evitar errores si cambias de pantalla rápido
    if (!mounted) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    
    // 1. Si falta URL o Prefijo, no podemos hacer nada aún
    if (!appProvider.isConfigured) return;

    // 2. LÓGICA DE AUTO-CONEXIÓN
    if (appProvider.currentSuffix.isEmpty) {
      // Si la lista de sucursales está vacía, la pedimos
      if (appProvider.availableBranches.isEmpty) {
        await appProvider.fetchAvailableBranches();
      }

      // Si encontramos sucursales, seleccionamos la primera alfabéticamente
      if (appProvider.availableBranches.isNotEmpty) {
        appProvider.availableBranches.sort();
        final firstBranch = appProvider.availableBranches.first;
        await appProvider.setBranch(firstBranch);
      }
    }

    // 3. CARGAR DATOS DEL DASHBOARD
    // Verificamos mounted de nuevo por si el await anterior tardó
    if (mounted && 
        appProvider.currentSuffix.isNotEmpty && 
        !inventory.isLoadingDashboard && 
        inventory.dashboardData == null) {
      inventory.fetchDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final appSuffix = appProvider.currentSuffix;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: appSuffix.isEmpty ? "AdminHub" : "AdminHub ($appSuffix)",
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          
          // 1. Esperando configuración
          if (!appProvider.isConfigured) {
            return _buildWelcomeView();
          }

          // 2. Cargando
          if (provider.isLoadingDashboard) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. Error
          if (provider.error != null) {
            return _buildErrorView(provider.error!);
          }

          // 4. Sin datos -> Botón manual
          if (provider.dashboardData == null) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Text("Conectando..."),
                   const Gap(10),
                   ElevatedButton(
                     onPressed: () => _checkAndLoad(), 
                     child: const Text("Reintentar")
                   )
                 ],
               )
             );
          }

          // 5. Todo listo
          return _buildDashboardContent(provider.dashboardData!);
        },
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 80, color: Colors.grey),
            const Gap(20),
            const Text("Bienvenido a AdminHub", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Cargando configuración...", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 80, color: Colors.redAccent),
            const Gap(20),
            Text("Error de Conexión", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red)),
            const Gap(10),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const Gap(30),
            ElevatedButton.icon(
              onPressed: () => _checkAndLoad(), 
              icon: const Icon(Icons.refresh), 
              label: const Text("Reintentar")
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(Map<String, dynamic> data) {
    final summary = data['summary'];
    final history = data['history'] as List;
    
    final ButtonStyle bigButtonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
      elevation: 3
    );

    return RefreshIndicator(
      onRefresh: () async => Provider.of<InventoryProvider>(context, listen: false).fetchDashboard(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
              Expanded(child: _KpiCard(title: "Venta este Mes", value: "\$${summary['total_sales']}", icon: Icons.attach_money, color: Colors.green)),
              const Gap(16),
              Expanded(child: _KpiCard(title: "Tickets", value: "${summary['total_tickets']}", icon: Icons.receipt, color: Colors.orange)),
          ]),
          const Gap(25),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ElevatedButton.icon(
                style: bigButtonStyle.copyWith(backgroundColor: MaterialStateProperty.all(Theme.of(context).primaryColor), foregroundColor: MaterialStateProperty.all(Colors.white)), 
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())), 
                icon: const Icon(Icons.inventory_2_outlined, size: 28), 
                label: const Text("GESTIONAR INVENTARIO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              ),
              const Gap(15),
              ElevatedButton.icon(
                style: bigButtonStyle.copyWith(backgroundColor: MaterialStateProperty.all(Colors.blueGrey), foregroundColor: MaterialStateProperty.all(Colors.white)), 
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsMenuScreen())), 
                icon: const Icon(Icons.bar_chart, size: 28), 
                label: const Text("REPORTES Y CONSULTAS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              ),
          ]),
          const Gap(25),
          const Text("Historial Reciente (Último Mes)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Gap(10),
          ...history.map((corte) => Card(child: ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.calendar_today, color: Colors.brown)), 
            title: Text("Fecha: ${corte['fecha'].toString().substring(0, 10)}"), 
            subtitle: Text("${corte['numerotickets']} Tickets emitidos"), 
            trailing: Text("\$${corte['totalcobradot']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green))
          ))).toList(),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 30), 
        const Gap(10), 
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)), 
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22))
      ])
    );
  }
}