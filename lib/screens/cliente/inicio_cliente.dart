import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/negocio_model.dart';
import '../../models/pedido_models.dart';
import '../../theme/brand_style.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formato.dart';
import '../../widgets/app_fotos_comida.dart';
import '../../widgets/app_imagen_red.dart';
import '../../widgets/panel_personal.dart';
import '../../widgets/tarjeta_pedido_personal.dart';
import '../legal/info_negocio_screen.dart';
import 'condiciones_restaurante_screen.dart';
import 'mis_pedidos_screen.dart';
import 'pedido_detalle_screen.dart';

/// true si el pedido todavía no terminó (ni entregado ni cancelado).
bool pedidoEnCurso(PedidoModel p) => p.estado != PedidoEstado.entregado && p.estado != PedidoEstado.cancelado;

/// Lo que se le dice al cliente según el estado de su pedido.
String mensajeEstadoCliente(PedidoModel p) {
  switch (p.estado) {
    case PedidoEstado.pendiente:
      return tr('El restaurante está revisando tu pedido.');
    case PedidoEstado.enPreparacion:
      return tr('La cocina está preparando tu pedido.');
    case PedidoEstado.listo:
      return p.esDelivery ? tr('Tu pedido está listo y pronto sale.') : tr('¡Tu pedido está listo!');
    case PedidoEstado.enCamino:
      return tr('Tu pedido va en camino.');
    case PedidoEstado.llego:
      return tr('Tu repartidor llegó.');
    case PedidoEstado.entregado:
      return tr('Pedido entregado.');
    default:
      return tr('Pedido cancelado.');
  }
}

/// Pantalla de inicio del cliente: su restaurante (portada, logo y botón
/// grande para pedir), sus pedidos en curso y accesos rápidos. Si todavía
/// no entró a ningún restaurante, le pide el código; si entró a varios,
/// los muestra para elegir.
class InicioCliente extends StatelessWidget {
  final String nombre;

  /// Restaurantes a los que entró con su código (null = cargando).
  final List<NegocioModel>? restaurantes;
  final Stream<List<PedidoModel>> pedidos;
  final VoidCallback onIngresarCodigo;
  final VoidCallback onMiCuenta;

  const InicioCliente({
    super.key,
    required this.nombre,
    required this.restaurantes,
    required this.pedidos,
    required this.onIngresarCodigo,
    required this.onMiCuenta,
  });

  @override
  Widget build(BuildContext context) {
    final lista = restaurantes;
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final unico = lista != null && lista.length == 1 ? lista.first : null;

    final accesos = <(IconData, String, String, VoidCallback)>[
      (
        Icons.receipt_long_outlined,
        tr('Mis pedidos'),
        tr('Sigue tus pedidos y revisa los anteriores'),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MisPedidosScreen())),
      ),
      if (unico != null) ...[
        (
          Icons.storefront_outlined,
          tr('Sobre el restaurante'),
          tr('Dirección, contacto y reclamos'),
          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InfoNegocioScreen(negocio: unico))),
        ),
        (
          Icons.gavel_outlined,
          tr('Condiciones'),
          tr('Pagos, entregas y devoluciones'),
          () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CondicionesRestauranteScreen(negocio: unico, soloLectura: true)),
              ),
        ),
      ],
      (
        Icons.manage_accounts_outlined,
        tr('Mi cuenta'),
        tr('Tus datos, alergias y preferencias'),
        onMiCuenta,
      ),
      if (lista != null && lista.isNotEmpty)
        (
          Icons.vpn_key_outlined,
          tr('Agregar un restaurante'),
          tr('Con el código que te dio el restaurante'),
          onIngresarCodigo,
        ),
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final amplio = c.maxWidth >= 720;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: amplio ? AppSpacing.lg : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('¡Hola, {nombre}!', {'nombre': nombre}),
                      style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (lista == null)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (lista.isEmpty)
                      _SinRestaurante(onIngresarCodigo: onIngresarCodigo)
                    else if (unico != null)
                      _PortadaRestaurante(negocio: unico, alto: amplio ? 240 : 200)
                    else
                      _ElegirRestaurante(restaurantes: lista),
                    StreamBuilder<List<PedidoModel>>(
                      stream: pedidos,
                      builder: (context, s) {
                        final todos = [...(s.data ?? const <PedidoModel>[])]
                          ..sort((a, b) => (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
                        final enCurso = todos.where(pedidoEnCurso).toList();
                        PedidoModel? ultimo;
                        for (final p in todos) {
                          if (p.estado == PedidoEstado.entregado && p.origen == PedidoOrigen.cliente) {
                            ultimo = p;
                            break;
                          }
                        }
                        if (enCurso.isEmpty && ultimo == null) return const SizedBox(height: AppSpacing.md);
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final p in enCurso.take(3)) ...[
                                _PedidoEnCurso(pedido: p),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              if (enCurso.isEmpty && ultimo != null) ...[
                                _PedirDeNuevo(pedido: ultimo),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    if (unico != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          textStyle: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onPressed: () => abrirRestaurante(context, unico, fotoRespaldo: fotoComidaPorIndice(0)),
                        icon: const Icon(Icons.restaurant_menu),
                        label: Text(tr('Ver el menú y pedir')),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      tr('Accesos rápidos').toUpperCase(),
                      style: textos.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 4),
                    LayoutBuilder(
                      builder: (context, c2) {
                        const gap = AppSpacing.sm + 4;
                        final columnas = c2.maxWidth >= 640 ? 3 : 2;
                        final ancho = (c2.maxWidth - gap * (columnas - 1)) / columnas;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final a in accesos)
                              SizedBox(
                                width: ancho,
                                child: _AccesoCliente(icono: a.$1, titulo: a.$2, detalle: a.$3, onTap: a.$4),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Portada del restaurante: su foto, su logo y su nombre.
class _PortadaRestaurante extends StatelessWidget {
  final NegocioModel negocio;
  final double alto;

  const _PortadaRestaurante({required this.negocio, required this.alto});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: ClipRRect(
        borderRadius: context.brand.card,
        child: SizedBox(
          height: alto,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImagenRed(
                url: negocio.bannerUrl,
                icono: Icons.storefront_outlined,
                respaldoAsset: fotoComidaPara(negocio.idNegocio),
                descripcion: tr('Portada de {restaurante}', {'restaurante': negocio.nombre}),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x10000000), Color(0xD9000000)],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        border: Border.all(color: scheme.primary, width: 2.5),
                      ),
                      child: ClipOval(
                        child: AppImagenRed(
                          url: negocio.logoUrl,
                          icono: Icons.restaurant,
                          descripcion: tr('Logo de {restaurante}', {'restaurante': negocio.nombre}),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.brand.titulo(negocio.nombre),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textos.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          if (negocio.descripcion.trim().isNotEmpty)
                            Text(
                              negocio.descripcion.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textos.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Todavía no entró a ningún restaurante: le pide el código.
class _SinRestaurante extends StatelessWidget {
  final VoidCallback onIngresarCodigo;

  const _SinRestaurante({required this.onIngresarCodigo});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return TarjetaPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(Icons.vpn_key_outlined, size: 44, color: scheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr('Ingresa el código de tu restaurante'),
            textAlign: TextAlign.center,
            style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr('Te lo da el restaurante donde quieres pedir. También puedes entrar con su enlace o su código QR.'),
            textAlign: TextAlign.center,
            style: textos.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: onIngresarCodigo,
            icon: const Icon(Icons.vpn_key_outlined),
            label: Text(tr('Ingresar código')),
          ),
        ],
      ),
    );
  }
}

/// Entró a varios restaurantes: una tarjeta por restaurante.
class _ElegirRestaurante extends StatelessWidget {
  final List<NegocioModel> restaurantes;

  const _ElegirRestaurante({required this.restaurantes});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('¿Dónde quieres pedir hoy?'), style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        for (final (i, n) in restaurantes.indexed) ...[
          TarjetaPanel(
            padding: EdgeInsets.zero,
            onTap: () => abrirRestaurante(context, n, fotoRespaldo: fotoComidaPorIndice(i)),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 80,
                  child: AppImagenRed(
                    url: n.bannerUrl,
                    icono: Icons.storefront_outlined,
                    respaldoAsset: fotoComidaPorIndice(i),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.nombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      if (n.descripcion.trim().isNotEmpty)
                        Text(
                          n.descripcion.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.bodySmall,
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.md),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Un pedido del cliente que todavía no terminó.
class _PedidoEnCurso extends StatelessWidget {
  final PedidoModel pedido;

  const _PedidoEnCurso({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final color = switch (p.estado) {
      PedidoEstado.listo || PedidoEstado.llego => semantic.success,
      PedidoEstado.enCamino => semantic.info,
      _ => scheme.primary,
    };
    return TarjetaPanel(
      franja: color,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: p.id)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tr('Tu pedido {numero}', {'numero': numeroPedido(p)}),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    EtiquetaPanel(tr(p.estado), color: color),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${mensajeEstadoCliente(p)} ${tr('Toca para seguirlo.')}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Acceso rápido del cliente (ícono, título y una línea de ayuda).
class _AccesoCliente extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _AccesoCliente({required this.icono, required this.titulo, required this.detalle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TarjetaPanel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icono, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            detalle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// "Pedir de nuevo": el último pedido entregado, para repetirlo con un
/// toque (los productos vuelven al carrito y el cliente confirma).
class _PedirDeNuevo extends StatelessWidget {
  final PedidoModel pedido;

  const _PedirDeNuevo({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final scheme = Theme.of(context).colorScheme;
    return TarjetaPanel(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(Icons.replay, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Tu último pedido'), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  [
                    if (p.fechaCreacion != null) formatoFechaHora(p.fechaCreacion!),
                    dinero(p.totalACobrar),
                  ].join(' · '),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: () => volverAPedir(context, p),
            child: Text(tr('Pedir de nuevo')),
          ),
        ],
      ),
    );
  }
}
