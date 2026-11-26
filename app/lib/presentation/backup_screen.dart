import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.database,
    required this.onRestored,
  });

  final AppDatabase database;
  final VoidCallback onRestored;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupService service = BackupService(widget.database);
  bool busy = false;
  String? status;
  bool statusIsError = false;

  Future<void> _createBackup() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final path = await service.createBackup();
      if (!mounted) return;
      setState(() {
        status = path == null
            ? 'Se canceló la creación del respaldo.'
            : 'Respaldo creado en $path';
        statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        status = 'No se pudo crear el respaldo: $error';
        statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text(
          'La restauración reemplazará los gastos, ingresos, categorías, perfiles y archivos de este equipo por los del respaldo. Esta acción afecta a todos los perfiles locales. ¿Quieres elegir un respaldo compatible?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elegir archivo'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final name = await service.restoreBackup();
      if (!mounted) return;
      if (name == null) {
        setState(() {
          status = 'Se canceló la restauración.';
          statusIsError = false;
        });
        return;
      }
      setState(() {
        status = 'Respaldo restaurado: $name. Inicia sesión de nuevo.';
        statusIsError = false;
      });
      widget.onRestored();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        status = 'No se pudo restaurar el respaldo: $error';
        statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = statusIsError
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF38675C);
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Protege tus datos',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Guarda una copia en otra ubicación para recuperarla si cambias de equipo o se pierde información. El respaldo incluye todos los perfiles locales, sus registros y comprobantes adjuntos. El archivo no está cifrado: guárdalo en un lugar privado.',
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crear respaldo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Se creará un archivo .sgcgbak con los perfiles, categorías, ingresos, gastos, papelera y documentos adjuntos.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy ? null : _createBackup,
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Guardar respaldo…'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restaurar respaldo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'La restauración reemplaza la información actual de todos los perfiles por la información incluida en el archivo.',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _restoreBackup,
                        icon: const Icon(Icons.settings_backup_restore),
                        label: const Text('Elegir respaldo…'),
                      ),
                    ],
                  ),
                ),
              ),
              if (busy) ...[
                const SizedBox(height: 20),
                const LinearProgressIndicator(),
              ],
              if (status != null) ...[
                const SizedBox(height: 18),
                SelectableText(status!, style: TextStyle(color: color)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
