import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/security_provider.dart';

/// Envuelve toda la app: si hay PIN y la app está bloqueada, dibuja la
/// pantalla de bloqueo encima (sin destruir lo que hay debajo).
class LockGate extends StatelessWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool locked = context.watch<SecurityProvider>().isLocked;
    return Stack(
      children: [
        child,
        if (locked) const Positioned.fill(child: PinLockScreen()),
      ],
    );
  }
}

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  bool _wrong = false;

  void _onPin(String pin) {
    final bool ok = context.read<SecurityProvider>().unlock(pin);
    if (!ok) setState(() => _wrong = true);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final security = context.watch<SecurityProvider>();
    final theme = Theme.of(context);
    final int blocked = security.blockedSeconds;

    String? error;
    if (blocked > 0) {
      error = '${locale.t('pin_bloqueado')} $blocked s';
    } else if (_wrong) {
      error = locale.t('pin_incorrecto');
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 44, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  locale.t('pin_ingresa'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                PinPad(onCompleted: _onPin, errorText: error, enabled: blocked == 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Teclado numérico con indicador de puntos. Llama a [onCompleted] al
/// llegar a [SecurityProvider.pinLength] dígitos y se limpia solo.
class PinPad extends StatefulWidget {
  final ValueChanged<String> onCompleted;
  final String? errorText;
  final bool enabled;

  const PinPad({
    super.key,
    required this.onCompleted,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  void _press(String digit) {
    if (!widget.enabled || _digits.length >= SecurityProvider.pinLength) return;
    setState(() => _digits += digit);
    if (_digits.length == SecurityProvider.pinLength) {
      final String pin = _digits;
      setState(() => _digits = '');
      widget.onCompleted(pin);
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Widget _key(Widget label, VoidCallback? onTap) {
    return SizedBox(
      width: 72,
      height: 56,
      child: TextButton(
        onPressed: widget.enabled ? onTap : null,
        child: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? digitStyle =
        theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600);

    Widget digit(String d) => _key(Text(d, style: digitStyle), () => _press(d));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < SecurityProvider.pinLength; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 7),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _digits.length ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(color: theme.colorScheme.primary, width: 1.6),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              widget.errorText ?? '',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) digit(d)],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 72, height: 56),
            digit('0'),
            _key(const Icon(Icons.backspace_outlined), _backspace),
          ],
        ),
      ],
    );
  }
}

enum PinFlow { setNew, change, remove }

/// Diálogo para activar, cambiar o quitar el PIN.
Future<void> showPinFlowDialog(BuildContext context, PinFlow flow) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinFlowDialog(flow: flow),
  );
}

enum _Step { current, fresh, confirm }

class _PinFlowDialog extends StatefulWidget {
  final PinFlow flow;
  const _PinFlowDialog({required this.flow});

  @override
  State<_PinFlowDialog> createState() => _PinFlowDialogState();
}

class _PinFlowDialogState extends State<_PinFlowDialog> {
  late _Step _step;
  String _firstEntry = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = widget.flow == PinFlow.setNew ? _Step.fresh : _Step.current;
  }

  Future<void> _onPin(String pin) async {
    final security = context.read<SecurityProvider>();
    final locale = context.read<LocaleProvider>();

    switch (_step) {
      case _Step.current:
        if (!security.verifyPin(pin)) {
          setState(() => _error = locale.t('pin_incorrecto'));
          return;
        }
        if (widget.flow == PinFlow.remove) {
          await security.removePin();
          if (mounted) Navigator.of(context).pop();
          return;
        }
        setState(() {
          _error = null;
          _step = _Step.fresh;
        });
        break;
      case _Step.fresh:
        setState(() {
          _firstEntry = pin;
          _error = null;
          _step = _Step.confirm;
        });
        break;
      case _Step.confirm:
        if (pin != _firstEntry) {
          setState(() {
            _error = locale.t('pin_no_coincide');
            _step = _Step.fresh;
          });
          return;
        }
        await security.setPin(pin);
        if (mounted) Navigator.of(context).pop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final String title;
    switch (_step) {
      case _Step.current:
        title = locale.t('pin_actual');
        break;
      case _Step.fresh:
        title = locale.t('pin_nuevo');
        break;
      case _Step.confirm:
        title = locale.t('pin_confirmar');
        break;
    }

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [PinPad(onCompleted: _onPin, errorText: _error)],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
      ],
    );
  }
}
