import 'package:flutter/material.dart';

import '../../models/sucursal_model.dart';
import '../../models/usuario_model.dart';
import '../../services/admin_service.dart';
import '../../services/sucursal_service.dart';

/// HU-05 — Formulario para que un Administrador cree la cuenta de un
/// empleado y le asigne su rol (y opcionalmente su sucursal).
class CrearEmpleadoScreen extends StatefulWidget {
  const CrearEmpleadoScreen({super.key});

  @override
  State<CrearEmpleadoScreen> createState() => _CrearEmpleadoScreenState();
}

class _CrearEmpleadoScreenState extends State<CrearEmpleadoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _rolSeleccionado = Rol.cajero;
  String? _idSucursalSeleccionada;
  bool _cargando = false;
  bool _verPassword = false;

  // El administrador puede crear cualquier rol de personal, incluyendo
  // otro Administrador.
  static const List<String> _rolesDisponibles = Rol.staff;

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
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Empleado "${_nombreCtrl.text.trim()}" creado.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo empleado')),
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
                        labelText: 'Nombre completo',
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
                        labelText: 'Correo electrónico',
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

                    TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa el teléfono'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_verPassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña temporal',
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
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 16),

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

                    StreamBuilder<List<SucursalModel>>(
                      stream: SucursalService.instancia.streamSucursales(),
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
