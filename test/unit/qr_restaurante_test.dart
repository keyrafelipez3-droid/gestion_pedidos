import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/screens/admin/qr_restaurante_screen.dart';

void main() {
  test('la hoja para imprimir trae 4 tarjetas con el QR y el código', () {
    final html = htmlQrRestaurante(
      nombre: 'Pollos <Doña> Rosa',
      codigo: 'POLLO1',
      enlace: 'https://gestion-pedidos-univalle.web.app/?r=POLLO1',
      qrPngBase64: 'AAAA',
      colorHex: '#c9a45c',
    );
    expect('class="tarjeta"'.allMatches(html).length, 4);
    expect(html, contains('POLLO1'));
    expect(html, contains('data:image/png;base64,AAAA'));
    expect(html, contains('Pollos &lt;Doña&gt; Rosa'));
    expect(html, isNot(contains('<Doña>')));
    expect(html, isNot(contains('class="logo"')));
  });
}
