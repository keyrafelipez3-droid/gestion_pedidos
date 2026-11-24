import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Campo de selección cuyo menú se abre DEBAJO del campo, del mismo ancho,
/// sin taparlo.
///
/// Reemplaza a `DropdownButtonFormField`: el menú de ese widget se abre
/// encima del campo (centrado en la opción elegida) y tapaba la etiqueta y
/// los campos vecinos. Acepta los mismos `DropdownMenuItem` y la misma
/// `InputDecoration`, así que cambiarlo es solo cambiar el nombre.
class CampoDesplegable<T> extends StatefulWidget {
  /// Valor elegido al principio. Si el padre pasa otro valor después, el
  /// campo lo muestra.
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;

  /// Cómo se ve la opción elegida dentro del campo (si no, se usa la
  /// misma vista que en el menú). Una entrada por cada opción de [items].
  final DropdownButtonBuilder? selectedItemBuilder;

  /// Texto que se muestra cuando no hay nada elegido.
  final Widget? hint;

  /// Se acepta por compatibilidad con `DropdownButtonFormField`: el campo
  /// siempre ocupa el ancho disponible.
  final bool isExpanded;

  const CampoDesplegable({
    super.key,
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.selectedItemBuilder,
    this.hint,
    this.isExpanded = true,
  });

  @override
  State<CampoDesplegable<T>> createState() => _CampoDesplegableState<T>();
}

class _CampoDesplegableState<T> extends State<CampoDesplegable<T>> {
  final _menu = MenuController();
  final _foco = FocusNode(debugLabel: 'CampoDesplegable');
  late T? _valor = widget.initialValue;

  @override
  void didUpdateWidget(covariant CampoDesplegable<T> anterior) {
    super.didUpdateWidget(anterior);
    if (widget.initialValue != anterior.initialValue) {
      _valor = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  int get _indiceElegido => widget.items.indexWhere((i) => i.value == _valor);

  void _elegir(T? valor) {
    setState(() => _valor = valor);
    widget.onChanged?.call(valor);
  }

  void _alternar() {
    if (_menu.isOpen) {
      _menu.close();
    } else {
      _menu.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final habilitado = widget.onChanged != null && widget.items.isNotEmpty;
    final indice = _indiceElegido;
    Widget? elegido;
    if (indice >= 0) {
      final vistas = widget.selectedItemBuilder?.call(context);
      elegido = vistas != null && indice < vistas.length
          ? vistas[indice]
          : widget.items[indice].child;
    }

    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth.isFinite
            ? restricciones.maxWidth
            : 280.0;
        return MenuAnchor(
          controller: _menu,
          childFocusNode: _foco,
          // Un poco de aire entre el campo y el menú.
          alignmentOffset: const Offset(0, AppSpacing.xs),
          style: MenuStyle(
            minimumSize: WidgetStatePropertyAll(Size(ancho, 0)),
            maximumSize: WidgetStatePropertyAll(Size(ancho, 360)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: AppSpacing.xs),
            ),
          ),
          onOpen: () => setState(() {}),
          onClose: () => setState(() {}),
          menuChildren: [
            for (final item in widget.items)
              MenuItemButton(
                onPressed: item.enabled ? () => _elegir(item.value) : null,
                style: MenuItemButton.styleFrom(
                  minimumSize: Size(ancho, 48),
                  maximumSize: Size(ancho, double.infinity),
                  backgroundColor: item.value == _valor
                      ? scheme.primary.withValues(alpha: 0.10)
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                trailingIcon: item.value == _valor
                    ? Icon(Icons.check, size: 18, color: scheme.primary)
                    : null,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontWeight: item.value == _valor ? FontWeight.w700 : null,
                  ),
                  child: item.child,
                ),
              ),
          ],
          builder: (context, controller, _) {
            return Semantics(
              button: true,
              enabled: habilitado,
              child: InkWell(
                focusNode: _foco,
                canRequestFocus: habilitado,
                onTap: habilitado ? _alternar : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: widget.decoration.copyWith(
                    enabled: habilitado,
                    suffixIcon:
                        widget.decoration.suffixIcon ??
                        Icon(
                          controller.isOpen
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                        ),
                  ),
                  isFocused: controller.isOpen,
                  isEmpty: elegido == null && widget.hint == null,
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: elegido ?? widget.hint ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
