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

  static final _borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(32),
    borderSide: BorderSide.none,
  );

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
        border: _borde,
        enabledBorder: _borde,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
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
