import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('AppProfile')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 48)();
  TextColumn get passwordSalt => text()();
  TextColumn get passwordHash => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExpenseCategory')
class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 48)();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF658576))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get amountCents => integer()();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get categoryId => text().references(ExpenseCategories, #id)();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get inTrash => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [];
}

class ExpenseAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get expenseId =>
      integer().references(Expenses, #id, onDelete: KeyAction.cascade)();
  TextColumn get originalName => text().withLength(min: 1, max: 255)();
  TextColumn get relativePath => text()();
  TextColumn get extension => text()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('IncomeRecord')
class Incomes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get amountCents => integer()();
  DateTimeColumn get incomeDate => dateTime()();
  TextColumn get source => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get inTrash => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
  tables: [Profiles, ExpenseCategories, Expenses, ExpenseAttachments, Incomes],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'control_gastos'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(expenseAttachments);
      if (from < 3) await m.createTable(incomes);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<List<AppProfile>> allProfiles() => select(profiles).get();

  Future<AppProfile?> profileByName(String name) {
    return (select(profiles)
          ..where((p) => p.name.lower().equals(name.trim().toLowerCase())))
        .getSingleOrNull();
  }

  Future<AppProfile> createProfile(String name, String password) async {
    if (await profileByName(name) != null) {
      throw StateError('Ya existe un perfil con ese nombre.');
    }
    final id = _newId();
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await _hashPassword(password, salt);
    await into(profiles).insert(
      ProfilesCompanion.insert(
        id: id,
        name: name.trim(),
        passwordSalt: base64Encode(salt),
        passwordHash: base64Encode(hash),
      ),
    );

    const defaults = <(String, int)>[
      ('Servicios', 0xFF4A7C75),
      ('Compras', 0xFF638E6B),
      ('Restaurantes', 0xFFC27A55),
      ('Transporte', 0xFF55799B),
      ('Salud', 0xFF8B7198),
      ('Vivienda', 0xFFAF8D52),
      ('Entretenimiento', 0xFFB76572),
      ('Educación', 0xFF6F849E),
      ('Otros', 0xFF7C827D),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final item = defaults[i];
      await into(expenseCategories).insert(
        ExpenseCategoriesCompanion.insert(
          id: _newId(),
          profileId: id,
          name: item.$1,
          colorValue: Value(item.$2),
          sortOrder: Value(i),
        ),
      );
    }
    return (select(profiles)..where((p) => p.id.equals(id))).getSingle();
  }

  Future<bool> authenticate(String name, String password) async {
    final profile = await profileByName(name);
    if (profile == null) return false;
    final salt = base64Decode(profile.passwordSalt);
    final actual = await _hashPassword(password, salt);
    return _constantTimeEquals(actual, base64Decode(profile.passwordHash));
  }

  Future<List<ExpenseCategory>> categoriesFor(String profileId) {
    return (select(expenseCategories)
          ..where(
            (c) => c.profileId.equals(profileId) & c.archived.equals(false),
          )
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  Future<List<ExpenseCategory>> allCategoriesFor(String profileId) {
    return (select(expenseCategories)
          ..where((c) => c.profileId.equals(profileId))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  Future<void> createCategory(String profileId, String name) async {
    final existing = await allCategoriesFor(profileId);
    await into(expenseCategories).insert(
      ExpenseCategoriesCompanion.insert(
        id: _newId(),
        profileId: profileId,
        name: name.trim(),
        sortOrder: Value(existing.length),
      ),
    );
  }

  Future<void> archiveCategory(String id, bool archived) async {
    await (update(expenseCategories)..where((c) => c.id.equals(id))).write(
      ExpenseCategoriesCompanion(archived: Value(archived)),
    );
  }

  Future<List<Expense>> expensesFor(String profileId, {bool inTrash = false}) {
    return (select(expenses)
          ..where(
            (e) => e.profileId.equals(profileId) & e.inTrash.equals(inTrash),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]))
        .get();
  }

  Future<int> addExpense({
    required String profileId,
    required String name,
    required int amountCents,
    required DateTime expenseDate,
    required String categoryId,
    String? paymentMethod,
    String? merchant,
    String? notes,
  }) {
    return into(expenses).insert(
      ExpensesCompanion.insert(
        profileId: profileId,
        name: name.trim(),
        amountCents: amountCents,
        expenseDate: expenseDate,
        categoryId: categoryId,
        paymentMethod: Value(paymentMethod),
        merchant: Value(merchant),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateExpense({
    required int id,
    required String name,
    required int amountCents,
    required DateTime expenseDate,
    required String categoryId,
    String? paymentMethod,
    String? merchant,
    String? notes,
  }) async {
    await (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        name: Value(name.trim()),
        amountCents: Value(amountCents),
        expenseDate: Value(expenseDate),
        categoryId: Value(categoryId),
        paymentMethod: Value(paymentMethod),
        merchant: Value(merchant),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> moveToTrash(int id) async {
    await (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        inTrash: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreExpense(int id) async {
    await (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        inTrash: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> permanentlyDeleteExpense(int id) async {
    await (delete(expenses)..where((e) => e.id.equals(id))).go();
  }

  Future<List<ExpenseAttachment>> attachmentsForExpense(int expenseId) {
    return (select(
      expenseAttachments,
    )..where((attachment) => attachment.expenseId.equals(expenseId))).get();
  }

  Future<int> addAttachment({
    required int expenseId,
    required String originalName,
    required String relativePath,
    required String extension,
    required int sizeBytes,
  }) {
    return into(expenseAttachments).insert(
      ExpenseAttachmentsCompanion.insert(
        expenseId: expenseId,
        originalName: originalName,
        relativePath: relativePath,
        extension: extension,
        sizeBytes: sizeBytes,
      ),
    );
  }

  Future<void> deleteAttachment(int id) async {
    await (delete(expenseAttachments)..where((a) => a.id.equals(id))).go();
  }

  Future<List<IncomeRecord>> incomesFor(
    String profileId, {
    bool inTrash = false,
  }) {
    return (select(incomes)
          ..where(
            (income) =>
                income.profileId.equals(profileId) &
                income.inTrash.equals(inTrash),
          )
          ..orderBy([(income) => OrderingTerm.desc(income.incomeDate)]))
        .get();
  }

  Future<int> addIncome({
    required String profileId,
    required String name,
    required int amountCents,
    required DateTime incomeDate,
    String? source,
    String? notes,
  }) {
    return into(incomes).insert(
      IncomesCompanion.insert(
        profileId: profileId,
        name: name.trim(),
        amountCents: amountCents,
        incomeDate: incomeDate,
        source: Value(source),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateIncome({
    required int id,
    required String name,
    required int amountCents,
    required DateTime incomeDate,
    String? source,
    String? notes,
  }) async {
    await (update(incomes)..where((income) => income.id.equals(id))).write(
      IncomesCompanion(
        name: Value(name.trim()),
        amountCents: Value(amountCents),
        incomeDate: Value(incomeDate),
        source: Value(source),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> moveIncomeToTrash(int id) async {
    await (update(incomes)..where((income) => income.id.equals(id))).write(
      IncomesCompanion(
        inTrash: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreIncome(int id) async {
    await (update(incomes)..where((income) => income.id.equals(id))).write(
      IncomesCompanion(
        inTrash: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> permanentlyDeleteIncome(int id) async {
    await (delete(incomes)..where((income) => income.id.equals(id))).go();
  }

  Future<Map<String, dynamic>> rowsForBackup() async {
    final values = await Future.wait([
      select(profiles).get(),
      select(expenseCategories).get(),
      select(expenses).get(),
      select(incomes).get(),
      select(expenseAttachments).get(),
    ]);
    return {
      'profiles': (values[0] as List<AppProfile>)
          .map((row) => row.toJson())
          .toList(),
      'categories': (values[1] as List<ExpenseCategory>)
          .map((row) => row.toJson())
          .toList(),
      'expenses': (values[2] as List<Expense>)
          .map((row) => row.toJson())
          .toList(),
      'incomes': (values[3] as List<IncomeRecord>)
          .map((row) => row.toJson())
          .toList(),
      'attachments': (values[4] as List<ExpenseAttachment>)
          .map((row) => row.toJson())
          .toList(),
    };
  }

  Future<void> replaceFromBackup(Map<String, dynamic> tables) async {
    List<Map<String, dynamic>> rows(String key) {
      final value = tables[key];
      if (value is! List) throw FormatException('Tabla inválida: $key');
      return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    }

    final restoredProfiles = rows('profiles').map(AppProfile.fromJson).toList();
    final restoredCategories = rows('categories')
        .map(ExpenseCategory.fromJson)
        .toList();
    final restoredExpenses = rows('expenses').map(Expense.fromJson).toList();
    final restoredIncomes = rows('incomes').map(IncomeRecord.fromJson).toList();
    final restoredAttachments = rows('attachments')
        .map(ExpenseAttachment.fromJson)
        .toList();
    if (restoredProfiles.isEmpty) {
      throw const FormatException('El respaldo no contiene perfiles.');
    }

    await transaction(() async {
      await delete(expenseAttachments).go();
      await delete(expenses).go();
      await delete(incomes).go();
      await delete(expenseCategories).go();
      await delete(profiles).go();
      await batch((batch) {
        batch.insertAll(profiles, restoredProfiles);
        batch.insertAll(expenseCategories, restoredCategories);
        batch.insertAll(expenses, restoredExpenses);
        batch.insertAll(incomes, restoredIncomes);
        batch.insertAll(expenseAttachments, restoredAttachments);
      });
    });
  }

  Future<void> closeDatabase() => close();
}

Future<List<int>> _hashPassword(String password, List<int> salt) async {
  final algorithm = Argon2id(
    parallelism: 1,
    memory: 19 * 1024,
    iterations: 2,
    hashLength: 32,
  );
  final result = await algorithm.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );
  return result.extractBytes();
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

String _newId() {
  final random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
}
