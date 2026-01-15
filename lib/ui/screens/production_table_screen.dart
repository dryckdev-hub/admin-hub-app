import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import 'package:excel/excel.dart' hide TextSpan;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import '../../providers/production_provider.dart';
import '../widgets/custom_appbar.dart';

class ProductionTableScreen extends StatelessWidget {
  const ProductionTableScreen({super.key});

  Future<void> _exportToExcel(BuildContext context, ProductionProvider provider) async {
    if (provider.displayList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sin datos para exportar")));
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Produccion'];
    excel.delete('Sheet1');

    // Encabezados
    List<String> headers = ['Fecha', 'Area', 'Producto', 'Cantidad', 'Costo (Raya)', 'Valor (Total)', 'Autorizó', 'Status'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final dateFmt = DateFormat('dd/MM/yyyy');

    for (var row in provider.displayList) {
      DateTime dateVal;
      try {
        dateVal = DateTime.parse(row['fecha']);
      } catch (_) {
        dateVal = DateTime.now();
      }

      sheet.appendRow([
        TextCellValue(dateFmt.format(dateVal)),
        TextCellValue(row['area'] ?? ''),
        TextCellValue(row['producto'] ?? ''),
        IntCellValue(int.tryParse(row['cantidad'].toString()) ?? 0),
        DoubleCellValue(double.tryParse(row['costo_mo'].toString()) ?? 0),
        DoubleCellValue(double.tryParse(row['valor_venta'].toString()) ?? 0),
        TextCellValue(row['autorizo'] ?? '-'),
        TextCellValue(row['status'] ?? '-'),
      ]);
    }

    var fileBytes = excel.encode();
    String fileName = 'Produccion_${DateFormat('dd-MM').format(provider.startDate)}_al_${DateFormat('dd-MM').format(provider.endDate)}.xlsx';

    if (kIsWeb) {
      if (fileBytes != null) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        final anchor = html.AnchorElement(href: url)
          ..style.display = 'none'
          ..download = fileName;

        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      }
    } else {
      try {
        final directory = await getTemporaryDirectory();
        final path = "${directory.path}/$fileName";
        File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
        await Share.shareXFiles([XFile(path)], text: 'Reporte de Producción');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductionProvider>();
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM');

    return Scaffold(
      appBar: const CustomAppBar(title: "Tabla de Producción", showBack: true),
      body: Column(
        children: [
          // BARRA DE HERRAMIENTAS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // --- CAMBIO: AHORA EL RANGO DE FECHAS ES CLICKEABLE ---
                Expanded(
                  child: InkWell(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Rango de Fechas", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.black87),
                            const Gap(6),
                            Text(
                              "${DateFormat('dd/MM').format(provider.startDate)} - ${DateFormat('dd/MM').format(provider.endDate)}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.black54) // Indicador visual extra
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Botón Exportar
                IconButton(
                  icon: const Icon(Icons.file_download, color: Colors.green),
                  tooltip: "Descargar Excel",
                  onPressed: () => _exportToExcel(context, provider),
                ),

                // Menú Ordenar
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Colors.brown),
                  tooltip: "Ordenar por...",
                  onSelected: (val) => provider.setSort(val),
                  itemBuilder: (context) => [
                    _buildSortItem("fecha", "Fecha", provider),
                    _buildSortItem("producto", "Producto", provider),
                    _buildSortItem("cantidad", "Cantidad", provider),
                    _buildSortItem("raya", "Raya (Costo)", provider),
                    _buildSortItem("valor_venta", "Valor", provider),
                    _buildSortItem("area", "Área", provider),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1),

          // TABLA
          Expanded(
            child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text("Fecha", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Área", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Producto", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Cant.", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text("Raya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), numeric: true),
                        DataColumn(label: Text("Valor", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), numeric: true),
                        DataColumn(label: Text("Autorizó", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: provider.displayList.map((row) {
                        return DataRow(cells: [
                          DataCell(Text(dateFmt.format(DateTime.parse(row['fecha'])))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                            child: Text(row['area'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          )),
                          DataCell(Text(row['producto'] ?? '')),
                          DataCell(Text(row['cantidad'].toString())),
                          DataCell(Text(currency.format(double.tryParse(row['costo_mo'].toString()) ?? 0))),
                          DataCell(Text(currency.format(double.tryParse(row['valor_venta'].toString()) ?? 0))),
                          DataCell(Text(row['autorizo'] ?? '')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label, ProductionProvider provider) {
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
            color: isSelected ? Colors.brown : Colors.grey
          ),
          const Gap(8),
          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}