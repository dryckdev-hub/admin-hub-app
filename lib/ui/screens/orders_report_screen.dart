import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../providers/orders_provider.dart';
import '../widgets/custom_appbar.dart';
import 'orders_table_screen.dart'; // <--- IMPORTANTE: Importamos la pantalla de tabla

class OrdersReportScreen extends StatefulWidget {
  const OrdersReportScreen({super.key});

  @override
  State<OrdersReportScreen> createState() => _OrdersReportScreenState();
}

class _OrdersReportScreenState extends State<OrdersReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().fetchOrders();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    if (status == 'Entregado') return Colors.green;
    if (status == 'Cancelado') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();
    final currency = NumberFormat.simpleCurrency();
    final dateFmt = DateFormat('dd/MM HH:mm'); // Día/Mes Hora:Min

    return Scaffold(
      appBar: const CustomAppBar(title: "Consulta Pedidos", showBack: true),
      body: Column(
        children: [
          // 1. ZONA DE FILTROS Y BÚSQUEDA
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                // A. Selector de Fechas
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: DateTimeRange(start: provider.startDate, end: provider.endDate),
                      builder: (context, child) => Theme(data: ThemeData.light().copyWith(primaryColor: Theme.of(context).primaryColor), child: child!),
                    );
                    if (picked != null) provider.setDateRange(picked.start, picked.end);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.grey),
                      const Gap(10),
                      Text(
                        "${DateFormat('dd MMM').format(provider.startDate)} - ${DateFormat('dd MMM').format(provider.endDate)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                
                const Gap(12),

                // B. Buscador y Botón de Tabla (Aquí estaba lo que faltaba)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => provider.onSearchChanged(val),
                        decoration: InputDecoration(
                          hintText: "Buscar cliente o nota...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const Gap(8),
                    // BOTÓN PARA IR A LA TABLA / EXCEL
                    IconButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersTableScreen()));
                      },
                      icon: const Icon(Icons.table_view), // Icono de tabla
                      tooltip: "Ver Tabla Avanzada",
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12)
                      ),
                    ),
                  ],
                ),

                const Gap(12),

                // C. Chips de Filtro (Toggle)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: "Pendientes Entrega", 
                        isSelected: provider.filterStatusEntrega == 'Pendiente', 
                        onTap: () => provider.toggleEntregaFilter('Pendiente')
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: "Entregados", 
                        isSelected: provider.filterStatusEntrega == 'Entregado', 
                        onTap: () => provider.toggleEntregaFilter('Entregado')
                      ),
                      const VerticalDivider(width: 20, thickness: 1),
                      _FilterChip(
                        label: "Por Pagar", 
                        isSelected: provider.filterPago == 'Debe', 
                        onTap: () => provider.togglePagoFilter('Debe'),
                        colorOverride: Colors.red,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          // 2. RESUMEN RAPIDO (KPI)
          if (!provider.isLoading && provider.summary.isNotEmpty)
             Container(
               width: double.infinity,
               color: Colors.red[50],
               padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text("Pedidos: ${provider.summary['total_pedidos']}", style: TextStyle(color: Colors.red[900])),
                   Text(
                     "Por Cobrar: ${currency.format(provider.summary['dinero_pendiente'])}", 
                     style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                   ),
                 ],
               ),
             ),

          // 3. LISTADO DE PEDIDOS (TARJETAS)
          Expanded(
            child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.ordersList.isEmpty
                ? const Center(child: Text("No se encontraron pedidos"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.ordersList.length,
                    itemBuilder: (context, index) {
                      final order = provider.ordersList[index];
                      
                      final saldo = double.tryParse(order['saldo'].toString()) ?? 0;
                      final total = double.tryParse(order['total'].toString()) ?? 0;
                      final bool isPaid = saldo <= 0.1;

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), 
                          side: BorderSide(color: isPaid ? Colors.transparent : Colors.red.withOpacity(0.5), width: 1)
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order['cliente'].toString().toUpperCase(), 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                        ),
                                        Text(
                                          "Nota: ${order['Nota'] ?? 'S/N'}",
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(order['statusentrega']).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Text(
                                      order['statusentrega'], 
                                      style: TextStyle(
                                        color: _getStatusColor(order['statusentrega']), 
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold
                                      )
                                    ),
                                  )
                                ],
                              ),
                              const Gap(8),
                              
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 14, color: Colors.brown),
                                  const Gap(4),
                                  Text(
                                    "${dateFmt.format(DateTime.parse(order['fechaentrega']))}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                                  ),
                                ],
                              ),
                              const Gap(4),
                              Text("Pastel: ${order['tipopastel']}", style: TextStyle(color: Colors.grey[800])),
                              
                              const Divider(),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Total: ${currency.format(total)}"),
                                  if (!isPaid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        "Debe: ${currency.format(saldo)}", 
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                      ),
                                    )
                                  else
                                    const Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 16, color: Colors.green), 
                                        Gap(4), 
                                        Text("PAGADO", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                      ]
                                    )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? colorOverride;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.colorOverride});

  @override
  Widget build(BuildContext context) {
    final activeColor = colorOverride ?? Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87, 
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
          ),
        ),
      ),
    );
  }
}