/// Fecha y hora cortas en español para listas ("21/10 · 14:35").
String formatoFechaHora(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)} · ${dos(f.hour)}:${dos(f.minute)}';
}
