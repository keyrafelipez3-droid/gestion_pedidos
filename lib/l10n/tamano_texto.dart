import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'idioma.dart';

/// Tamaño de letra elegido en la app (accesibilidad). Se guarda en el
/// dispositivo y se aplica a TODA la app, en la web y en el celular. Se
/// multiplica por el tamaño que la persona ya tenga en la configuración de
/// su teléfono o navegador.
class TamanoTexto {
  final String nombre;
  final double escala;
  const TamanoTexto(this.nombre, this.escala);

  static const normal = TamanoTexto('Normal', 1.0);
  static const todos = [
    normal,
    TamanoTexto('Grande', 1.15),
    TamanoTexto('Muy grande', 1.3),
    TamanoTexto('Máximo', 1.5),
  ];

  /// El tamaño más cercano a [escala] (por si se guardó un valor viejo).
  static TamanoTexto deEscala(double escala) => todos.reduce(
        (a, b) => (a.escala - escala).abs() <= (b.escala - escala).abs() ? a : b,
      );
}

/// Escala final del texto: la del sistema por la elegida en la app, con un
/// tope para que las pantallas no se desarmen.
double escalaFinal(double sistema, double app) => (sistema * app).clamp(0.8, 2.0);

class TamanoTextoController {
  TamanoTextoController._();
  static final instancia = TamanoTextoController._();

  static const _clave = 'escalaTexto';
  final ValueNotifier<double> escala = ValueNotifier(1.0);

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      escala.value = TamanoTexto.deEscala(prefs.getDouble(_clave) ?? 1.0).escala;
    } catch (_) {
      // Sin almacenamiento: tamaño normal.
    }
  }

  Future<void> cambiar(double nueva) async {
    escala.value = nueva;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_clave, nueva);
    } catch (_) {
      // Se aplica igual, solo que no se recuerda.
    }
  }
}

/// Aplica el tamaño elegido a todo lo que está debajo (se usa una vez, en
/// el `builder` de MaterialApp).
class EscalaTexto extends StatelessWidget {
  final Widget child;
  const EscalaTexto({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: TamanoTextoController.instancia.escala,
      builder: (context, app, _) {
        final mq = MediaQuery.of(context);
        final sistema = mq.textScaler.scale(1);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(escalaFinal(sistema, app))),
          child: child,
        );
      },
    );
  }
}

/// Muestra las opciones de tamaño con una vista previa.
Future<void> elegirTamanoTexto(BuildContext context) {
  final ctrl = TamanoTextoController.instancia;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => ValueListenableBuilder<double>(
      valueListenable: ctrl.escala,
      builder: (ctx, actual, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Tamaño de letra'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                tr('Elige el tamaño que te resulte más cómodo. Se aplica a toda la app.'),
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final t in TamanoTexto.todos)
                Card(
                  color: t.escala == actual ? Theme.of(ctx).colorScheme.primaryContainer : null,
                  child: ListTile(
                    leading: Text(
                      'Aa',
                      textScaler: TextScaler.linear(t.escala),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    title: Text(tr(t.nombre)),
                    trailing: t.escala == actual ? const Icon(Icons.check_circle) : null,
                    onTap: () => ctrl.cambiar(t.escala),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Botón "Aa" para la barra superior (al lado del idioma).
class BotonTamanoTexto extends StatelessWidget {
  final Color? color;
  const BotonTamanoTexto({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('Tamaño de letra'),
      onPressed: () => elegirTamanoTexto(context),
      icon: Icon(Icons.text_fields, color: color),
    );
  }
}

/// Opción "Tamaño de letra" para Mi cuenta.
class TileTamanoTexto extends StatelessWidget {
  const TileTamanoTexto({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: TamanoTextoController.instancia.escala,
      builder: (context, actual, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.text_fields),
        title: Text(tr('Tamaño de letra')),
        subtitle: Text(tr(TamanoTexto.deEscala(actual).nombre)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => elegirTamanoTexto(context),
      ),
    );
  }
}
