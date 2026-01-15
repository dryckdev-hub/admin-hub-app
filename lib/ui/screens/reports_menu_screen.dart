import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../widgets/custom_appbar.dart';
import 'reports_screen.dart'; 
import 'production_report_screen.dart'; 
import 'orders_report_screen.dart'; 
import 'transfers_screen.dart'; // <--- IMPORTANTE: Importamos la pantalla de traslados

class ReportsMenuScreen extends StatelessWidget {
  const ReportsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Seleccionar Módulo", showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "¿Qué deseas consultar?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Gap(20),
          
          _MenuCard(
            title: "VENTAS PANADERÍA",
            subtitle: "Reporte de ventas, tickets marcados y cancelamientos.",
            icon: Icons.point_of_sale,
            color: Colors.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          
          _MenuCard(
            title: "PRODUCCIÓN",
            subtitle: "Historial unificado de producción en panadería.",
            icon: Icons.bakery_dining,
            color: Colors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionReportScreen())),
          ),
          
          _MenuCard(
            title: "PEDIDOS",
            subtitle: "Revisión de entregas, totales y saldos pendientes.",
            icon: Icons.cake,
            color: Colors.purple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersReportScreen())),
          ),

          // --- NUEVO BOTÓN DE TRASLADOS ---
          _MenuCard(
            title: "TRASLADOS",
            subtitle: "Movimientos, salidas, y sucursales.",
            icon: Icons.local_shipping,
            color: Colors.blueAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransfersScreen())),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const Gap(20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Gap(5),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}