import 'package:flutter/material.dart';

import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import 'admin/admin_home_screen.dart';
import 'cuenta/mi_cuenta_screen.dart';

/// Pantalla mostrada justo después de iniciar sesión / registrarse.
/// Si el usuario es Administrador, muestra además un acceso al panel de
/// administración (HU-03/04/05/07). El acceso a "Mi cuenta" (HU-06) está
/// disponible para cualquier usuario logueado, sin importar el rol.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<UsuarioModel?> _usuarioFuture;

  @override
  void initState() {
    super.initState();
    _usuarioFuture = AuthService.instancia.obtenerUsuarioActual();
  }

  void _reintentar() {
    setState(() {
      _usuarioFuture = AuthService.instancia.obtenerUsuarioActual();
    });
  }

  Future<void> _abrirMiCuenta() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MiCuentaScreen()),
    );
    // Si el usuario cambió su nombre en "Mi cuenta", refresca esta pantalla
    // para mostrarlo actualizado.
    _reintentar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Pedidos'),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: _abrirMiCuenta,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instancia.cerrarSesion(),
          ),
        ],
      ),
      body: FutureBuilder<UsuarioModel?>(
        future: _usuarioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final usuario = snapshot.data;
          if (usuario == null) {
            // Puede pasar justo después de registrarse, mientras el
            // documento de Firestore todavía se está escribiendo.
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar tu perfil todavía.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 36,
                    child: Text(
                      usuario.nombre.isNotEmpty
                          ? usuario.nombre[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Bienvenido/a, ${usuario.nombre}!',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Chip(label: Text(usuario.rol)),
                  const SizedBox(height: 8),
                  Text(
                    usuario.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Conectado a Firebase ✅',
                    style: TextStyle(fontSize: 16, color: Colors.green),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Mi cuenta'),
                    onPressed: _abrirMiCuenta,
                  ),
                  if (usuario.esAdministrador) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Panel de administración'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminHomeScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
