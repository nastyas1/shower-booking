import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/booking_repository.dart';

class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({
    required this.cabinId,
    required this.cabinNumber,
    required this.startsAt,
    super.key,
  });

  final int cabinId;
  final String cabinNumber;
  final DateTime startsAt;

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  static const _durations = [15, 30, 45];

  var _durationMinutes = 15;
  var _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            cabinId: widget.cabinId,
            startsAt: widget.startsAt,
            durationMinutes: _durationMinutes,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      setState(() {
        _errorMessage = switch (statusCode) {
          409 => 'Это время только что заняли. Обновите расписание.',
          400 => 'Выбранное время больше недоступно.',
          401 => 'Войдите в аккаунт, чтобы создать бронь.',
          _ => 'Не удалось создать бронь. Проверьте подключение.',
        };
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${widget.startsAt.hour.toString().padLeft(2, '0')}:'
        '${widget.startsAt.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Новая бронь',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Кабинка ${widget.cabinNumber} · $timeLabel'),
            const SizedBox(height: 24),
            Text(
              'Длительность',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final duration in _durations)
                  ChoiceChip(
                    key: Key('duration-$duration'),
                    label: Text('$duration мин'),
                    selected: _durationMinutes == duration,
                    onSelected: _isSubmitting
                        ? null
                        : (_) => setState(() => _durationMinutes = duration),
                  ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  key: const Key('booking-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('booking-submit'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Подтвердить бронь'),
            ),
          ],
        ),
      ),
    );
  }
}
