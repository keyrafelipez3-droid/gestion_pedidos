import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';

/// HU-06 — "Como usuario, quiero modificar mis datos de cuenta, contraseña,
/// notificaciones y preferencias."
/// Disponible para CUALQUIER usuario logueado (Cliente, Administrador,
/// Cajero, Cocina, Repartidor) — no es exclusiva del panel de admin.
class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({super.key});

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final usuario = _usuario;
    if (usuario == null) {
      return const Scaffold(
        body: Center(child: Text('No se pudo cargar tu cuenta.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Datos de la cuenta',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa tu teléfono'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    // El correo no se puede editar acá: cambiar el email de
                    // Firebase Auth requiere un flujo de verificación aparte
                    // (fuera del alcance de esta historia).
                    TextFormField(
                      initialValue: usuario.email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        helperText: 'El correo no se puede modificar aquí',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _guardandoPerfil ? null : _guardarPerfil,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _guardandoPerfil
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),
              Text('Seguridad', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: const Text('Cambiar contraseña'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _abrirDialogoCambiarPassword,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text('Preferencias', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: _guardandoNotificaciones
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_outlined),
                title: const Text('Notificaciones'),
                subtitle: const Text(
                  'Recibir avisos sobre el estado de tus pedidos',
                ),
                value: usuario.notificacionesActivas,
                onChanged: _guardandoNotificaciones
                    ? null
                    : (v) => _cambiarNotificaciones(v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
