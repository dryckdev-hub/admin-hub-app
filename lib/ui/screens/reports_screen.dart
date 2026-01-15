import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gap/gap.dart';
// Ocultamos TextSpan del paquete excel para evitar conflictos con Flutter
import 'package:excel/excel.dart' hide TextSpan; 
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import '../../providers/reports_provider.dart';
import '../widgets/custom_appbar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
  }

  // --- FUNCIÓN DE EXPORTACIÓN A EXCEL (Tu código original) ---
  Future<void> _exportToExcel(ReportsProvider provider) async {
    if (provider.reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar")));
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Reporte'];
    excel.delete('Sheet1'); 

    final fileNameFormat = DateFormat('dd-MM-yyyy');
    final cellFormat = DateFormat('dd/MM/yyyy');

    List<String> headers = ['Fecha', 'Folio', 'Venta Total', 'Tickets', 'Cancelados', 'En Caja'];
    sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (var row in provider.reportData) {
      DateTime fechaObj = DateTime.parse(row['fecha'].toString());
      sheetObject.appendRow([
        TextCellValue(cellFormat.format(fechaObj)),
        TextCellValue(row['folio_corte'] ?? '-'),
        DoubleCellValue(double.tryParse(row['venta_total'].toString()) ?? 0.0),
        IntCellValue(double.parse(row['num_tickets'].toString()).round()),
        IntCellValue(double.parse(row['cancelados'].toString()).round()), 
        DoubleCellValue(double.tryParse(row['efectivoencaja'].toString()) ?? 0.0),
      ]);
    }

    var fileBytes = excel.encode();
    String fileName = 'Reporte_Ventas_${fileNameFormat.format(provider.startDate)}_al_${fileNameFormat.format(provider.endDate)}.xlsx';

    if (kIsWeb) {
      if (fileBytes != null) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fileName;
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Descarga iniciada"), backgroundColor: Colors.green));
      }
    } else {
      try {
        final directory = await getTemporaryDirectory();
        final path = "${directory.path}/$fileName";
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes!);
        await Share.shareXFiles([XFile(path)], text: 'Reporte de Ventas Generado');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al exportar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final currency = NumberFormat.simpleCurrency();
    final displayDate = DateFormat('dd/MM/yyyy', 'es');

    return Scaffold(
      appBar: const CustomAppBar(title: "Consulta Ventas", showBack: true),
      body: Column(
        children: [
          // 1. BARRA SUPERIOR (FECHAS + EXCEL + ORDENAR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                // A. Selector de Fechas (Estilo limpio)
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: DateTimeRange(start: provider.startDate, end: provider.endDate),
                        builder: (context, child) => Theme(data: ThemeData.light().copyWith(primaryColor: Theme.of(context).primaryColor, colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor)), child: child!),
                      );
                      if (picked != null) provider.setDateRange(picked.start, picked.end);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Periodo de Consulta", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
                            const Gap(8),
                            Text(
                              "${displayDate.format(provider.startDate)} - ${displayDate.format(provider.endDate)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // B. Botón Exportar Excel
                IconButton(
                  onPressed: () => _exportToExcel(provider),
                  icon: const Icon(Icons.file_download, color: Colors.green),
                  tooltip: "Exportar a Excel",
                ),

                // C. NUEVO: Botón de Ordenar
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Colors.brown),
                  tooltip: "Ordenar tabla por...",
                  onSelected: (val) => provider.setSort(val),
                  itemBuilder: (context) => [
                    _buildSortItem("fecha", "Fecha", provider),
                    _buildSortItem("venta", "Mayor Venta", provider),
                    _buildSortItem("tickets", "Más Tickets", provider),
                    _buildSortItem("cancelados", "Más Cancelados", provider),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. CONTENIDO PRINCIPAL
          Expanded(
             child: provider.isLoading
               ? const Center(child: CircularProgressIndicator())
               : Column(
                 children: [
                   // A. Tarjetas de Resumen (KPIs)
                   if (provider.reportData.isNotEmpty)
                     Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                title: "Venta Total",
                                content: Text(
                                  currency.format(provider.totals['sales']),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                icon: Icons.attach_money,
                                color: Colors.green,
                                comparisonPercent: provider.comparisonPercent,
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: _InfoCard(
                                title: "Tickets / Cancelados",
                                content: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                      children: [
                                        TextSpan(text: "${provider.totals['tickets']} / "),
                                        TextSpan(
                                          text: "${provider.totals['cancelled']}",
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                icon: Icons.receipt_long,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                   // B. Tabla de Datos
                   Expanded(
                      child: provider.reportData.isEmpty
                        ? const Center(child: Text("No hay registros en estas fechas"))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                                columnSpacing: 20,
                                columns: const [
                                  DataColumn(label: Text("Fecha", style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text("Folio", style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text("Venta", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                  DataColumn(label: Text("Tickets", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                  DataColumn(label: Text("Cancelados", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), numeric: true),
                                  DataColumn(label: Text("En Caja", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                ],
                                rows: provider.reportData.map((row) {
                                  DateTime fechaRow = DateTime.parse(row['fecha'].toString());
                                  return DataRow(cells: [
                                    DataCell(Text(displayDate.format(fechaRow))),
                                    DataCell(Text(row['folio_corte'] ?? '-')),
                                    DataCell(Text("\$${row['venta_total']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                    DataCell(Text("${double.parse(row['num_tickets'].toString()).round()}")),
                                    DataCell(Text("${double.parse(row['cancelados'].toString()).round()}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                    DataCell(Text("\$${row['efectivoencaja'] ?? 0}")),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                   ),
                 ],
               ),
          ),
        ],
      ),
    );
  }

  // Helper para construir los ítems del menú de ordenar
  PopupMenuItem<String> _buildSortItem(String value, String label, ReportsProvider provider) {
    final isSelected = provider.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected 
              ? (provider.order == 'ASC' ? Icons.arrow_upward : Icons.arrow_downward) 
              : Icons.radio_button_unchecked,
            size: 16,
            color: isSelected ? Colors.brown : Colors.grey,
          ),
          const Gap(8),
          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData icon;
  final Color color;
  final double? comparisonPercent;

  const _InfoCard({required this.title, required this.content, required this.icon, required this.color, this.comparisonPercent});

  @override
  Widget build(BuildContext context) {
    bool isPositive = (comparisonPercent ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const Gap(8), Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis))]),
          const Gap(8),
          content, 
          if (comparisonPercent != null) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: isPositive ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: isPositive ? Colors.green : Colors.red),
                const Gap(4),
                Text("${comparisonPercent!.toStringAsFixed(1)}% vs mes ant.", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPositive ? Colors.green : Colors.red))
              ]),
            )
          ]
        ],
      ),
    );
  }
}
