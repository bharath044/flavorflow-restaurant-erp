import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<Category> get categories => List.unmodifiable(_categories);

  List<String> get categoryNames =>
      _categories.map((c) => c.name).toList();

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final remoteCats = await ApiService.getCategories();
      _categories = remoteCats.map((c) => Category(
        name: c['name'],
        icon: iconOf(c['name']),
      )).toList();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  IconData iconOf(String name) {
    switch (name) {
      case 'Rice': return Icons.rice_bowl;
      case 'Noodles': return Icons.ramen_dining;
      case 'Burger': return Icons.lunch_dining;
      case 'Pizza': return Icons.local_pizza;
      case 'Starters': return Icons.restaurant;
      case 'Dessert': return Icons.icecream;
      case 'Beverages': return Icons.local_cafe;
      default: return Icons.fastfood;
    }
  }

  void addCategory(Category category) {
    _categories.add(category);
    notifyListeners();
  }

  void updateCategory(int index, Category updated) {
    _categories[index] = updated;
    notifyListeners();
  }

  void deleteCategory(int index) {
    _categories.removeAt(index);
    notifyListeners();
  }
}
