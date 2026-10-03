import 'package:flutter/material.dart';

/// Campo de búsqueda reutilizable para encabezados de listas
/// (Sucursales, Productos, Clientes, etc.). Filtra en el cliente sobre
/// los datos que ya trae el stream — no agrega ninguna consulta nueva a
/// Firestore.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Buscar...',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}
