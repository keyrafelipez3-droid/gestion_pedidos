import 'package:flutter/material.dart';

import '../models/pedido_models.dart';
import '../services/app_theme_controller.dart';
import '../services/sesion_actual.dart';
import '../services/sucursal_service.dart';
import '../utils/reporte_entregas.dart';

/// Arma el reporte de entregas realizadas de quien tiene la sesión abierta:
/// las columnas dependen de su rol y el encabezado lleva su restaurante y
/// su sucursal.
Future<ReporteEntregas> reporteEntregasDeLaSesion({
  required List<PedidoModel> pedidos,
  required String periodo,
  Map<String, String> nombresSucursal = const {},
}) async {
  final u = SesionActual.instancia.actual;
  final negocio = AppThemeController.instancia.negocio.value?.nombre ?? '';
  var nombres = nombresSucursal;
  final idSucursal = u?.idSucursal;
  if (nombres.isEmpty && idSucursal != null && idSucursal.isNotEmpty) {
    try {
      final s = await SucursalService.instancia.obtener(idSucursal);
      if (s != null) nombres = {idSucursal: s.nombre};
    } catch (_) {}
  }
  final sucursal = idSucursal != null && nombres[idSucursal] != null ? ' · Sucursal ${nombres[idSucursal]}' : '';
  return ReporteEntregas(
    negocio: '$negocio$sucursal',
    periodo: periodo,
    persona: u?.nombre ?? '',
    rol: u?.rol ?? '',
    pedidos: pedidos,
    alcance: alcanceDelRol(u?.rol ?? ''),
    nombresSucursal: nombres,
  );
}

/// Botón "Entregas realizadas": descarga el reporte en Word (.docx) o lo
/// abre para imprimir. [cargar] trae las entregas en el momento de tocarlo.
class BotonEntregasRealizadas extends StatefulWidget {
  final Future<ReporteEntregas> Function() cargar;

  /// true: botón con texto (pantallas con espacio); false: solo ícono
  /// (barra superior).
  final bool conTexto;

  const BotonEntregasRealizadas({super.key, required this.cargar, this.conTexto = false});

  @override
  State<BotonEntregasRealizadas> createState() => _BotonEntregasRealizadasState();
}

enum _Accion { word, imprimir }

class _BotonEntregasRealizadasState extends State<BotonEntregasRealizadas> {
  bool _cargando = false;

  Future<void> _hacer(_Accion accion) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _cargando = true);
    try {
      final r = await widget.cargar();
      final ok = accion == _Accion.word ? await descargarWordEntregas(r) : await imprimirEntregas(r);
      messenger.showSnackBar(SnackBar(
        content: Text(!ok
            ? 'Para descargar el Word o imprimir, abre Nami en el navegador de una computadora.'
            : (accion == _Accion.word
                ? 'Reporte descargado: ${r.nombreArchivo} (${r.pedidos.length} entregas)'
                : 'Se abrió el reporte para imprimir (${r.pedidos.length} entregas).')),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo preparar el reporte. Revisa tu conexión e intenta de nuevo.'),
      ));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<PopupMenuEntry<_Accion>> _opciones(BuildContext _) => const [
        PopupMenuItem(
          value: _Accion.word,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.description_outlined),
            title: Text('Descargar en Word'),
          ),
        ),
        PopupMenuItem(
          value: _Accion.imprimir,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined),
            title: Text('Imprimir'),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (widget.conTexto) {
      return PopupMenuButton<_Accion>(
        tooltip: 'Entregas realizadas: Word o imprimir',
        onSelected: _hacer,
        itemBuilder: _opciones,
        child: IgnorePointer(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Entregas realizadas'),
          ),
        ),
      );
    }
    return PopupMenuButton<_Accion>(
      tooltip: 'Entregas realizadas: Word o imprimir',
      icon: const Icon(Icons.print_outlined),
      onSelected: _hacer,
      itemBuilder: _opciones,
    );
  }
}
