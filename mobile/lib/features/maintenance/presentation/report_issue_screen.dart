import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../schedule/data/availability_repository.dart';
import '../data/maintenance_repository.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  int? _selectedCabinId;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cabinId = _selectedCabinId;
    if (cabinId == null) {
      setState(() => _errorMessage = 'Выберите кабинку.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .createReport(
            cabinId: cabinId,
            description: _descriptionController.text.trim(),
          );
      if (mounted) {
        setState(() {
          _descriptionController.clear();
          _selectedCabinId = null;
          _successMessage = 'Заявка отправлена';
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (error.response?.statusCode) {
            400 => 'Проверьте выбранную кабинку и описание.',
            401 => 'Войдите в аккаунт, чтобы отправить заявку.',
            _ => 'Не удалось отправить заявку. Проверьте подключение.',
          };
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateUtils.dateOnly(DateTime.now());
    final cabins = ref.watch(availableCabinsProvider(date));

    return Scaffold(
      appBar: AppBar(title: const Text('Сообщить о неисправности')),
      body: cabins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось загрузить список кабинок.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(availableCabinsProvider(date)),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          final selectedCabinId =
              items.any((cabin) => cabin.id == _selectedCabinId)
              ? _selectedCabinId
              : null;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Опишите проблему, чтобы мы могли быстрее её устранить.',
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      key: const Key('issue-cabin'),
                      initialValue: selectedCabinId,
                      decoration: const InputDecoration(
                        labelText: 'Кабинка',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final cabin in items)
                          DropdownMenuItem(
                            value: cabin.id,
                            child: Text('Кабинка ${cabin.number}'),
                          ),
                      ],
                      onChanged: _isSubmitting || items.isEmpty
                          ? null
                          : (id) => setState(() {
                              _selectedCabinId = id;
                              _errorMessage = null;
                            }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('issue-description'),
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Описание неисправности',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Опишите неисправность.'
                          : null,
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() => _errorMessage = null);
                        }
                      },
                    ),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Не найдено активных кабинок.'),
                      ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorMessage!,
                          key: const Key('issue-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _successMessage!,
                          key: const Key('issue-success'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('issue-submit'),
                      onPressed: _isSubmitting || items.isEmpty
                          ? null
                          : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Отправить заявку'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
