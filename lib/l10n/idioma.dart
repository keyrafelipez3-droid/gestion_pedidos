import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'traducciones_en.dart';
import 'traducciones_fr.dart';
import 'traducciones_pt.dart';

/// Idiomas de la app. El español es el idioma base: los textos se escriben
/// en español en el código y `tr()` los cambia por su traducción.
///
/// Alcance: la parte del cliente (pedir, carrito, pagar, seguir el pedido,
/// reseñas, Mi cuenta) y el inicio de sesión / registro. El panel del
/// personal (Administrador, Cajero, Cocina, Repartidor, SuperAdmin) se
/// mantiene siempre en español.
class Idioma {
  final String codigo;
  final String nombre; // en su propio idioma
  const Idioma(this.codigo, this.nombre);

  static const espanol = Idioma('es', 'Español');
  static const todos = [
    espanol,
    Idioma('en', 'English'),
    Idioma('pt', 'Português'),
    Idioma('fr', 'Français'),
  ];

  static List<Locale> get locales => [for (final i in todos) Locale(i.codigo)];

  static bool soportado(String codigo) => todos.any((i) => i.codigo == codigo);
}

const _traducciones = <String, Map<String, String>>{
  'en': traduccionesEn,
  'pt': traduccionesPt,
  'fr': traduccionesFr,
};

/// Guarda el idioma elegido y avisa a la app cuando cambia.
class IdiomaController {
  IdiomaController._();
  static final instancia = IdiomaController._();

  static const _clave = 'idioma';

  /// Idioma que se está mostrando ahora mismo.
  final ValueNotifier<String> codigo = ValueNotifier('es');

  String _elegido = 'es';
  bool _soloEspanol = false;

  /// Idioma que eligió la persona (aunque ahora se muestre en español
  /// porque inició sesión alguien del personal).
  String get elegido => _elegido;

  /// Se llama una vez al arrancar: usa el idioma guardado o, si es la
  /// primera vez, el del dispositivo (si la app lo tiene).
  Future<void> cargar() async {
    String? guardado;
    try {
      final prefs = await SharedPreferences.getInstance();
      guardado = prefs.getString(_clave);
    } catch (_) {
      // Sin almacenamiento disponible: se usa el idioma del dispositivo.
    }
    final dispositivo = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _elegido = guardado != null && Idioma.soportado(guardado)
        ? guardado
        : (Idioma.soportado(dispositivo) ? dispositivo : 'es');
    _actualizar();
  }

  Future<void> cambiar(String nuevo) async {
    if (!Idioma.soportado(nuevo)) return;
    _elegido = nuevo;
    _actualizar();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, nuevo);
    } catch (_) {
      // Si no se puede guardar, igual se aplica por esta sesión.
    }
  }

  /// El personal del negocio siempre ve la app en español.
  void soloEspanol(bool valor) {
    _soloEspanol = valor;
    _actualizar();
  }

  void _actualizar() {
    final nuevo = _soloEspanol ? 'es' : _elegido;
    if (nuevo == codigo.value) return;
    codigo.value = nuevo;
    _redibujarTodo();
  }

  /// Vuelve a construir todas las pantallas abiertas (como al recargar en
  /// caliente): así los textos ya dibujados también cambian de idioma y no
  /// se pierde lo que la persona estaba haciendo.
  static void _redibujarTodo() {
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    void ejecutar() => WidgetsBinding.instance.rootElement?.visitChildren(marcar);

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => ejecutar());
    } else {
      ejecutar();
    }
  }
}

/// Traduce un texto escrito en español al idioma actual. Si falta la
/// traducción, devuelve el texto en español (nunca queda vacío).
///
/// Los datos variables van entre llaves y se pasan en [datos]:
///   tr('¡Hola, {nombre}!', {'nombre': usuario.nombre})
String tr(String es, [Map<String, Object?> datos = const {}]) {
  final cod = IdiomaController.instancia.codigo.value;
  var texto = cod == 'es' ? es : (_traducciones[cod]?[es] ?? es);
  datos.forEach((k, v) => texto = texto.replaceAll('{$k}', '${v ?? ''}'));
  return texto;
}

/// Traduce los comentarios automáticos del historial de un pedido
/// ("Motivo: ...", "Pedido creado por el cliente.", etc.).
String trComentario(String comentario) {
  const prefijo = 'Motivo: ';
  if (comentario.startsWith(prefijo)) {
    return tr('Motivo: {motivo}', {'motivo': tr(comentario.substring(prefijo.length).trim())});
  }
  final mesa = RegExp(r'^Pedido registrado por el Cajero para la mesa (.+)\.$').firstMatch(comentario);
  if (mesa != null) {
    return tr('Pedido registrado por el Cajero para la mesa {numero}.', {'numero': mesa.group(1)});
  }
  return tr(comentario);
}

/// Botón para cambiar el idioma (ícono de globo + código).
class BotonIdioma extends StatelessWidget {
  /// Color del ícono y el texto (por ejemplo blanco sobre una foto).
  final Color? color;
  const BotonIdioma({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final ctrl = IdiomaController.instancia;
    return ValueListenableBuilder<String>(
      valueListenable: ctrl.codigo,
      builder: (context, actual, _) => PopupMenuButton<String>(
        tooltip: tr('Idioma'),
        initialValue: actual,
        onSelected: ctrl.cambiar,
        itemBuilder: (_) => [
          for (final i in Idioma.todos)
            PopupMenuItem(
              value: i.codigo,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      i.codigo.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(i.nombre)),
                  if (i.codigo == actual) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 20, color: color),
              const SizedBox(width: 4),
              Text(
                actual.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opción "Idioma" para listas de ajustes (Mi cuenta).
class TileIdioma extends StatelessWidget {
  const TileIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = IdiomaController.instancia;
    final actual = Idioma.todos.firstWhere(
      (i) => i.codigo == ctrl.elegido,
      orElse: () => Idioma.espanol,
    );
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(tr('Idioma')),
      subtitle: Text(actual.nombre),
      trailing: const BotonIdioma(),
    );
  }
}
