import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';

Future<void> showCategoryManager(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _CategoryManagerDialog(),
  );
}

class _CategoryManagerDialog extends ConsumerWidget {
  const _CategoryManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(globalCategoriesProvider).valueOrNull ?? const <Category>[];
    return AlertDialog(
      title: const Text('Categorías globales'),
      content: SizedBox(
        width: 380,
        child: categories.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Aún no hay categorías.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final color = Color(category.color);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 10, backgroundColor: color),
                    title: Text(category.name),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'Editar categoría',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _editCategory(context, ref, category: category),
                        ),
                        IconButton(
                          tooltip: 'Eliminar categoría',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _deleteCategory(context, ref, category),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: () => _editCategory(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Agregar'),
        ),
      ],
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
  }) async {
    final name = TextEditingController(text: category?.name ?? '');
    var color = category?.color ?? _categoryColors.first;
    final result = await showDialog<({String name, int color})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            category == null ? 'Nueva categoría' : 'Editar categoría',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Color',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final value in _categoryColors)
                    InkWell(
                      onTap: () => setState(() => color = value),
                      borderRadius: BorderRadius.circular(20),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(value),
                        child: color == value
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = name.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, (name: value, color: color));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (result == null || !context.mounted) return;
    final repository = ref.read(categoryRepositoryProvider);
    if (category == null) {
      await repository.insert(
        CategoriesCompanion.insert(
          id: generateId(),
          name: result.name,
          color: Value(result.color),
        ),
      );
    } else {
      await repository.update(
        category.id,
        CategoriesCompanion(
          name: Value(result.name),
          color: Value(result.color),
        ),
      );
    }
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          'Las asociaciones de «${category.name}» quedarán vacías.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoryRepositoryProvider).delete(category.id);
    }
  }
}

const _categoryColors = [
  0xFF5B8DEF,
  0xFF8E9AAF,
  0xFF26A69A,
  0xFFEF8354,
  0xFFE85D75,
  0xFF9B5DE5,
  0xFFF2C14E,
  0xFF4D908E,
];
