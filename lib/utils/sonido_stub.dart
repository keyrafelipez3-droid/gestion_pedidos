import 'package:flutter/services.dart';

Future<void> sonarAvisoPedido() async {
  await SystemSound.play(SystemSoundType.alert);
  await HapticFeedback.heavyImpact();
}
