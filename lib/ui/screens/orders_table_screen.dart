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

import '../../providers/orders_provider.dart';
import '../widgets/custom_appbar.dart';

class OrdersTableScreen extends StatelessWidget {
  const OrdersTableScreen({super.key});

  Future<void> _exportToExcel(BuildContext context, OrdersProvider provider) async {
    if (provider.ordersList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sin datos para exportar")));
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Pedidos'];
    excel.delete('Sheet1');

    // 1. AGREGAMOS "ANTICIPO" A LOS ENCABEZADOS DEL EXCEL
    List<String> headers = ['Fecha Entrega', 'Nota', 'Cliente', 'Pastel', 'Total', 'Anticipo', 'Saldo', 'Estado'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    for (var row in provider.ordersList) {
      DateTime fecha = DateTime.parse(row['fechaentrega']);
      
      sheet.appendRow([
        TextCellValue(dateFmt.format(fecha)),
        TextCellValue(row['Nota'] ?? '-'),
        TextCellValue(row['cliente']),
        TextCellValue(row['tipopastel']),
        DoubleCellValue(double.tryParse(row['total'].toString()) ?? 0),
        // 2. AGREGAMOS EL DATO AL EXCEL
        DoubleCellValue(double.tryParse(row['a_cuenta'].toString()) ?? 0),
        DoubleCellValue(double.tryParse(row['saldo'].toString()) ?? 0),
        TextCellValue(row['statusentrega']),
      ]);
    }

    var fileBytes = excel.encode();
    String fileName = 'Pedidos_${DateFormat('dd-MM').format(provider.startDate)}_al_${DateFormat('dd-MM').format(provider.endDate)}.xlsx';

    if (kIsWeb) {
      if (fileBytes != null) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement..href = url ..style.display = 'none' ..download = fileName;
        html.document.body!.children.add(anchor); anchor.click(); html.document.body!.children.remove(anchor); html.Url.revokeObjectUrl(url);
      }
    } else {
      try {
        final directory = await getTemporaryDirectory();
        final path = "${directory.path}/$fileName";
        File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
        await Share.shareXFiles([XFile(path)], text: 'Reporte de Pedidos');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdersProvider>();
    final currency = NumberFormat.simpleCurrency();
    final dateFmt = DateFormat('dd/MM HH:mm');

    return Scaffold(
      appBar: const CustomAppBar(title: "Tabla de Pedidos", showBack: true),
      body: Column(
        children: [
          // BARRA DE HERRAMIENTAS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Rango de Fechas", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Row(children: [const Icon(Icons.calendar_today, size: 14), const Gap(6), Text("${DateFormat('dd/MM').format(provider.startDate)} - ${DateFormat('dd/MM').format(provider.endDate)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                      ],
                    ),
                  ),
                ),
                
                IconButton(
                  icon: const Icon(Icons.file_download, color: Colors.green),
                  tooltip: "Descargar Excel",
                  onPressed: () => _exportToExcel(context, provider),
                ),

                // MENU ORDENAR
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Colors.brown),
                  tooltip: "Ordenar por...",
                  onSelected: (val) => provider.setSort(val),
                  itemBuilder: (context) => [
                    _buildSortItem("fechaentrega", "Fecha Entrega", provider),
                    _buildSortItem("cliente", "Nombre Cliente", provider),
                    _buildSortItem("saldo", "Mayor Deuda", provider),
                    // 3. NUEVO FILTRO DE ORDENAMIENTO
                    _buildSortItem("acuenta", "Mayor Anticipo", provider),
                    _buildSortItem("total", "Monto Total", provider),
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
                        DataColumn(label: Text("Nota", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Total", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        // 4. NUEVA COLUMNA VISUAL
                        DataColumn(label: Text("Anticipo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), numeric: true),
                        DataColumn(label: Text("Saldo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), numeric: true),
                        DataColumn(label: Text("Estado", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: provider.ordersList.map((order) {
                        final saldo = double.tryParse(order['saldo'].toString()) ?? 0;
                        final total = double.tryParse(order['total'].toString()) ?? 0;
                        final acuenta = double.tryParse(order['a_cuenta'].toString()) ?? 0; // Recuperamos el dato
                        
                        return DataRow(cells: [
                          DataCell(Text(dateFmt.format(DateTime.parse(order['fechaentrega'])))),
                          DataCell(Text(order['Nota'] ?? '-')),
                          DataCell(Text(order['cliente'].toString().length > 15 ? "${order['cliente'].toString().substring(0, 15)}..." : order['cliente'])),
                          DataCell(Text(currency.format(total))),
                          
                          // CELDA DE ANTICIPO (En Azul para distinguir)
                          DataCell(Text(
                            currency.format(acuenta),
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                          )),

                          DataCell(Text(
                            currency.format(saldo),
                            style: TextStyle(color: saldo > 0.1 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: order['statusentrega'] == 'Entregado' ? Colors.green[50] : Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                            child: Text(order['statusentrega'], style: TextStyle(fontSize: 12, color: order['statusentrega'] == 'Entregado' ? Colors.green : Colors.orange[800])),
                          )),
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

  PopupMenuItem<String> _buildSortItem(String value, String label, OrdersProvider provider) {
    final isSelected = provider.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(isSelected ? (provider.order == 'ASC' ? Icons.arrow_upward : Icons.arrow_downward) : Icons.radio_button_unchecked, size: 16, color: isSelected ? Colors.brown : Colors.grey),
          const Gap(8),
          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}