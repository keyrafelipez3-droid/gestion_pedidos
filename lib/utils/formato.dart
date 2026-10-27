import '../l10n/idioma.dart';
import '../models/pais.dart';

/// Fecha y hora cortas en español para listas ("21/10 · 14:35").
String formatoFechaHora(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)} · ${dos(f.hour)}:${dos(f.minute)}';
}

/// "19:30".
String formatoHora(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

/// "Hoy 19:30", "Mañana 12:00" o "23/10 19:30" (en el idioma actual).
String formatoProgramado(DateTime f) {
  final hoy = DateTime.now();
  final dia = DateTime(f.year, f.month, f.day);
  final dif = dia.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  if (dif == 0) return tr('Hoy {hora}', {'hora': formatoHora(f)});
  if (dif == 1) return tr('Mañana {hora}', {'hora': formatoHora(f)});
  return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')} ${formatoHora(f)}';
}

/// Monto con la moneda del país del restaurante ("Bs 12.50", "\$12.50").
String dinero(double v) => Paises.actual.formatear(v);

/// Símbolo para poner delante de un campo de monto ("Bs ", "\$").
String prefijoMoneda() {
  final s = Paises.actual.simbolo;
  return s.endsWith(r'$') ? s : '$s ';
}

/// Nombre corto de la moneda para etiquetas ("Bs", "\$").
String simboloMoneda() => Paises.actual.simbolo;

/// Minutos que pasaron desde [desde] (0 si no se sabe o es en el futuro).
int minutosTranscurridos(DateTime? desde, {DateTime? ahora}) {
  if (desde == null) return 0;
  final m = (ahora ?? DateTime.now()).difference(desde).inMinutes;
  return m < 0 ? 0 : m;
}

/// "recién", "hace 8 min", "hace 1 h 05" o "hace 2 d".
String haceTiempo(DateTime? desde, {DateTime? ahora}) {
  if (desde == null) return '';
  final m = minutosTranscurridos(desde, ahora: ahora);
  if (m < 1) return tr('recién');
  if (m < 60) return tr('hace {n} min', {'n': m});
  if (m < 24 * 60) {
    return tr('hace {h} h {m}', {'h': m ~/ 60, 'm': (m % 60).toString().padLeft(2, '0')});
  }
  return tr('hace {n} d', {'n': m ~/ (24 * 60)});
}

/// Duración corta: "35 min", "1 h 05" o "2 d".
String duracionCorta(int minutos) {
  if (minutos < 60) return '$minutos min';
  if (minutos < 24 * 60) return '${minutos ~/ 60} h ${(minutos % 60).toString().padLeft(2, '0')}';
  return '${minutos ~/ (24 * 60)} d';
}
