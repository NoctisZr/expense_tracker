import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../utils/mod_shapes.dart';
import 'expense_list_item.dart';

const Map<String, List<String>> _monthNames = {
  'es': [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ],
  'en': [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ],
  'pt': [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ],
};

const Map<String, List<String>> _weekdayShort = {
  'es': ['D', 'L', 'M', 'M', 'J', 'V', 'S'],
  'en': ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
  'pt': ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'],
};

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ExpenseCalendar extends StatefulWidget {
  const ExpenseCalendar({super.key});

  @override
  State<ExpenseCalendar> createState() => _ExpenseCalendarState();
}

class _ExpenseCalendarState extends State<ExpenseCalendar> {
  late DateTime _displayedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final extras = theme.extension<AppThemeExtras>()!;
    final String lang = _monthNames.containsKey(locale.languageCode) ? locale.languageCode : 'es';

    final Set<DateTime> daysWithExpenses = finance.expenseDaysInMonth(_displayedMonth);
    final int firstWeekdayIndex = _displayedMonth.weekday % 7;
    final int daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final int totalCells = firstWeekdayIndex + daysInMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              '${_monthNames[lang]![_displayedMonth.month - 1]} ${_displayedMonth.year}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: _weekdayShort[lang]!
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < firstWeekdayIndex) return const SizedBox.shrink();
            final int day = index - firstWeekdayIndex + 1;
            final DateTime date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
            final bool hasExpense = daysWithExpenses.contains(date);
            final bool isSelected = _selectedDay != null && _isSameDay(_selectedDay!, date);
            final bool isToday = _isSameDay(DateTime.now(), date);
            final Color dotColor = isSelected ? AppColors.onColorFor(accent) : extras.expense;

            return Padding(
              padding: const EdgeInsets.all(3),
              child: Material(
                color: isSelected ? accent : Colors.transparent,
                shape: CircleBorder(
                  side: (isToday && !isSelected) ? BorderSide(color: accent, width: 1.4) : BorderSide.none,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _selectedDay = date),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected ? AppColors.onColorFor(accent) : theme.colorScheme.onSurface,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 5,
                        width: 5,
                        child: hasExpense
                            ? DecoratedBox(decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        if (_selectedDay != null) _SelectedDayDetail(day: _selectedDay!),
      ],
    );
  }
}

class _SelectedDayDetail extends StatelessWidget {
  final DateTime day;
  const _SelectedDayDetail({required this.day});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;
    final expenses = finance.expensesOnDay(day);

    final Set<String> currenciesThatDay = expenses.map((e) => e.currency).toSet();
    final double dayTotal = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadiusApproxFor(extras.cardShapeKey, extras.cardRadius - 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDateShort(day),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (expenses.isNotEmpty && currenciesThatDay.length == 1)
                Text(
                  '${locale.t('gastado_el_dia')}: ${formatCurrency(dayTotal, currenciesThatDay.first)}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(locale.t('sin_gastos_este_dia'), style: TextStyle(color: theme.hintColor)),
            )
          else
            for (int i = 0; i < expenses.length; i++) ...[
              ExpenseListItem(
                expense: expenses[i],
                locale: locale,
                onDelete: () => confirmDeleteExpense(context, expenses[i].id),
              ),
              if (i != expenses.length - 1)
                Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ],
        ],
      ),
    );
  }
}
