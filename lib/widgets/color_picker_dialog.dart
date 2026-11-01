import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_colors.dart';

/// Selector de color libre (tono, intensidad y brillo) sin dependencias
/// externas. Devuelve el color elegido o null si se cancela.
Future<Color?> showColorPickerDialog(BuildContext context, Color initial) {
  return showDialog<Color>(context: context, builder: (_) => _ColorPickerDialog(initial: initial));
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final HSVColor hsv = HSVColor.fromColor(widget.initial);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  String get _hex => '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final Color color = _color;

    Widget slider(String label, double value, double max, ValueChanged<double> onChanged) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Slider(value: value, min: 0, max: max, onChanged: (v) => setState(() => onChanged(v))),
          ],
        );

    return AlertDialog(
      title: Text(locale.t('color_personalizado')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              child: Text(
                _hex,
                style: TextStyle(color: AppColors.onColorFor(color), fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 8),
            slider(locale.t('color_tono'), _hue, 360, (v) => _hue = v),
            slider(locale.t('color_intensidad'), _saturation, 1, (v) => _saturation = v),
            slider(locale.t('color_brillo'), _value, 1, (v) => _value = v),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(color), child: Text(locale.t('guardar'))),
      ],
    );
  }
}
