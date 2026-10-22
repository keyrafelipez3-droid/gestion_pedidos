import '../l10n/idioma.dart';

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
