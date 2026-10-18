import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../utils/mod_builder.dart';

/// Selector de color sencillo (tono, saturación, brillo y código hex), sin
/// paquetes externos. Devuelve el color elegido o `null` si se cancela.
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initial,
  required String title,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial, title: title),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  final String title;

  const _ColorPickerDialog({required this.initial, required this.title});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hexController = TextEditingController(text: colorToHex(widget.initial));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor value) {
    setState(() {
      _hsv = value;
      _hexController.text = colorToHex(value.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final Color current = _hsv.toColor();

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: current,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 8),
            Text(locale.t('color_tono')),
            Slider(
              value: _hsv.hue,
              min: 0,
              max: 360,
              onChanged: (v) => _setHsv(_hsv.withHue(v)),
            ),
            Text(locale.t('color_saturacion')),
            Slider(
              value: _hsv.saturation,
              onChanged: (v) => _setHsv(_hsv.withSaturation(v)),
            ),
            Text(locale.t('color_brillo')),
            Slider(
              value: _hsv.value,
              onChanged: (v) => _setHsv(_hsv.withValue(v)),
            ),
            TextField(
              controller: _hexController,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: locale.t('mod_color_hex')),
              onChanged: (text) {
                final Color? parsed = parseHexColor(text);
                if (parsed != null) setState(() => _hsv = HSVColor.fromColor(parsed));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(current),
          child: Text(locale.t('confirmar')),
        ),
      ],
    );
  }
}
