import 'package:flutter/material.dart';

import '../../models/actividad_model.dart';
import '../../models/sucursal_model.dart';
import '../../models/usuario_model.dart';
import '../../services/actividad_service.dart';
import '../../services/admin_service.dart';
import '../../services/sucursal_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/contrasena.dart';
import '../../widgets/campo_telefono.dart';

/// HU-05 — Formulario para que un Administrador cree la cuenta de un
/// empleado y le asigne su rol (y opcionalmente su sucursal).
///
/// Corrección pedida por el docente: esta MISMA pantalla también la usa
/// el SuperAdmin para designar al Administrador de un negocio (desde
/// `superadmin_negocios_screen.dart`) — en ese caso llega con `rolFijo` =
/// Administrador y `idNegocioFijo` = el negocio elegido, así que el rol
/// no se elige (ya viene decidido) y no se muestra sucursal (un
/// Administrador no queda atado a una sucursal, gestiona todo el
/// negocio). Un Administrador normal, en cambio, ya NO puede crear a otro
/// Administrador (eso ahora es exclusivo del SuperAdmin) — por eso
/// `_rolesDisponibles` excluye ese rol cuando no viene fijo.
class CrearEmpleadoScreen extends StatefulWidget {
  final String? rolFijo;
  final String? idNegocioFijo;

  const CrearEmpleadoScreen({super.key, this.rolFijo, this.idNegocioFijo});

  @override
  State<CrearEmpleadoScreen> createState() => _CrearEmpleadoScreenState();
}

class _CrearEmpleadoScreenState extends State<CrearEmpleadoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late String _rolSeleccionado =
      widget.rolFijo ?? _rolesDisponibles.first;
  String? _idSucursalSeleccionada;
  bool _cargando = false;
  bool _verPassword = false;

  // Un Administrador ya no puede crear a otro Administrador — eso ahora
  // lo hace exclusivamente el SuperAdmin (ver comentario de la clase).
  static const List<String> _rolesDisponibles = Rol.staffOperativo;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    final error = await AdminService.instancia.crearEmpleado(
      nombre: _nombreCtrl.text,
      email: _emailCtrl.text,
      telefono: _telefonoCtrl.text,
      password: _passwordCtrl.text,
      rol: _rolSeleccionado,
      idSucursal: _idSucursalSeleccionada,
      idNegocio: widget.idNegocioFijo ?? SesionActual.instancia.idNegocio,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    ActividadService.instancia.registrar(
      ActividadTipo.empleado,
      'Creó la cuenta de ${_nombreCtrl.text.trim()} ($_rolSeleccionado)',
      idNegocio: widget.idNegocioFijo,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Empleado "${_nombreCtrl.text.trim()}" creado.'),
        backgroundColor: context.semanticColors.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rolFijo == Rol.administrador
            ? 'Asignar administrador'
            : 'Nuevo empleado'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa el nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico *',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa el correo';
                        }
                        final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        if (!regex.hasMatch(v.trim())) {
                          return 'Correo no válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    CampoTelefono(
                      controller: _telefonoCtrl,
                      obligatorio: true,
                      contorno: true,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_verPassword,
                      obscuringCharacter: '*',
                      decoration: InputDecoration(
                        labelText: 'Contraseña temporal *',
                        helperText:
                            'Compártela con el empleado para su primer inicio de sesión',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_verPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _verPassword = !_verPassword),
                        ),
                      ),
                      validator: (v) => validarContrasena(v, correo: _emailCtrl.text),
                    ),
                    MedidorContrasena(controller: _passwordCtrl),
                    const SizedBox(height: 16),

                    // Si el rol viene fijo (el SuperAdmin designando un
                    // Administrador para un negocio), no hay nada que
                    // elegir — se muestra solo como texto informativo.
                    if (widget.rolFijo == null) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _rolSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _rolesDisponibles
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _rolSeleccionado = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Un Administrador no queda atado a una sucursal
                      // (gestiona todo el negocio), así que esta pregunta
                      // solo aplica a Cajero/Cocina/Repartidor.
                      StreamBuilder<List<SucursalModel>>(
                        stream: SucursalService.instancia
                            .streamSucursales(SesionActual.instancia.idNegocio!),
                        builder: (context, snapshot) {
                          final sucursales = snapshot.data ?? [];
                          return DropdownButtonFormField<String?>(
                            initialValue: _idSucursalSeleccionada,
                            decoration: InputDecoration(
                              labelText: 'Sucursal (opcional)',
                              helperText: sucursales.isEmpty
                                  ? 'Todavía no hay sucursales creadas'
                                  : 'Déjalo sin asignar si aún no corresponde',
                              prefixIcon: const Icon(Icons.store_outlined),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Sin asignar'),
                              ),
                              ...sucursales.map(
                                (s) => DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text(s.nombre),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _idSucursalSeleccionada = v),
                          );
                        },
                      ),
                    ] else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Rol'),
                        subtitle: Text(widget.rolFijo!),
                      ),
                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: _cargando ? null : _crear,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear empleado'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
