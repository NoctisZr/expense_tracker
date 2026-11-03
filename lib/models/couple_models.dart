/// Modelos (solo lectura) de lo que tu pareja comparte contigo, y los ajustes
/// de lo que tú compartes. Nada de esto se mezcla con tus propios datos.

class CouplePrefs {
  final bool expenses;
  final bool incomes;
  final bool vaults;
  final bool debts;

  const CouplePrefs({this.expenses = false, this.incomes = false, this.vaults = false, this.debts = false});

  bool get any => expenses || incomes || vaults || debts;

  CouplePrefs copyWith({bool? expenses, bool? incomes, bool? vaults, bool? debts}) => CouplePrefs(
        expenses: expenses ?? this.expenses,
        incomes: incomes ?? this.incomes,
        vaults: vaults ?? this.vaults,
        debts: debts ?? this.debts,
      );

  Map<String, dynamic> toMap() => {'expenses': expenses, 'incomes': incomes, 'vaults': vaults, 'debts': debts};

  factory CouplePrefs.fromMap(dynamic map) {
    if (map is! Map) return const CouplePrefs();
    return CouplePrefs(
      expenses: map['expenses'] == true,
      incomes: map['incomes'] == true,
      vaults: map['vaults'] == true,
      debts: map['debts'] == true,
    );
  }
}

double _d(dynamic v) => v is num ? v.toDouble() : 0;
DateTime _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

/// Gasto de tu pareja. Si [split] es true es un gasto para dividir: [amount]
/// es la parte de tu pareja y [total] la cuenta completa.
class PExpense {
  final String name;
  final double amount;
  final String currency;
  final String category;
  final DateTime date;
  final bool split;
  final double total;
  final bool paidByAuthor;

  const PExpense({
    required this.name,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.split = false,
    this.total = 0,
    this.paidByAuthor = true,
  });

  factory PExpense.fromData(Map<String, dynamic> d, {required bool split}) => PExpense(
        name: (d['n'] ?? '').toString(),
        amount: _d(d['a']),
        currency: (d['c'] ?? '').toString(),
        category: (d['cat'] ?? 'otros').toString(),
        date: _date(d['d']),
        split: split,
        total: _d(d['t']),
        paidByAuthor: d['pp'] != false,
      );
}

class PIncome {
  final String label;
  final double amount;
  final String currency;
  final DateTime date;
  const PIncome({required this.label, required this.amount, required this.currency, required this.date});

  factory PIncome.fromData(Map<String, dynamic> d) => PIncome(
        label: (d['n'] ?? '').toString(),
        amount: _d(d['a']),
        currency: (d['c'] ?? '').toString(),
        date: _date(d['d']),
      );
}

class PVault {
  final String name;
  final double target;
  final double current;
  final String currency;
  const PVault({required this.name, required this.target, required this.current, required this.currency});

  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();

  factory PVault.fromData(Map<String, dynamic> d) => PVault(
        name: (d['n'] ?? '').toString(),
        target: _d(d['t']),
        current: _d(d['cur']),
        currency: (d['c'] ?? '').toString(),
      );
}

class PDebt {
  final String person;
  final double amount;
  final String currency;

  /// true = le deben a tu pareja; false = tu pareja debe.
  final bool owedToAuthor;
  final DateTime date;
  final bool paid;
  final String? note;

  const PDebt({
    required this.person,
    required this.amount,
    required this.currency,
    required this.owedToAuthor,
    required this.date,
    required this.paid,
    this.note,
  });

  factory PDebt.fromData(Map<String, dynamic> d) => PDebt(
        person: (d['p'] ?? '').toString(),
        amount: _d(d['a']),
        currency: (d['c'] ?? '').toString(),
        owedToAuthor: d['o'] == true,
        date: _date(d['d']),
        paid: d['paid'] == true,
        note: d['note']?.toString(),
      );
}

/// Pago entre ustedes para saldar cuentas.
class PSettle {
  final double amount;
  final String currency;

  /// true = quien lo anotó le pagó a la otra persona.
  final bool paidByAuthor;
  final DateTime date;
  const PSettle({required this.amount, required this.currency, required this.paidByAuthor, required this.date});

  factory PSettle.fromData(Map<String, dynamic> d) => PSettle(
        amount: _d(d['a']),
        currency: (d['c'] ?? '').toString(),
        paidByAuthor: d['pp'] != false,
        date: _date(d['d']),
      );
}

/// Meta en común (la creó tu pareja).
class PGoal {
  final String id;
  final String name;
  final double target;
  final String currency;
  const PGoal({required this.id, required this.name, required this.target, required this.currency});

  factory PGoal.fromData(Map<String, dynamic> d) => PGoal(
        id: (d['i'] ?? '').toString(),
        name: (d['n'] ?? '').toString(),
        target: _d(d['t']),
        currency: (d['c'] ?? '').toString(),
      );
}

/// Aporte de tu pareja a una meta en común.
class PContrib {
  final String goalId;
  final double amount;
  final String currency;
  final DateTime date;
  const PContrib({required this.goalId, required this.amount, required this.currency, required this.date});

  factory PContrib.fromData(Map<String, dynamic> d) => PContrib(
        goalId: (d['g'] ?? '').toString(),
        amount: _d(d['a']),
        currency: (d['c'] ?? '').toString(),
        date: _date(d['d']),
      );
}

/// Meta en común lista para mostrar: suma lo que aportó cada quien (en la
/// moneda de la meta).
class GoalView {
  final String id;
  final String name;
  final double target;
  final String currency;
  final bool mine;
  final double myContributed;
  final double partnerContributed;

  const GoalView({
    required this.id,
    required this.name,
    required this.target,
    required this.currency,
    required this.mine,
    required this.myContributed,
    required this.partnerContributed,
  });

  double get total => myContributed + partnerContributed;
  double get progress => target <= 0 ? 0 : (total / target).clamp(0.0, 1.0).toDouble();
  bool get done => target > 0 && total >= target;
}

/// Todo lo que tu pareja comparte contigo (ya descifrado).
class PartnerData {
  final String? name;
  final String? currency;
  final List<PExpense> expenses;
  final List<PExpense> splits;
  final List<PIncome> incomes;
  final List<PVault> vaults;
  final List<PDebt> debts;
  final List<PSettle> settlements;
  final List<PGoal> goals;
  final List<PContrib> contribs;

  const PartnerData({
    this.name,
    this.currency,
    this.expenses = const [],
    this.splits = const [],
    this.incomes = const [],
    this.vaults = const [],
    this.debts = const [],
    this.settlements = const [],
    this.goals = const [],
    this.contribs = const [],
  });

  bool get hasAnything =>
      expenses.isNotEmpty ||
      splits.isNotEmpty ||
      incomes.isNotEmpty ||
      vaults.isNotEmpty ||
      debts.isNotEmpty ||
      goals.isNotEmpty;
}
