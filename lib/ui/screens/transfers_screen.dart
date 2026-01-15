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

import '../../providers/transfers_provider.dart';
import '../widgets/custom_appbar.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  // 1. Controlador para el buscador local
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransfersProvider>().fetchMovements();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- EXPORTAR A EXCEL ---
  // Nota: Esto lee directamente del provider (lista completa), ignorando el buscador local.
  Future<void> _exportToExcel(TransfersProvider provider) async {
    if (provider.movementsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sin datos para exportar")));
      return;
    }

    var excel = Excel.createExcel();
    Sheet sheet = excel['Traslados'];
    excel.delete('Sheet1');

    sheet.appendRow(['Fecha/Hora', 'Movimiento', 'Sucursal', 'Producto', 'Autorizó', 'Piezas', 'Costo Total'].map((e) => TextCellValue(e)).toList());
    
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    for (var row in provider.movementsList) {
      DateTime fecha;
      if (row['fecha_full'] != null) {
        fecha = DateTime.parse(row['fecha_full'].toString());
      } else {
        fecha = DateTime.parse(row['fecha'].toString());
      }

      sheet.appendRow([
        TextCellValue(dateFmt.format(fecha)),
        TextCellValue(row['movimiento']),
        TextCellValue(row['contraparte'] ?? '-'),
        TextCellValue(row['producto'] ?? '-'),
        TextCellValue(row['autorizo'] ?? '-'),
        IntCellValue(double.parse(row['total_piezas'].toString()).toInt()),
        DoubleCellValue(double.parse(row['costo_total'].toString())),
      ]);
    }

    var fileBytes = excel.encode();
    String fileName = 'Traslados_${DateFormat('dd-MM').format(provider.startDate)}_al_${DateFormat('dd-MM').format(provider.endDate)}.xlsx';

    if (kIsWeb) {
      if (fileBytes != null) {
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement..href = url..style.display = 'none'..download = fileName;
        html.document.body!.children.add(anchor); anchor.click(); html.document.body!.children.remove(anchor); html.Url.revokeObjectUrl(url);
      }
    } else {
      try {
        final dir = await getTemporaryDirectory();
        final path = "${dir.path}/$fileName";
        File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
        await Share.shareXFiles([XFile(path)], text: 'Reporte Traslados');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransfersProvider>();
    final currency = NumberFormat.simpleCurrency();
    final dateFmt = DateFormat('dd/MM HH:mm'); 

    // 2. FILTRO LOCAL (VISUAL)
    // Creamos una lista filtrada al vuelo sin tocar el provider
    final filteredList = provider.movementsList.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      
      final prod = item['producto']?.toString().toLowerCase() ?? '';
      final suc = item['contraparte']?.toString().toLowerCase() ?? '';
      final auth = item['autorizo']?.toString().toLowerCase() ?? '';
      final qty = item['total_piezas']?.toString() ?? '';

      return prod.contains(query) || suc.contains(query) || auth.contains(query) || qty.contains(query);
    }).toList();

    // 3. RE-CALCULO DE TOTALES VISUALES
    // Para que los KPIs de abajo coincidan con lo que estás buscando
    double visibleCosto = 0;
    int visiblePiezas = 0;
    for (var m in filteredList) {
      visibleCosto += double.tryParse(m['costo_total'].toString()) ?? 0;
      visiblePiezas += double.tryParse(m['total_piezas'].toString())?.toInt() ?? 0;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: "Consulta Traslados", showBack: true),
      body: Column(
        children: [
          // 1. ZONA DE CONTROLES
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // A. FILA SUPERIOR: FECHAS Y BOTONES
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: DateTimeRange(start: provider.startDate, end: provider.endDate),
                            builder: (context, child) => Theme(data: ThemeData.light().copyWith(primaryColor: Theme.of(context).primaryColor), child: child!),
                          );
                          if (picked != null) {
                            // Limpiamos la búsqueda al cambiar fechas para evitar confusión
                            _searchCtrl.clear();
                            setState(() => _searchQuery = "");
                            provider.setDateRange(picked.start, picked.end);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Rango", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Row(children: [const Icon(Icons.calendar_today, size: 14), const Gap(5), Text("${DateFormat('dd/MM').format(provider.startDate)} - ${DateFormat('dd/MM').format(provider.endDate)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.file_download, color: Colors.green), tooltip: "Exportar Todo", onPressed: () => _exportToExcel(provider)),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort, color: Colors.brown),
                      tooltip: "Ordenar por...",
                      onSelected: (val) => provider.setSort(val),
                      itemBuilder: (ctx) => [
                        _buildSortItem("fecha_full", "Fecha y Hora", provider),
                        _buildSortItem("producto", "Producto", provider),
                        _buildSortItem("contraparte", "Sucursal", provider),
                        _buildSortItem("piezas", "Cantidad (Piezas)", provider),
                        _buildSortItem("costo", "Mayor Costo", provider),
                        _buildSortItem("autorizo", "Autorizó", provider),
                      ],
                    ),
                  ],
                ),
                
                const Gap(10),

                // B. BUSCADOR VISUAL (Aquí lo insertamos)
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Buscar producto, sucursal, piezas, autorizó...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),

                const Gap(10),
                
                // C. CHIPS DE TIPO
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: "Todos", sel: provider.filterType == 'Todos', onTap: () => provider.setFilterType('Todos')),
                      _FilterChip(label: "Salidas", sel: provider.filterType == 'Salida', onTap: () => provider.setFilterType('Salida'), color: Colors.blue),
                      _FilterChip(label: "Entradas", sel: provider.filterType == 'Entrada', onTap: () => provider.setFilterType('Entrada'), color: Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 2. TOTALES (Usamos los visibles calculados arriba)
          if (!provider.isLoading && filteredList.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blueGrey[50],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   Text("Piezas: $visiblePiezas", style: const TextStyle(fontWeight: FontWeight.bold)),
                   Text("Costo: ${currency.format(visibleCosto)}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
                ],
              ),
            ),

          // 3. TABLA DE MOVIMIENTOS (Usa filteredList)
          Expanded(
            child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredList.isEmpty
              ? const Center(child: Text("No se encontraron resultados"))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text("Fecha/Hora", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Tipo", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Sucursal", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Producto", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("Piezas", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text("Costo", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text("Autorizó", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredList.map((row) {
                        DateTime fecha;
                        if (row['fecha_full'] != null) {
                          fecha = DateTime.parse(row['fecha_full'].toString());
                        } else {
                          fecha = DateTime.parse(row['fecha'].toString());
                        }

                        final tipo = row['movimiento'].toString();
                        final isEntrada = tipo == 'Entrada';
                        
                        return DataRow(cells: [
                          DataCell(Text(dateFmt.format(fecha))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isEntrada ? Colors.green[50] : Colors.blue[50],
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(
                              tipo, 
                              style: TextStyle(
                                color: isEntrada ? Colors.green[800] : Colors.blue[900], 
                                fontSize: 12, 
                                fontWeight: FontWeight.bold
                              )
                            ),
                          )),
                          DataCell(Text(row['contraparte'] ?? '-')),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(row['producto'] ?? '-', overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(Text("${double.parse(row['total_piezas'].toString()).toInt()}")),
                          DataCell(Text(currency.format(double.parse(row['costo_total'].toString())))),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(row['autorizo'] ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  PopupMenuItem<String> _buildSortItem(String value, String label, TransfersProvider provider) {
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({required this.label, required this.sel, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? Colors.brown;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.black87)),
        selected: sel,
        onSelected: (_) => onTap(),
        selectedColor: activeColor,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.grey[200],
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}