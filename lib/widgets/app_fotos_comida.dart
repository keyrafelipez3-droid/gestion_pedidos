/// Fotos de comida incluidas en la app (assets/images/) que se usan de
/// respaldo cuando un negocio todavía no subió su propio banner, para que
/// las pantallas no se vean vacías y cada negocio se vea distinto.
const List<String> fotosComida = [
  'assets/images/comida_banner.jpg',
  'assets/images/comida_hamburguesa.jpg',
  'assets/images/comida_papas.jpg',
  'assets/images/comida_steak.jpg',
  'assets/images/comida_costilla.jpg',
  'assets/images/comida_terraza.jpg',
];

/// Foto de respaldo según la posición del negocio en la lista: las
/// tarjetas vecinas nunca repiten foto (hasta agotar las disponibles).
String fotoComidaPorIndice(int indice) => fotosComida[indice % fotosComida.length];

/// Foto de respaldo estable a partir de un texto (ej. el id del negocio),
/// para cuando no se conoce su posición en la lista.
String fotoComidaPara(String clave) {
  var h = 0;
  for (final c in clave.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return fotosComida[h % fotosComida.length];
}
