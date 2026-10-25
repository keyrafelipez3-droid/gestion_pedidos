import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/services/app_theme_controller.dart';

void main() {
  AppThemeController.usarFuentesDeGoogle = false;

  testWidgets('theme builder produces a valid Material app', (tester) async {
    final theme = AppThemeController.instancia.buildTheme(Brightness.light);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Text('OK')),
      ),
    );

    expect(find.text('OK'), findsOneWidget);
  });
}
