class Product {
  final int id;
  final String name;
  final double price;
  final double currentStock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.currentStock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['producto'] ?? 'Sin Nombre',
      // Convertimos a double de forma segura (la API puede mandar int o string)
      price: double.tryParse(json['precio'].toString()) ?? 0.0,
      currentStock: double.tryParse(json['existencia_final'].toString()) ?? 0.0,
    );
  }
}