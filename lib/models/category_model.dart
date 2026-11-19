import 'package:flutter/material.dart';

/// Categorías predefinidas del sistema (H.2 - Categorías de gasto/ahorro).
/// Cada grupo puede además agregar categorías personalizadas
/// (ver GroupModel.customCategories).
class AppCategory {
  final String name;
  final IconData icon;

  const AppCategory(this.name, this.icon);
}

const List<AppCategory> defaultCategories = [
  AppCategory('Comida', Icons.restaurant),
  AppCategory('Transporte', Icons.directions_car),
  AppCategory('Alojamiento', Icons.home_outlined),
  AppCategory('Entretenimiento', Icons.movie_outlined),
  AppCategory('Servicios', Icons.receipt_long_outlined),
  AppCategory('Salud', Icons.local_hospital_outlined),
  AppCategory('Compras', Icons.shopping_bag_outlined),
  AppCategory('Otros', Icons.category_outlined),
];

IconData iconForCategory(String name) {
  return defaultCategories
      .firstWhere(
        (c) => c.name == name,
        orElse: () => const AppCategory('Otros', Icons.category_outlined),
      )
      .icon;
}
