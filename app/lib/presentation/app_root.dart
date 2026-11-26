import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'backup_screen.dart';
import 'screens.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.database});
  final AppDatabase database;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  AppProfile? activeProfile;

  @override
  Widget build(BuildContext context) {
    final profile = activeProfile;
    if (profile == null) {
      return ProfileGate(
        database: widget.database,
        onAuthenticated: (value) => setState(() => activeProfile = value),
      );
    }
    return HomeShell(
      database: widget.database,
      profile: profile,
      onSignOut: () => setState(() => activeProfile = null),
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.database,
    required this.onAuthenticated,
  });
  final AppDatabase database;
  final ValueChanged<AppProfile> onAuthenticated;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      busy = true;
      error = null;
    });
    final valid = await widget.database.authenticate(
      nameController.text,
      passwordController.text,
    );
    if (!mounted) return;
    if (!valid) {
      setState(() {
        busy = false;
        error = 'Revisa el nombre y la clave e inténtalo de nuevo.';
      });
      return;
    }
    final profile = await widget.database.profileByName(nameController.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (profile != null) widget.onAuthenticated(profile);
  }

  Future<void> _createProfile() async {
    final name = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final created = await showDialog<AppProfile>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear perfil local'),
        content: SizedBox(
          width: 390,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  maxLength: 48,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Escribe un nombre para el perfil.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Clave local'),
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Usa al menos 6 caracteres.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar clave',
                  ),
                  validator: (value) => value != password.text
                      ? 'Las claves no coinciden.'
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'La clave identifica este perfil en este equipo. No se puede recuperar por internet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final profile = await widget.database.createProfile(
                  name.text,
                  password.text,
                );
                if (dialogContext.mounted)
                  Navigator.pop(dialogContext, profile);
              } catch (_) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se pudo crear el perfil. Revisa si el nombre ya existe.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Crear perfil'),
          ),
        ],
      ),
    );
    name.dispose();
    password.dispose();
    confirmation.dispose();
    if (created != null && mounted) widget.onAuthenticated(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(34),
              child: FutureBuilder<List<AppProfile>>(
                future: widget.database.allProfiles(),
                builder: (context, snapshot) {
                  final hasProfiles = snapshot.data?.isNotEmpty ?? false;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 42,
                        color: Color(0xFF38675C),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Control de gastos',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasProfiles
                            ? 'Inicia sesión en tu perfil local'
                            : 'Crea tu primer perfil para comenzar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: const Color(0xFF69746E)),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del perfil',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onSubmitted: (_) => _signIn(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Clave local',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _signIn(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: busy ? null : _signIn,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Iniciar sesión'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _createProfile,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          hasProfiles ? 'Crear otro perfil' : 'Crear perfil',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.database,
    required this.profile,
    required this.onSignOut,
  });
  final AppDatabase database;
  final AppProfile profile;
  final VoidCallback onSignOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;
  int refreshToken = 0;

  void _refresh() => setState(() => refreshToken++);

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Resumen',
      'Gastos',
      'Ingresos',
      'Informes',
      'Categorías',
      'Papelera',
      'Respaldos',
    ];
    final pages = [
      DashboardScreen(
        database: widget.database,
        profile: widget.profile,
        refreshToken: refreshToken,
        onAdd: _addExpense,
      ),
      ExpensesScreen(
        database: widget.database,
        profile: widget.profile,
        refreshToken: refreshToken,
        onChanged: _refresh,
        onAdd: _addExpense,
      ),
      IncomesScreen(
        database: widget.database,
        profile: widget.profile,
        refreshToken: refreshToken,
        onChanged: _refresh,
      ),
      ReportsScreen(database: widget.database, profile: widget.profile),
      CategoriesScreen(
        database: widget.database,
        profile: widget.profile,
        refreshToken: refreshToken,
        onChanged: _refresh,
      ),
      TrashScreen(
        database: widget.database,
        profile: widget.profile,
        refreshToken: refreshToken,
        onChanged: _refresh,
      ),
      BackupScreen(database: widget.database, onRestored: widget.onSignOut),
    ];

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 232,
            padding: const EdgeInsets.fromLTRB(16, 24, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE8EBE7))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 28),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFF38675C),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mis gastos',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < titles.length; i++)
                  _NavItem(
                    title: titles[i],
                    icon: [
                      Icons.space_dashboard_outlined,
                      Icons.receipt_long_outlined,
                      Icons.savings_outlined,
                      Icons.bar_chart_rounded,
                      Icons.category_outlined,
                      Icons.delete_outline,
                      Icons.backup_outlined,
                    ][i],
                    selected: selectedIndex == i,
                    onTap: () => setState(() => selectedIndex = i),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo gasto'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: CircleAvatar(
                    radius: 18,
                    child: Text(
                      widget.profile.name.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(
                    widget.profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Perfil local'),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opciones del perfil',
                    onSelected: (value) {
                      if (value == 'signout') widget.onSignOut();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'signout',
                        child: Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE8EBE7)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        titles[selectedIndex],
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        'COP',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: const Color(0xFF69746E)),
                      ),
                      const SizedBox(width: 18),
                      IconButton(
                        onPressed: widget.onSignOut,
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ExpenseFormDialog(database: widget.database, profile: widget.profile),
    );
    if (saved == true) _refresh();
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFFE9F1ED),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        leading: Icon(icon, size: 21),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}
