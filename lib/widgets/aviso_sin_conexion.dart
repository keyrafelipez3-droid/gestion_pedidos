import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/idioma.dart';

/// Franja abajo cuando no hay internet. Firestore guarda en el dispositivo
/// lo ya cargado y encola los cambios, así que la app sigue usable; esta
/// franja solo avisa que lo nuevo llegará cuando vuelva la conexión.
///
/// Cómo lo detecta: escucha un documento pequeño (plataforma/app) con
/// metadatos; si los datos vienen solo de la memoria del dispositivo por
/// más de unos segundos, es que no hay conexión con el servidor.
class AvisoSinConexion extends StatefulWidget {
  final Widget child;
  const AvisoSinConexion({super.key, required this.child});

  @override
  State<AvisoSinConexion> createState() => _AvisoSinConexionState();
}

class _AvisoSinConexionState extends State<AvisoSinConexion> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _espera;
  bool _sinConexion = false;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('plataforma')
        .doc('app')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (s) => _actualizar(s.metadata.isFromCache),
          onError: (_) {},
        );
  }

  void _actualizar(bool desdeCache) {
    _espera?.cancel();
    if (!desdeCache) {
      if (_sinConexion && mounted) setState(() => _sinConexion = false);
      return;
    }
    // Al abrir la app los primeros datos también vienen de la memoria:
    // se espera un poco antes de avisar.
    _espera = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _sinConexion = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _espera?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sinConexion) return widget.child;
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(context: context, removeBottom: true, child: widget.child),
        ),
        Material(
          color: const Color(0xFF424242),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Sin conexión a internet. Ves lo último que se cargó; tus cambios se enviarán cuando vuelva la conexión.'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
