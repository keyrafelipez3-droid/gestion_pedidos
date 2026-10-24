import 'package:flutter/material.dart';

import '../l10n/idioma.dart';

/// Lista en vivo que se carga por partes: primero [porPagina] elementos y
/// un botón "Ver más" trae los siguientes. Así una lista con miles de
/// registros no se descarga entera (más rápido y menos lecturas).
class ConsultaPaginada<T> extends StatefulWidget {
  /// Consulta con límite (debe ordenar los resultados).
  final Stream<List<T>> Function(int limite) consulta;
  final int porPagina;

  /// [verMas] es el botón para cargar más, o null si ya está todo.
  final Widget Function(BuildContext context, AsyncSnapshot<List<T>> snapshot, Widget? verMas) builder;

  const ConsultaPaginada({
    super.key,
    required this.consulta,
    required this.builder,
    this.porPagina = 30,
  });

  @override
  State<ConsultaPaginada<T>> createState() => _ConsultaPaginadaState<T>();
}

class _ConsultaPaginadaState<T> extends State<ConsultaPaginada<T>> {
  late int _limite = widget.porPagina;
  late Stream<List<T>> _stream = widget.consulta(_limite);

  void _verMas() {
    setState(() {
      _limite += widget.porPagina;
      _stream = widget.consulta(_limite);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: _stream,
      builder: (context, snapshot) {
        final hayMas = snapshot.hasData && snapshot.data!.length >= _limite;
        final cargando = snapshot.connectionState == ConnectionState.waiting && snapshot.hasData;
        final verMas = !hayMas
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: cargando
                      ? const CircularProgressIndicator()
                      : OutlinedButton.icon(
                          onPressed: _verMas,
                          icon: const Icon(Icons.expand_more),
                          label: Text(tr('Ver más')),
                        ),
                ),
              );
        return widget.builder(context, snapshot, verMas);
      },
    );
  }
}
