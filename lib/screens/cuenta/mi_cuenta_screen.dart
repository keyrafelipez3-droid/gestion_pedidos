import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/selector_imagen.dart';
import '../../widgets/app_cargando.dart';

/// HU-06 — "Como usuario, quiero modificar mis datos de cuenta, contraseña,
/// notificaciones y preferencias."
/// Disponible para CUALQUIER usuario logueado (Cliente, Administrador,
/// Cajero, Cocina, Repartidor) — no es exclusiva del panel de admin.
///
/// Fase 4: la misma información se reorganizó en tres secciones con
/// tarjetas (Perfil / Seguridad / Notificaciones) para que sea más fácil
/// de escanear — toda la lógica de guardado sigue igual.
class MiCuentaScreen extends StatefulWidget {
  final bool incrustada;
  const MiCuentaScreen({super.key, this.incrustada = false});

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _fotoPerfilCtrl = TextEditingController();

  UsuarioModel? _usuario;
  bool _cargando = true;
  bool _guardandoPerfil = false;
  bool _guardandoNotificaciones = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final usuario = await AuthService.instancia.obtenerUsuarioActual();
    _nombreCtrl.text = usuario?.nombre ?? '';
    _telefonoCtrl.text = usuario?.telefono ?? '';
    _fotoPerfilCtrl.text = usuario?.fotoPerfil ?? '';
    if (mounted) {
      setState(() {
        _usuario = usuario;
        _cargando = false;
      });
    }
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardandoPerfil = true);
    final error = await AuthService.instancia.actualizarPerfil(
      nombre: _nombreCtrl.text,
      telefono: _telefonoCtrl.text,
      fotoPerfil: _fotoPerfilCtrl.text,
    );
    if (!mounted) return;
    setState(() => _guardandoPerfil = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos de la cuenta actualizados.'),
        backgroundColor: Colors.green,
      ),
    );
    // Refresca el usuario en memoria para que el switch de notificaciones
    // y el resto de la pantalla queden con los datos más recientes.
    _cargar();
  }

  Future<void> _cambiarNotificaciones(bool activas) async {
    setState(() => _guardandoNotificaciones = true);
    final error = await AuthService.instancia.actualizarNotificaciones(activas);
    if (!mounted) return;
    setState(() {
      _guardandoNotificaciones = false;
      if (error == null && _usuario != null) {
        // Actualiza el estado local sin tener que recargar todo el documento.
        _usuario = UsuarioModel(
          idUsuario: _usuario!.idUsuario,
          nombre: _usuario!.nombre,
          email: _usuario!.email,
          telefono: _usuario!.telefono,
          rol: _usuario!.rol,
          fotoPerfil: _usuario!.fotoPerfil,
          idSucursal: _usuario!.idSucursal,
          estado: _usuario!.estado,
          fechaRegistro: _usuario!.fechaRegistro,
          notificacionesActivas: activas,
        );
      }
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _abrirDialogoCambiarPassword() async {
    final formKeyPassword = GlobalKey<FormState>();
    final actualCtrl = TextEditingController();
    final nuevaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    bool guardando = false;
    bool verActual = false;
    bool verNueva = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> guardar() async {
              if (!formKeyPassword.currentState!.validate()) return;

              setDialogState(() => guardando = true);
              final error = await AuthService.instancia.cambiarPassword(
                passwordActual: actualCtrl.text,
                passwordNueva: nuevaCtrl.text,
              );
              setDialogState(() => guardando = false);

              if (!dialogContext.mounted) return;

              if (error != null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(error)),
                );
                return;
              }

              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contraseña actualizada correctamente.'),
                  backgroundColor: Colors.green,
                ),
              );
            }

            return AlertDialog(
              title: const Text('Cambiar contraseña'),
              content: Form(
                key: formKeyPassword,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: actualCtrl,
                        obscureText: !verActual,
                        decoration: InputDecoration(
                          labelText: 'Contraseña actual',
                          suffixIcon: IconButton(
                            icon: Icon(verActual
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setDialogState(() => verActual = !verActual),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Ingresa tu contraseña actual'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nuevaCtrl,
                        obscureText: !verNueva,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          suffixIcon: IconButton(
                            icon: Icon(
                              verNueva ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () =>
                                setDialogState(() => verNueva = !verNueva),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Ingresa la nueva contraseña';
                          }
                          if (v.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmarCtrl,
                        obscureText: !verNueva,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                        ),
                        validator: (v) {
                          if (v != nuevaCtrl.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: guardando ? null : guardar,
                  child: guardando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _fotoPerfilCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: AppCargando());
    }

    final usuario = _usuario;
    if (usuario == null) {
      return const Scaffold(
        body: Center(child: Text('No se pudo cargar tu cuenta.')),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Mi cuenta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        // OJO: antes esto usaba `backgroundImage:
                        // NetworkImage(...)`, que si la imagen falla al
                        // cargar (ej. un link que no es una imagen directa,
                        // como la URL de una página de Pinterest en vez del
                        // archivo de imagen en sí) deja el círculo
                        // completamente en blanco, sin foto NI inicial, sin
                        // avisar nada. Con Image.network + errorBuilder acá
                        // adentro sí cae de vuelta a la inicial cuando el
                        // link no sirve.
                        child: ClipOval(
                          child: usuario.fotoPerfil.trim().isEmpty
                              ? _InicialUsuario(nombre: usuario.nombre)
                              : Image.network(
                                  usuario.fotoPerfil.trim(), webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _InicialUsuario(nombre: usuario.nombre),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              usuario.nombre,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            AppStatusBadge(
                              label: usuario.rol,
                              tone: AppStatusTone.neutral,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _SeccionCuenta(
                    icono: Icons.person_outline,
                    titulo: 'Perfil',
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectorImagen(
                            etiqueta: 'Foto de perfil (opcional)',
                            controller: _fotoPerfilCtrl,
                            rutaStorage: 'usuarios/${usuario.idUsuario}/perfil',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _nombreCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa tu nombre'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _telefonoCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa tu teléfono'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // El correo no se puede editar acá: cambiar el
                          // email de Firebase Auth requiere un flujo de
                          // verificación aparte (fuera del alcance de esta
                          // historia).
                          TextFormField(
                            initialValue: usuario.email,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.email_outlined),
                              helperText: 'El correo no se puede modificar aquí',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed:
                                _guardandoPerfil ? null : _guardarPerfil,
                            child: _guardandoPerfil
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Guardar cambios'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _SeccionCuenta(
                    icono: Icons.lock_outline,
                    titulo: 'Seguridad',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.password_outlined),
                      title: const Text('Cambiar contraseña'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _abrirDialogoCambiarPassword,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  _SeccionCuenta(
                    icono: Icons.notifications_outlined,
                    titulo: 'Notificaciones',
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: _guardandoNotificaciones
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      title: const Text('Recibir notificaciones'),
                      subtitle: const Text(
                        'Avisos sobre el estado de tus pedidos',
                      ),
                      value: usuario.notificacionesActivas,
                      onChanged: _guardandoNotificaciones
                          ? null
                          : (v) => _cambiarNotificaciones(v),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inicial del nombre sobre el color de marca — se usa como avatar por
/// defecto (sin foto subida) y como respaldo si la foto de perfil no
/// pudo cargar (ej. el link guardado no es una imagen directa válida).
class _InicialUsuario extends StatelessWidget {
  final String nombre;
  const _InicialUsuario({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SeccionCuenta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Widget child;

  const _SeccionCuenta({
    required this.icono,
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icono, size: 20, color: scheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
