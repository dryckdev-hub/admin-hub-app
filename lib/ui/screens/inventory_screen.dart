import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import '../../providers/inventory_provider.dart';
import '../../data/models/product_model.dart';
import '../widgets/custom_appbar.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).fetchProducts();
    });
  }

  void _showProductListSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _ProductListSheet(),
    );
  }

  String _formatCategoryName(String raw) {
    if (raw.isEmpty) return raw;
    final spaced = raw.replaceAll('_', ' ');
    return spaced.split(' ').map((word) {
      if (word.isEmpty) return "";
      return "${word[0].toUpperCase()}${word.substring(1)}";
    }).join(' ');
  }

  Future<void> _showAddProductDialog(BuildContext context) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    await provider.fetchCategories(); 

    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    
    String? selectedCategory;
    bool isProduccion = true; 
    bool isRegistradora = true; 
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Agregar Nuevo Producto"),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: "Nombre", prefixIcon: Icon(Icons.bakery_dining)),
              ),
              const Gap(15),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: "Categoría", prefixIcon: Icon(Icons.category), border: OutlineInputBorder()),
                items: provider.categories.map((String catRaw) {
                  return DropdownMenuItem<String>(
                    value: catRaw, 
                    child: Text(_formatCategoryName(catRaw)), 
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedCategory = val),
              ),
              const Gap(15),
              Row(
                children: [
                  Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio", prefixIcon: Icon(Icons.attach_money)))),
                  const Gap(10),
                  Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock", prefixIcon: Icon(Icons.numbers)))),
                ],
              ),
              const Gap(15),
              SwitchListTile(title: const Text("Producción"), value: isProduccion, onChanged: (val) => setState(() => isProduccion = val)),
              SwitchListTile(title: const Text("Registradora"), value: isRegistradora, onChanged: (val) => setState(() => isRegistradora = val)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || selectedCategory == null) return;
                setState(() => isLoading = true);
                final success = await provider.createProduct(nameCtrl.text, selectedCategory!, double.tryParse(priceCtrl.text) ?? 0, int.tryParse(stockCtrl.text) ?? 0, isProduccion, isRegistradora);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? "Creado" : "Error"), backgroundColor: success ? Colors.green : Colors.red));
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text("Guardar"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final filteredProducts = provider.products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: const CustomAppBar(title: "Inventario", showBack: true),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (provider.changes.isNotEmpty) ...[
            FloatingActionButton.extended(heroTag: "fab_list", onPressed: () => _showProductListSheet(context), label: Text("Ver Lista (${provider.changes.length})"), icon: const Icon(Icons.checklist), backgroundColor: Colors.orange),
            const Gap(15),
          ],
          FloatingActionButton(heroTag: "fab_add", onPressed: () => _showAddProductDialog(context), backgroundColor: Theme.of(context).primaryColor, child: const Icon(Icons.add, color: Colors.white, size: 30)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(controller: _searchCtrl, onChanged: (val) => setState(() => _searchQuery = val), decoration: const InputDecoration(hintText: "Buscar...", prefixIcon: Icon(Icons.search))),
          ),
          Expanded(
            child: provider.isLoadingProducts
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    padding: const EdgeInsets.only(bottom: 120),
                    itemBuilder: (context, index) => _ProductCard(key: ValueKey(filteredProducts[index].id), product: filteredProducts[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  const _ProductCard({super.key, required this.product});
  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _updateController(int val) {
    final textVal = val == 0 ? "0" : val.toString();
    if (_qtyCtrl.text != textVal) {
      _qtyCtrl.text = textVal;
      // Mantenemos el cursor al final para que no sea molesto
      _qtyCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _qtyCtrl.text.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final change = provider.changes[widget.product.id];
    final int pendingQty = change != null ? change['quantity'] : 0;

    // Sincronización pasiva (si cambia externamente)
    if (!_qtyCtrl.selection.isValid) {
       _updateController(pendingQty);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row( // Row Principal
          children: [
            // 1. INFORMACIÓN (Expandible para evitar overflow)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis, maxLines: 2),
                  const Gap(4),
                  Wrap( // Wrap ayuda si la pantalla es muy angosta
                    spacing: 8,
                    children: [
                      Text("Stock: ${widget.product.currentStock.toStringAsFixed(0)}", style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                      Text("\$${widget.product.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  )
                ],
              ),
            ),
            
            const Gap(8),

            // 2. CONTROLES (FittedBox ayuda a encogerlos si no caben)
            FittedBox(
              child: Row(
                children: [
                  _buildCircleBtn(Icons.remove, Colors.red, () {
                    provider.addChange(widget.product.id, widget.product.name, -1, null);
                    // Actualización forzada inmediata visual
                    _updateController(pendingQty - 1); 
                  }),
                  
                  Container(
                    width: 60, // Ancho fijo controlado
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: pendingQty > 0 ? Colors.green : (pendingQty < 0 ? Colors.red : Colors.black)),
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8), border: OutlineInputBorder()),
                      onChanged: (val) {
                        final newVal = int.tryParse(val);
                        if (newVal != null) {
                          int current = provider.changes[widget.product.id]?['quantity'] ?? 0;
                          int delta = newVal - current;
                          if (delta != 0) provider.addChange(widget.product.id, widget.product.name, delta, null);
                        } else if (val.isEmpty) {
                           int current = provider.changes[widget.product.id]?['quantity'] ?? 0;
                           provider.addChange(widget.product.id, widget.product.name, -current, null);
                        }
                      },
                    ),
                  ),

                  _buildCircleBtn(Icons.add, Colors.green, () {
                    provider.addChange(widget.product.id, widget.product.name, 1, null);
                    // Actualización forzada inmediata visual
                    _updateController(pendingQty + 1);
                  }),
                ],
              ),
            ),
            
            // 3. EDITAR PRECIO
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.grey),
              onPressed: () => _showPriceDialog(context, widget.product),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, size: 18, color: color), onPressed: onTap, padding: EdgeInsets.zero),
    );
  }

  void _showPriceDialog(BuildContext context, Product product) {
    final ctrl = TextEditingController(text: product.price.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Precio: ${product.name}"),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: "\$ ")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(ctrl.text);
              if (newPrice != null) {
                Provider.of<InventoryProvider>(context, listen: false).addChange(product.id, product.name, 0, newPrice);
                Navigator.pop(context);
              }
            },
            child: const Text("Aplicar"),
          )
        ],
      ),
    );
  }
}

// ... _ProductListSheet (Mantenlo igual que en tu versión anterior, no necesita cambios) ...
class _ProductListSheet extends StatefulWidget {
  const _ProductListSheet();
  @override
  State<_ProductListSheet> createState() => _ProductListSheetState();
}

class _ProductListSheetState extends State<_ProductListSheet> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final changes = provider.changes;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Lista de Ajustes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("¿Limpiar lista?"),
                        content: const Text("Se descartarán todos los cambios."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar")),
                          TextButton(onPressed: () { provider.clearAllChanges(); Navigator.pop(c); Navigator.pop(context); }, child: const Text("Borrar", style: TextStyle(color: Colors.red)))
                        ],
                      )
                    );
                  },
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  label: const Text("Borrar Todo", style: TextStyle(color: Colors.red)),
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: changes.entries.map((entry) {
                  final productId = entry.key;
                  final data = entry.value;
                  return ListTile(
                    title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Ajuste: ${data['quantity'] > 0 ? '+' : ''}${data['quantity']}", style: TextStyle(color: data['quantity'] > 0 ? Colors.green : Colors.red)),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { provider.removeChange(productId); if(provider.changes.isEmpty) Navigator.pop(context); }),
                  );
                }).toList(),
              ),
            ),
            const Gap(10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.all(18)),
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                final success = await provider.commitChanges();
                setState(() => _isSaving = false);
                if (success && mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guardado"), backgroundColor: Colors.green)); }
              },
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("CONFIRMAR"),
            )
          ],
        ),
      ),
    );
  }
}