import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../providers/production_provider.dart';
import '../widgets/custom_appbar.dart';
import 'production_table_screen.dart';

class ProductionReportScreen extends StatefulWidget {
  const ProductionReportScreen({super.key});

  @override
  State<ProductionReportScreen> createState() => _ProductionReportScreenState();
}

class _ProductionReportScreenState extends State<ProductionReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductionProvider>().fetchProduction();
    });
  }

  // --- FUNCIONES DE SEGURIDAD PARA EVITAR EL CRASH 'isNegative' ---
  int _safeInt(dynamic value) {
    if (value == null) return 0;
    return num.tryParse(value.toString())?.toInt() ?? 0;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    return num.tryParse(value.toString())?.toDouble() ?? 0.0;
  }
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductionProvider>();
    // Forzamos locale para asegurar formato moneda correcto
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0, locale: 'es_MX');
    final dateFmt = DateFormat('dd MMM', 'es');

    final groupedData = provider.groupedDays;

    return Scaffold(
      appBar: const CustomAppBar(title: "Consulta Producción", showBack: true),
      body: Column(
        children: [
          // 1. ZONA DE CONTROLES
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de Fechas
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(start: provider.startDate, end: provider.endDate),
                      builder: (context, child) => Theme(
                        data: ThemeData.light().copyWith(primaryColor: Theme.of(context).primaryColor),
                        child: child!,
                      ),
                    );
                    if (picked != null) provider.setDateRange(picked.start, picked.end);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                      const Gap(10),
                      Text(
                        "${dateFmt.format(provider.startDate)} - ${dateFmt.format(provider.endDate)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                const Gap(12),

                // Buscador y Botón Tabla
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => provider.onSearchChanged(val),
                        decoration: InputDecoration(
                          hintText: "Buscar producto...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const Gap(8),
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionTableScreen())),
                      icon: const Icon(Icons.table_view),
                      tooltip: "Ver Tabla Detallada",
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white
                      ),
                    ),
                  ],
                ),
                const Gap(12),

                // Filtro Chips (Áreas)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: provider.availableAreas.map((area) {
                      final isSelected = provider.selectedArea == area;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(area),
                          selected: isSelected,
                          onSelected: (_) => provider.setAreaFilter(area),
                          selectedColor: Theme.of(context).primaryColor,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                          backgroundColor: Colors.grey[100],
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 2. KPIs Generales
          if (!provider.isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniKPI("Piezas", "${_safeInt(provider.totals['piezas'])}", Colors.blue.shade900),
                  _MiniKPI("Costo.", currency.format(_safeDouble(provider.totals['costo'])), Colors.red.shade800),
                  _MiniKPI("Valor Est.", currency.format(_safeDouble(provider.totals['venta'])), Colors.green.shade800),
                ],
              ),
            ),

          // 3. LISTA DE RESULTADOS
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : groupedData.isEmpty
                    ? const Center(child: Text("No hay datos en este rango"))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: groupedData.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final day = groupedData[index];
                          final areasMap = day['areas'] as Map<String, dynamic>;

                          // Parseo de fecha seguro
                          DateTime parsedDate;
                          try {
                            parsedDate = DateTime.parse(day['fecha'].toString());
                          } catch (e) {
                            parsedDate = DateTime.now();
                          }

                          // USAMOS LA LECTURA SEGURA AQUÍ
                          final totalPiezas = _safeInt(day['total_piezas']);
                          final totalCosto = _safeDouble(day['total_costo']);

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_month, color: Colors.brown),
                                ),
                                title: Text(
                                  DateFormat('EEEE dd, MMM', 'es').format(parsedDate).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  "$totalPiezas pzas • ${currency.format(totalCosto)} de Costo.",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                children: areasMap.entries.map((entry) {
                                  final areaName = entry.key;
                                  final stats = entry.value as Map<String, dynamic>;

                                  // USAMOS LA LECTURA SEGURA TAMBIÉN AQUÍ
                                  final pzasArea = _safeInt(stats['piezas']);
                                  final costoArea = _safeDouble(stats['costo']);

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(top: BorderSide(color: Colors.grey.shade100))
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.only(left: 70, right: 20),
                                      title: Text(areaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      trailing: Text(
                                        "$pzasArea pzas  (${currency.format(costoArea)})",
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      ),
                                    ),
                                  );
                                }).toList(),
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

class _MiniKPI extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniKPI(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }
}