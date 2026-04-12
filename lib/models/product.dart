import 'dart:typed_data';

class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String image;
  final Uint8List? imageBytes;
  
  // ✅ RULE: Always use isAvailable for consistency across the app
  final bool isAvailable;

  // 🔴 STOCK: Current inventory count
  final int quantity; 
  final String description;
  final int qtyMorning;
  final int qtyAfternoon;
  final int qtyEvening;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.image,
    this.imageBytes,
    this.isAvailable = true, 
    this.quantity = 0,       
    this.description = '',
    this.qtyMorning = 0,
    this.qtyAfternoon = 0,
    this.qtyEvening = 0,
  });

  /// ✅ Helper to convert from JSON/Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      image: map['image'] ?? '',
      isAvailable: map['isAvailable'] ?? true, 
      quantity: map['quantity'] ?? 0,          
      description: map['description'] ?? '',
      qtyMorning: map['qtyMorning'] ?? 0,
      qtyAfternoon: map['qtyAfternoon'] ?? 0,
      qtyEvening: map['qtyEvening'] ?? 0,
    );
  }

  /// ✅ Helper to convert to Map for Database/API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'image': image,
      'isAvailable': isAvailable, 
      'quantity': quantity,       
      'description': description,
      'qtyMorning': qtyMorning,
      'qtyAfternoon': qtyAfternoon,
      'qtyEvening': qtyEvening,
    };
  }

  /// ✅ ATOMIC UPDATE: Returns a new Product instance with updated fields
  /// Used by ProductProvider.updateFromRemote and reduceStock
  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    String? image,
    Uint8List? imageBytes,
    bool? isAvailable,
    int? quantity, 
    String? description,
    int? qtyMorning,
    int? qtyAfternoon,
    int? qtyEvening,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      image: image ?? this.image,
      imageBytes: imageBytes ?? this.imageBytes,
      isAvailable: isAvailable ?? this.isAvailable, 
      quantity: quantity ?? this.quantity,          
      description: description ?? this.description,
      qtyMorning: qtyMorning ?? this.qtyMorning,
      qtyAfternoon: qtyAfternoon ?? this.qtyAfternoon,
      qtyEvening: qtyEvening ?? this.qtyEvening,
    );
  }
}