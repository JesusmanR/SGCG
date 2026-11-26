import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../data/app_database.dart';
import '../data/attachment_storage.dart';
import '../data/receipt_ocr_service.dart';
import '../data/report_export_service.dart';

String formatMoney(int cents) {
  final pesos = cents ~/ 100;
  final digits = pesos.toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final centavos = cents.abs() % 100;
  final suffix = centavos == 0 ? '' : ',${centavos.toString().padLeft(2, '0')}';
  return '\$ $grouped$suffix';
}

int? parseMoney(String input) {
  var value = input.trim().replaceAll(' ', '');
  if (value.isEmpty) return null;
  value = value.replaceAll('.', '').replaceAll(',', '.');
  final parsed = double.tryParse(value);
  if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
  return (parsed * 100).round();
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.database,
    required this.profile,
    required this.refreshToken,
    required this.onAdd,
  });
  final AppDatabase database;
  final AppProfile profile;
  final int refreshToken;
  final VoidCallback onAdd;

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      database.expensesFor(profile.id),
      database.categoriesFor(profile.id),
      database.incomesFor(profile.id),
    ]);
    return _DashboardData(
      results[0] as List<Expense>,
      results[1] as List<ExpenseCategory>,
      results[2] as List<IncomeRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      key: ValueKey(refreshToken),
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final now = DateTime.now();
        final monthExpenses = data.expenses
            .where(
              (expense) =>
                  expense.expenseDate.year == now.year &&
                  expense.expenseDate.month == now.month,
            )
            .toList();
        final total = monthExpenses.fold<int>(
          0,
          (sum, expense) => sum + expense.amountCents,
        );
        final monthIncomes = data.incomes
            .where(
              (income) =>
                  income.incomeDate.year == now.year &&
                  income.incomeDate.month == now.month,
            )
            .toList();
        final incomeTotal = monthIncomes.fold<int>(
          0,
          (sum, income) => sum + income.amountCents,
        );
        final lifetimeIncome = data.incomes.fold<int>(
          0,
          (sum, income) => sum + income.amountCents,
        );
        final lifetimeExpenses = data.expenses.fold<int>(
          0,
          (sum, expense) => sum + expense.amountCents,
        );
        final sums = <String, int>{};
        for (final expense in monthExpenses) {
          sums.update(
            expense.categoryId,
            (value) => value + expense.amountCents,
            ifAbsent: () => expense.amountCents,
          );
        }
        final categoryNames = {
          for (final category in data.categories) category.id: category.name,
        };
        final categoryColors = {
          for (final category in data.categories)
            category.id: Color(category.colorValue),
        };
        final leaders = sums.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxSpend = leaders.isEmpty ? 1 : leaders.first.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${profile.name}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Este es tu resumen de ${_monthName(now.month)}.',
                          style: const TextStyle(color: Color(0xFF69746E)),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo gasto'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 760;
                  final cards = [
                    _MetricCard(
                      title: 'Ingresos del mes',
                      value: formatMoney(incomeTotal),
                      icon: Icons.savings_outlined,
                      tint: const Color(0xFFE7F1EC),
                    ),
                    _MetricCard(
                      title: 'Gastos del mes',
                      value: formatMoney(total),
                      icon: Icons.receipt_long_outlined,
                      tint: const Color(0xFFEAF0F6),
                    ),
                    _MetricCard(
                      title: 'Saldo disponible',
                      value: formatMoney(lifetimeIncome - lifetimeExpenses),
                      icon: Icons.account_balance_wallet_outlined,
                      tint: const Color(0xFFF4EEE3),
                    ),
                  ];
                  return isWide
                      ? Row(
                          children: [
                            for (var i = 0; i < cards.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i == cards.length - 1 ? 0 : 14,
                                  ),
                                  child: cards[i],
                                ),
                              ),
                          ],
                        )
                      : Column(
                          children: [
                            for (final card in cards)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: card,
                              ),
                          ],
                        );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final categoriesCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gastos por categoría',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),
                          if (leaders.isEmpty)
                            const _EmptyHint(
                              icon: Icons.pie_chart_outline,
                              text: 'Registra gastos para ver aquí cómo se distribuyen.',
                            ),
                          for (final entry in leaders.take(6)) ...[
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color:
                                        categoryColors[entry.key] ??
                                        Colors.teal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    categoryNames[entry.key] ??
                                        'Otra categoría',
                                  ),
                                ),
                                Text(
                                  formatMoney(entry.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: entry.value / maxSpend,
                                minHeight: 7,
                                color: categoryColors[entry.key] ?? Colors.teal,
                                backgroundColor: const Color(0xFFEFF1EE),
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                        ],
                      ),
                    ),
                  );
                  final recentCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Gastos recientes',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Este mes'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (data.expenses.isEmpty)
                            const _EmptyHint(
                              icon: Icons.receipt_long_outlined,
                              text: 'Todavía no tienes gastos registrados.',
                            ),
                          for (final expense in data.expenses.take(5))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor:
                                    (categoryColors[expense.categoryId] ??
                                            Colors.teal)
                                        .withValues(alpha: .13),
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color:
                                      categoryColors[expense.categoryId] ??
                                      Colors.teal,
                                  size: 19,
                                ),
                              ),
                              title: Text(
                                expense.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${categoryNames[expense.categoryId] ?? 'Sin categoría'} · ${formatDate(expense.expenseDate)}',
                              ),
                              trailing: Text(
                                formatMoney(expense.amountCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  return constraints.maxWidth > 850
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: categoriesCard),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: recentCard),
                          ],
                        )
                      : Column(children: [categoriesCard, recentCard]);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardData {
  const _DashboardData(this.expenses, this.categories, this.incomes);
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final List<IncomeRecord> incomes;
}

String _monthName(int month) => const [
  '',
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
][month];

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF38675C)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF69746E))),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.database,
    required this.profile,
    required this.refreshToken,
    required this.onChanged,
    required this.onAdd,
  });
  final AppDatabase database;
  final AppProfile profile;
  final int refreshToken;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (value) =>
                      setState(() => query = value.toLowerCase().trim()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nombre',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo gasto'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: FutureBuilder<_ExpenseData>(
              key: ValueKey(widget.refreshToken),
              future: _load(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final categories = {
                  for (final category in data.categories)
                    category.id: category.name,
                };
                final items = data.expenses
                    .where(
                      (expense) =>
                          expense.name.toLowerCase().contains(query) ||
                          (expense.merchant?.toLowerCase().contains(query) ??
                              false),
                    )
                    .toList();
                if (items.isEmpty) {
                  return Card(
                    child: Center(
                      child: _EmptyHint(
                        icon: Icons.receipt_long_outlined,
                        text: query.isEmpty
                            ? 'Aún no hay gastos. Agrega el primero para comenzar.'
                            : 'No hay gastos que coincidan con la búsqueda.',
                      ),
                    ),
                  );
                }
                return Card(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text('FECHA', style: _tableHeaderStyle),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text('NOMBRE', style: _tableHeaderStyle),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'CATEGORÍA',
                                style: _tableHeaderStyle,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('MÉTODO', style: _tableHeaderStyle),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'VALOR',
                                textAlign: TextAlign.right,
                                style: _tableHeaderStyle,
                              ),
                            ),
                            SizedBox(width: 42),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                          ),
                          itemBuilder: (context, index) {
                            final expense = items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      formatDate(expense.expenseDate),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (expense.merchant?.isNotEmpty ==
                                            true)
                                          Text(
                                            expense.merchant!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF78817B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      categories[expense.categoryId] ??
                                          'Archivada',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(expense.paymentMethod ?? '—'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      formatMoney(expense.amountCents),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 82,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar gasto',
                                          onPressed: () =>
                                              _editExpense(expense),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Mover a papelera',
                                          onPressed: () async {
                                            await widget.database.moveToTrash(
                                              expense.id,
                                            );
                                            widget.onChanged();
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 19,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<_ExpenseData> _load() async => _ExpenseData(
    await widget.database.expensesFor(widget.profile.id),
    await widget.database.categoriesFor(widget.profile.id),
  );

  Future<void> _editExpense(Expense expense) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExpenseFormDialog(
        database: widget.database,
        profile: widget.profile,
        expense: expense,
      ),
    );
    if (saved == true) widget.onChanged();
  }
}

class _ExpenseData {
  const _ExpenseData(this.expenses, this.categories);
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
}

const _tableHeaderStyle = TextStyle(
  fontSize: 11,
  letterSpacing: .6,
  color: Color(0xFF7B847F),
  fontWeight: FontWeight.w700,
);

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({
    super.key,
    required this.database,
    required this.profile,
    required this.refreshToken,
    required this.onChanged,
  });
  final AppDatabase database;
  final AppProfile profile;
  final int refreshToken;
  final VoidCallback onChanged;

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _addIncome([IncomeRecord? income]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncomeFormDialog(
        database: widget.database,
        profile: widget.profile,
        income: income,
      ),
    );
    if (saved == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (value) =>
                      setState(() => query = value.toLowerCase().trim()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar ingresos',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _addIncome(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo ingreso'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<IncomeRecord>>(
              key: ValueKey(widget.refreshToken),
              future: widget.database.incomesFor(widget.profile.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final incomes = snapshot.data!
                    .where(
                      (income) =>
                          income.name.toLowerCase().contains(query) ||
                          (income.source?.toLowerCase().contains(query) ??
                              false),
                    )
                    .toList();
                if (incomes.isEmpty) {
                  return Card(
                    child: _EmptyHint(
                      icon: Icons.savings_outlined,
                      text: query.isEmpty
                          ? 'Aún no hay ingresos. Registra uno para calcular tu saldo.'
                          : 'No hay ingresos que coincidan con la búsqueda.',
                    ),
                  );
                }
                final total = incomes.fold<int>(
                  0,
                  (sum, income) => sum + income.amountCents,
                );
                return Column(
                  children: [
                    _MetricCard(
                      title: 'Ingresos registrados',
                      value: formatMoney(total),
                      icon: Icons.savings_outlined,
                      tint: const Color(0xFFE7F1EC),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Card(
                        child: ListView.separated(
                          itemCount: incomes.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                          ),
                          itemBuilder: (context, index) {
                            final income = incomes[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE7F1EC),
                                child: Icon(
                                  Icons.savings_outlined,
                                  color: Color(0xFF38675C),
                                ),
                              ),
                              title: Text(income.name),
                              subtitle: Text(
                                '${formatDate(income.incomeDate)}${income.source?.isNotEmpty == true ? ' · ${income.source}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatMoney(income.amountCents),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar ingreso',
                                    onPressed: () => _addIncome(income),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 19,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Mover a papelera',
                                    onPressed: () async {
                                      await widget.database.moveIncomeToTrash(
                                        income.id,
                                      );
                                      widget.onChanged();
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 19,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class IncomeFormDialog extends StatefulWidget {
  const IncomeFormDialog({
    super.key,
    required this.database,
    required this.profile,
    this.income,
  });
  final AppDatabase database;
  final AppProfile profile;
  final IncomeRecord? income;

  @override
  State<IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<IncomeFormDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  final sourceController = TextEditingController();
  final notesController = TextEditingController();
  DateTime incomeDate = DateTime.now();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final income = widget.income;
    if (income != null) {
      nameController.text = income.name;
      amountController.text = (income.amountCents / 100)
          .toStringAsFixed(income.amountCents % 100 == 0 ? 0 : 2)
          .replaceAll('.', ',');
      sourceController.text = income.source ?? '';
      notesController.text = income.notes ?? '';
      incomeDate = income.incomeDate;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    sourceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final values = {
      'name': nameController.text,
      'amount': parseMoney(amountController.text)!,
      'date': DateTime(incomeDate.year, incomeDate.month, incomeDate.day),
      'source': sourceController.text.trim().isEmpty
          ? null
          : sourceController.text.trim(),
      'notes': notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    };
    final existing = widget.income;
    if (existing == null) {
      await widget.database.addIncome(
        profileId: widget.profile.id,
        name: values['name'] as String,
        amountCents: values['amount'] as int,
        incomeDate: values['date'] as DateTime,
        source: values['source'] as String?,
        notes: values['notes'] as String?,
      );
    } else {
      await widget.database.updateIncome(
        id: existing.id,
        name: values['name'] as String,
        amountCents: values['amount'] as int,
        incomeDate: values['date'] as DateTime,
        source: values['source'] as String?,
        notes: values['notes'] as String?,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.income == null ? 'Nuevo ingreso' : 'Editar ingreso'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej. Salario de noviembre',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe un nombre.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor *',
                    prefixText: 'COP  ',
                    hintText: '2.500.000',
                  ),
                  validator: (value) => parseMoney(value ?? '') == null
                      ? 'Escribe un valor mayor que cero.'
                      : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: incomeDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      locale: const Locale('es', 'CO'),
                    );
                    if (selected != null) setState(() => incomeDate = selected);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha *',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(formatDate(incomeDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Origen',
                    hintText: 'Salario, venta, devolución…',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.income == null ? 'Guardar ingreso' : 'Guardar cambios',
                ),
        ),
      ],
    );
  }
}

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({
    super.key,
    required this.database,
    required this.profile,
    this.expense,
  });
  final AppDatabase database;
  final AppProfile profile;
  final Expense? expense;

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  final merchantController = TextEditingController();
  final noteController = TextEditingController();
  final paymentController = TextEditingController();
  late Future<List<ExpenseCategory>> categoriesFuture;
  late Future<List<ExpenseAttachment>> attachmentsFuture;
  final attachmentStorage = AttachmentStorage();
  static const ocrService = ReceiptOcrService();
  XFile? pendingAttachment;
  String? categoryId;
  DateTime expenseDate = DateTime.now();
  bool saving = false;
  bool analyzingReceipt = false;
  String? ocrNotice;
  double? ocrConfidence;

  @override
  void initState() {
    super.initState();
    categoriesFuture = widget.database.categoriesFor(widget.profile.id);
    attachmentsFuture = widget.expense == null
        ? Future.value(const <ExpenseAttachment>[])
        : widget.database.attachmentsForExpense(widget.expense!.id);
    final expense = widget.expense;
    if (expense != null) {
      nameController.text = expense.name;
      amountController.text = (expense.amountCents / 100)
          .toStringAsFixed(expense.amountCents % 100 == 0 ? 0 : 2)
          .replaceAll('.', ',');
      merchantController.text = expense.merchant ?? '';
      noteController.text = expense.notes ?? '';
      paymentController.text = expense.paymentMethod ?? '';
      categoryId = expense.categoryId;
      expenseDate = expense.expenseDate;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    merchantController.dispose();
    noteController.dispose();
    paymentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final amount = parseMoney(amountController.text)!;
    if (categoryId == null) return;
    setState(() => saving = true);
    final values = {
      'name': nameController.text,
      'amountCents': amount,
      'expenseDate': DateTime(
        expenseDate.year,
        expenseDate.month,
        expenseDate.day,
      ),
      'categoryId': categoryId!,
      'paymentMethod': paymentController.text.trim().isEmpty
          ? null
          : paymentController.text.trim(),
      'merchant': merchantController.text.trim().isEmpty
          ? null
          : merchantController.text.trim(),
      'notes': noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    };
    final existing = widget.expense;
    late final int expenseId;
    if (existing == null) {
      expenseId = await widget.database.addExpense(
        profileId: widget.profile.id,
        name: values['name'] as String,
        amountCents: values['amountCents'] as int,
        expenseDate: values['expenseDate'] as DateTime,
        categoryId: values['categoryId'] as String,
        paymentMethod: values['paymentMethod'] as String?,
        merchant: values['merchant'] as String?,
        notes: values['notes'] as String?,
      );
    } else {
      expenseId = existing.id;
      await widget.database.updateExpense(
        id: existing.id,
        name: values['name'] as String,
        amountCents: values['amountCents'] as int,
        expenseDate: values['expenseDate'] as DateTime,
        categoryId: values['categoryId'] as String,
        paymentMethod: values['paymentMethod'] as String?,
        merchant: values['merchant'] as String?,
        notes: values['notes'] as String?,
      );
    }
    final selectedAttachment = pendingAttachment;
    if (selectedAttachment != null) {
      final stored = await attachmentStorage.save(selectedAttachment);
      await widget.database.addAttachment(
        expenseId: expenseId,
        originalName: stored.originalName,
        relativePath: stored.relativePath,
        extension: stored.extension,
        sizeBytes: stored.sizeBytes,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickAttachment() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Recibos y documentos',
          extensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx'],
        ),
      ],
    );
    if (file == null) return;
    final size = await file.length();
    if (size > 15 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo supera el límite de 15 MB.'),
          ),
        );
      }
      return;
    }
    setState(() => pendingAttachment = file);
  }

  Future<void> _analyzeReceipt() async {
    final file = pendingAttachment;
    if (file == null) return;
    if (!ocrService.isConfigured) {
      setState(() {
        ocrNotice = 'El servicio OCR todavía no está configurado. Puedes completar el gasto manualmente.';
      });
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leer comprobante'),
        content: const Text(
          'Para sugerir el comercio, el valor y la fecha, se enviará este archivo por internet a Google Document AI. Google indica que las solicitudes inmediatas se procesan en memoria y no se guardan en disco. El procesamiento puede generar costos. Revisa y corrige los datos antes de guardar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar y leer'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      analyzingReceipt = true;
      ocrNotice = null;
    });
    try {
      final suggestion = await ocrService.analyze(file);
      if (!mounted) return;
      if (suggestion.merchant != null) {
        merchantController.text = suggestion.merchant!;
        if (nameController.text.trim().isEmpty) {
          nameController.text = 'Gasto en ${suggestion.merchant}';
        }
      }
      final isCop =
          suggestion.currency == null ||
          suggestion.currency!.toUpperCase() == 'COP';
      if (suggestion.amountCents != null && isCop) {
        final amount = suggestion.amountCents!;
        amountController.text = (amount / 100)
            .toStringAsFixed(amount % 100 == 0 ? 0 : 2)
            .replaceAll('.', ',');
      }
      if (suggestion.date != null) {
        expenseDate = DateTime(
          suggestion.date!.year,
          suggestion.date!.month,
          suggestion.date!.day,
        );
      }
      setState(() {
        ocrConfidence = suggestion.confidence;
        ocrNotice = suggestion.currency != null && !isCop
            ? 'Se detectó ${suggestion.currency}; revisa el valor y conviértelo a COP.'
            : 'Lectura lista. Verifica los datos antes de guardar.';
      });
    } on ReceiptOcrException catch (error) {
      if (mounted) setState(() => ocrNotice = error.message);
    } finally {
      if (mounted) setState(() => analyzingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'Nuevo gasto' : 'Editar gasto'),
      content: SizedBox(
        width: 550,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej. Compra semanal',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe un nombre.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor *',
                    prefixText: 'COP  ',
                    hintText: '25.000',
                  ),
                  validator: (value) => parseMoney(value ?? '') == null
                      ? 'Escribe un valor mayor que cero.'
                      : null,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<ExpenseCategory>>(
                  future: categoriesFuture,
                  builder: (context, snapshot) {
                    final categories =
                        snapshot.data ?? const <ExpenseCategory>[];
                    return DropdownButtonFormField<String>(
                      value: categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoría *',
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: snapshot.hasData
                          ? (value) => setState(() => categoryId = value)
                          : null,
                      validator: (value) =>
                          value == null ? 'Elige una categoría.' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: expenseDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      locale: const Locale('es', 'CO'),
                    );
                    if (selected != null)
                      setState(() => expenseDate = selected);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha *',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(formatDate(expenseDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: paymentController,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    hintText: 'Efectivo, débito, crédito…',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Comercio o beneficiario',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickAttachment,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Adjuntar archivo'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pendingAttachment?.name ??
                            'JPG, PNG, PDF o DOCX · hasta 15 MB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (pendingAttachment != null &&
                    const ['jpg', 'jpeg', 'png', 'pdf'].contains(
                      pendingAttachment!.name.split('.').last.toLowerCase(),
                    )) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: analyzingReceipt ? null : _analyzeReceipt,
                      icon: analyzingReceipt
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner_outlined),
                      label: Text(
                        analyzingReceipt
                            ? 'Leyendo comprobante…'
                            : 'Leer datos',
                      ),
                    ),
                  ),
                ],
                if (ocrNotice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ocrConfidence == null
                            ? ocrNotice!
                            : '$ocrNotice (confianza ${(ocrConfidence! * 100).round()} %)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                if (widget.expense != null)
                  FutureBuilder<List<ExpenseAttachment>>(
                    future: attachmentsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          for (final attachment in snapshot.data!)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.insert_drive_file_outlined,
                              ),
                              title: Text(
                                attachment.originalName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${(attachment.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.expense == null ? 'Guardar gasto' : 'Guardar cambios',
                ),
        ),
      ],
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.database,
    required this.profile,
    required this.refreshToken,
    required this.onChanged,
  });
  final AppDatabase database;
  final AppProfile profile;
  final int refreshToken;
  final VoidCallback onChanged;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await widget.database.createCategory(widget.profile.id, name);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: FutureBuilder<List<ExpenseCategory>>(
      key: ValueKey(widget.refreshToken),
      future: widget.database.allCategoriesFor(widget.profile.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final categories = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Organiza tus gastos con categorías propias.'),
                ),
                FilledButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva categoría'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 18, endIndent: 18),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(category.colorValue)
                            .withValues(alpha: .14),
                        child: Icon(
                          Icons.sell_outlined,
                          color: Color(category.colorValue),
                          size: 19,
                        ),
                      ),
                      title: Text(category.name),
                      subtitle: Text(
                        category.archived ? 'Archivada' : 'Activa',
                      ),
                      trailing: Switch(
                        value: !category.archived,
                        onChanged: (active) async {
                          await widget.database.archiveCategory(
                            category.id,
                            !active,
                          );
                          widget.onChanged();
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class TrashScreen extends StatelessWidget {
  const TrashScreen({
    super.key,
    required this.database,
    required this.profile,
    required this.refreshToken,
    required this.onChanged,
  });
  final AppDatabase database;
  final AppProfile profile;
  final int refreshToken;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: FutureBuilder<_TrashData>(
      key: ValueKey(refreshToken),
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data.expenses.isEmpty && data.incomes.isEmpty)
          return const Card(
            child: _EmptyHint(
              icon: Icons.delete_outline,
              text: 'La papelera está vacía.',
            ),
          );
        return Card(
          child: ListView(
            children: [
              if (data.incomes.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Text('INGRESOS', style: _tableHeaderStyle),
                ),
                for (final income in data.incomes)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.savings_outlined),
                    ),
                    title: Text(income.name),
                    subtitle: Text(
                      '${formatDate(income.incomeDate)} · ${formatMoney(income.amountCents)}',
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await database.restoreIncome(income.id);
                            onChanged();
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('Restaurar'),
                        ),
                        IconButton(
                          tooltip: 'Eliminar definitivamente',
                          onPressed: () async {
                            if (await _confirmPermanentDelete(
                              context,
                              income.name,
                            )) {
                              await database.permanentlyDeleteIncome(income.id);
                              onChanged();
                            }
                          },
                          icon: const Icon(Icons.delete_forever_outlined),
                        ),
                      ],
                    ),
                  ),
              ],
              if (data.expenses.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Text('GASTOS', style: _tableHeaderStyle),
                ),
                for (final expense in data.expenses)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(expense.name),
                    subtitle: Text(
                      '${formatDate(expense.expenseDate)} · ${formatMoney(expense.amountCents)}',
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await database.restoreExpense(expense.id);
                            onChanged();
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('Restaurar'),
                        ),
                        IconButton(
                          tooltip: 'Eliminar definitivamente',
                          onPressed: () async {
                            if (await _confirmPermanentDelete(
                              context,
                              expense.name,
                            )) {
                              final storage = AttachmentStorage();
                              final attachments = await database
                                  .attachmentsForExpense(expense.id);
                              for (final attachment in attachments) {
                                await storage.delete(attachment.relativePath);
                              }
                              await database.permanentlyDeleteExpense(
                                expense.id,
                              );
                              onChanged();
                            }
                          },
                          icon: const Icon(Icons.delete_forever_outlined),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Future<_TrashData> _load() async => _TrashData(
    await database.expensesFor(profile.id, inTrash: true),
    await database.incomesFor(profile.id, inTrash: true),
  );
}

class _TrashData {
  const _TrashData(this.expenses, this.incomes);
  final List<Expense> expenses;
  final List<IncomeRecord> incomes;
}

Future<bool> _confirmPermanentDelete(BuildContext context, String name) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar definitivamente'),
          content: Text('“$name” no se podrá recuperar después de eliminarlo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ??
      false;
}

enum _ReportPeriod { day, week, month, year, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.database,
    required this.profile,
  });
  final AppDatabase database;
  final AppProfile profile;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportPeriod period = _ReportPeriod.month;
  DateTime selectedDate = DateTime.now();
  DateTimeRange? customRange;
  String? categoryFilter;
  String? paymentFilter;
  final exporter = ReportExportService();

  ({DateTime start, DateTime end}) get range {
    final date = selectedDate;
    switch (period) {
      case _ReportPeriod.day:
        final start = DateTime(date.year, date.month, date.day);
        return (start: start, end: start.add(const Duration(days: 1)));
      case _ReportPeriod.week:
        final day = DateTime(date.year, date.month, date.day);
        final start = day.subtract(Duration(days: day.weekday - 1));
        return (start: start, end: start.add(const Duration(days: 7)));
      case _ReportPeriod.month:
        final start = DateTime(date.year, date.month);
        return (start: start, end: DateTime(date.year, date.month + 1));
      case _ReportPeriod.year:
        final start = DateTime(date.year);
        return (start: start, end: DateTime(date.year + 1));
      case _ReportPeriod.custom:
        final selected = customRange;
        if (selected == null) {
          final start = DateTime(date.year, date.month, 1);
          return (start: start, end: DateTime(date.year, date.month + 1));
        }
        final start = DateTime(
          selected.start.year,
          selected.start.month,
          selected.start.day,
        );
        final end = DateTime(
          selected.end.year,
          selected.end.month,
          selected.end.day,
        ).add(const Duration(days: 1));
        return (start: start, end: end);
    }
  }

  String get rangeLabel {
    final current = range;
    final endInclusive = current.end.subtract(const Duration(days: 1));
    return '${formatDate(current.start)} – ${formatDate(endInclusive)}';
  }

  Future<void> _chooseDate() async {
    if (period == _ReportPeriod.custom) {
      final chosen = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: customRange,
        locale: const Locale('es', 'CO'),
      );
      if (chosen != null) setState(() => customRange = chosen);
    } else {
      final chosen = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        locale: const Locale('es', 'CO'),
      );
      if (chosen != null) setState(() => selectedDate = chosen);
    }
  }

  Future<_ReportData> _load() async {
    final currentRange = range;
    final values = await Future.wait([
      widget.database.expensesFor(widget.profile.id),
      widget.database.incomesFor(widget.profile.id),
      widget.database.allCategoriesFor(widget.profile.id),
    ]);
    final expenses = values[0] as List<Expense>;
    final incomes = (values[1] as List<IncomeRecord>).where((income) {
      return !income.incomeDate.isBefore(currentRange.start) &&
          income.incomeDate.isBefore(currentRange.end);
    }).toList();
    final categories = values[2] as List<ExpenseCategory>;
    final filtered = expenses.where((expense) {
      final inRange =
          !expense.expenseDate.isBefore(currentRange.start) &&
          expense.expenseDate.isBefore(currentRange.end);
      final matchesCategory =
          categoryFilter == null || expense.categoryId == categoryFilter;
      final matchesPayment =
          paymentFilter == null || expense.paymentMethod == paymentFilter;
      return inRange && matchesCategory && matchesPayment;
    }).toList();
    return _ReportData(
      filtered,
      incomes,
      categories,
      currentRange.start,
      currentRange.end,
    );
  }

  Future<void> _export(
    String format,
    _ReportData data,
    Map<String, String> names,
  ) async {
    final endInclusive = data.end.subtract(const Duration(days: 1));
    try {
      final path = switch (format) {
        'PDF' => await exporter.exportPdf(
          expenses: data.expenses,
          incomes: data.incomes,
          categories: names,
          start: data.start,
          end: endInclusive,
          totalCents: data.totalCents,
          incomeCents: data.incomeCents,
        ),
        'CSV' => await exporter.exportCsv(
          expenses: data.expenses,
          incomes: data.incomes,
          categories: names,
          start: data.start,
          end: endInclusive,
          totalCents: data.totalCents,
          incomeCents: data.incomeCents,
        ),
        _ => await exporter.exportExcel(
          expenses: data.expenses,
          incomes: data.incomes,
          categories: names,
          start: data.start,
          end: endInclusive,
          totalCents: data.totalCents,
          incomeCents: data.incomeCents,
        ),
      };
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Informe guardado en $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el informe: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: FutureBuilder<_ReportData>(
        key: ValueKey(
          '$period-${selectedDate.toIso8601String()}-${customRange?.start}-${customRange?.end}-$categoryFilter-$paymentFilter',
        ),
        future: _load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          final names = {
            for (final category in data.categories) category.id: category.name,
          };
          final payments =
              data.expenses
                  .map((e) => e.paymentMethod)
                  .whereType<String>()
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final sums = <String, int>{};
          for (final expense in data.expenses) {
            sums.update(
              expense.categoryId,
              (value) => value + expense.amountCents,
              ifAbsent: () => expense.amountCents,
            );
          }
          final byCategory = sums.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final item in _ReportPeriod.values)
                    ChoiceChip(
                      label: Text(switch (item) {
                        _ReportPeriod.day => 'Diario',
                        _ReportPeriod.week => 'Semanal',
                        _ReportPeriod.month => 'Mensual',
                        _ReportPeriod.year => 'Anual',
                        _ReportPeriod.custom => 'Personalizado',
                      }),
                      selected: period == item,
                      onSelected: (_) async {
                        setState(() => period = item);
                        if (item == _ReportPeriod.custom) await _chooseDate();
                      },
                    ),
                  OutlinedButton.icon(
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(rangeLabel),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      value: categoryFilter,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todas'),
                        ),
                        ...data.categories
                            .where((c) => !c.archived)
                            .map(
                              (c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                      ],
                      onChanged: (value) =>
                          setState(() => categoryFilter = value),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      value: paymentFilter,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos'),
                        ),
                        ...payments.map(
                          (value) => DropdownMenuItem<String?>(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => paymentFilter = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 245,
                    child: _MetricCard(
                      title: 'Ingresos del periodo',
                      value: formatMoney(data.incomeCents),
                      icon: Icons.savings_outlined,
                      tint: const Color(0xFFE7F1EC),
                    ),
                  ),
                  SizedBox(
                    width: 245,
                    child: _MetricCard(
                      title: 'Gastos del periodo',
                      value: formatMoney(data.totalCents),
                      icon: Icons.receipt_long_outlined,
                      tint: const Color(0xFFEAF0F6),
                    ),
                  ),
                  SizedBox(
                    width: 245,
                    child: _MetricCard(
                      title: 'Saldo neto del periodo',
                      value: formatMoney(data.incomeCents - data.totalCents),
                      icon: Icons.account_balance_wallet_outlined,
                      tint: const Color(0xFFF4EEE3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Exportar:'),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _export('PDF', data, names),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _export('CSV', data, names),
                    icon: const Icon(Icons.table_rows_outlined),
                    label: const Text('CSV'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _export('Excel', data, names),
                    icon: const Icon(Icons.grid_on),
                    label: const Text('Excel'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: data.expenses.isEmpty && data.incomes.isEmpty
                    ? const Card(
                        child: _EmptyHint(
                          icon: Icons.bar_chart_rounded,
                          text: 'No hay gastos en este periodo con los filtros seleccionados.',
                        ),
                      )
                    : Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Detalle del informe · $rangeLabel',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    'Por categoría: ${byCategory.map((e) => '${names[e.key] ?? 'Otra'} ${formatMoney(e.value)}').join('  ·  ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView(
                                children: [
                                  if (data.incomes.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                        12,
                                        20,
                                        4,
                                      ),
                                      child: Text(
                                        'INGRESOS',
                                        style: _tableHeaderStyle,
                                      ),
                                    ),
                                    for (final income in data.incomes)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.savings_outlined,
                                          color: Color(0xFF38675C),
                                        ),
                                        title: Text(income.name),
                                        subtitle: Text(
                                          '${formatDate(income.incomeDate)} · ${income.source ?? 'Ingreso'}',
                                        ),
                                        trailing: Text(
                                          formatMoney(income.amountCents),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                  if (data.expenses.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                        12,
                                        20,
                                        4,
                                      ),
                                      child: Text(
                                        'GASTOS',
                                        style: _tableHeaderStyle,
                                      ),
                                    ),
                                    for (final expense in data.expenses)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.receipt_long_outlined,
                                        ),
                                        title: Text(expense.name),
                                        subtitle: Text(
                                          '${formatDate(expense.expenseDate)} · ${names[expense.categoryId] ?? 'Archivada'} · ${expense.paymentMethod ?? 'Sin método'}',
                                        ),
                                        trailing: Text(
                                          formatMoney(expense.amountCents),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportData {
  const _ReportData(
    this.expenses,
    this.incomes,
    this.categories,
    this.start,
    this.end,
  );
  final List<Expense> expenses;
  final List<IncomeRecord> incomes;
  final List<ExpenseCategory> categories;
  final DateTime start;
  final DateTime end;
  int get totalCents =>
      expenses.fold<int>(0, (sum, expense) => sum + expense.amountCents);
  int get incomeCents =>
      incomes.fold<int>(0, (sum, income) => sum + income.amountCents);
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: const Color(0xFF87928B)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF69746E)),
          ),
        ],
      ),
    ),
  );
}
