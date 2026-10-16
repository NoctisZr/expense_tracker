import 'package:flutter/material.dart';
import '../utils/currency_list.dart';

class CurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> currencies;
  final bool dense;

  const CurrencyDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.currencies = kSupportedCurrencies,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final String safeValue =
        currencies.contains(value) ? value : currencies.first;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: safeValue,
        isDense: dense,
        icon: const Icon(Icons.keyboard_arrow_down),
        dropdownColor: Theme.of(context).colorScheme.surface,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        items: currencies
            .map(
              (code) => DropdownMenuItem<String>(
                value: code,
                child: Text(code),
              ),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
      ),
    );
  }
}
