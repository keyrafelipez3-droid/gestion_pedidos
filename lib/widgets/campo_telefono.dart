import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../utils/telefono.dart';

/// Campo de teléfono con selector de país. Escribe en [controller] el número
/// en formato internacional (+59171234567), así el resto de la app no cambia.
class CampoTelefono extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final bool obligatorio;
  final bool contorno;

  const CampoTelefono({
    super.key,
    required this.controller,
    this.etiqueta = 'Teléfono',
    this.obligatorio = false,
    this.contorno = false,
  });

  @override
  State<CampoTelefono> createState() => _CampoTelefonoState();
}

class _CampoTelefonoState extends State<CampoTelefono> {
  late PaisTelefono _pais;
  final _localCtrl = TextEditingController();
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _leerDelControlador();
    widget.controller.addListener(_alCambiarControlador);
    _localCtrl.addListener(_alEscribir);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_alCambiarControlador);
    _localCtrl.dispose();
    super.dispose();
  }

  void _leerDelControlador() {
    final partes = Telefono.separar(widget.controller.text);
    _pais = partes.pais;
    _localCtrl.text = partes.numero;
  }

  // El valor se cambió desde afuera (por ejemplo al cargar el perfil).
  void _alCambiarControlador() {
    if (_sincronizando) return;
    if (widget.controller.text == Telefono.componer(_pais, _localCtrl.text)) {
      return;
    }
    setState(_leerDelControlador);
  }

  void _escribirEnControlador() {
    _sincronizando = true;
    widget.controller.text = Telefono.componer(_pais, _localCtrl.text);
    _sincronizando = false;
  }

  void _alEscribir() => _escribirEnControlador();

  @override
  Widget build(BuildContext context) {
    final borde = widget.contorno ? const OutlineInputBorder() : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: DropdownButtonFormField<PaisTelefono>(
            key: ValueKey(_pais.iso),
            initialValue: _pais,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'País',
              border: borde,
            ),
            selectedItemBuilder: (_) => [
              for (final p in Telefono.paises)
                Text('+${p.codigo}', overflow: TextOverflow.ellipsis),
            ],
            items: [
              for (final p in Telefono.paises)
                DropdownMenuItem(value: p, child: Text(p.etiqueta)),
            ],
            onChanged: (p) {
              if (p == null) return;
              setState(() => _pais = p);
              _escribirEnControlador();
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextFormField(
            controller: _localCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              labelText: widget.obligatorio
                  ? '${widget.etiqueta} *'
                  : widget.etiqueta,
              prefixIcon: const Icon(Icons.phone_outlined),
              border: borde,
            ),
            validator: (v) => Telefono.validar(
              _pais,
              v ?? '',
              obligatorio: widget.obligatorio,
            ),
          ),
        ),
      ],
    );
  }
}
