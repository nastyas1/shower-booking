import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/booking_repository.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  Future<bool> _confirmCancellation(BookingSummary booking) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить бронь?'),
        content: Text('Кабинка ${booking.cabinNumber}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Оставить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отменить бронь'),
          ),
        ],
      ),
    );
    if (shouldCancel != true) return false;

    try {
      await ref.read(bookingRepositoryProvider).cancelBooking(booking.id);
      return true;
    } on DioException catch (error) {
      if (mounted) {
        final message = switch (error.response?.statusCode) {
          401 => 'Войдите в аккаунт, чтобы отменить бронь.',
          404 => 'Эта бронь уже недоступна. Обновите список.',
          _ => 'Не удалось отменить бронь. Проверьте подключение.',
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    }
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date, $time';
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Мои брони')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось загрузить список броней.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(myBookingsProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(myBookingsProvider.future),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: Text('У вас пока нет броней')),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final booking in items)
                      Dismissible(
                        key: ValueKey('booking-${booking.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmCancellation(booking),
                        onDismissed: (_) {
                          ref.invalidate(myBookingsProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Бронь отменена')),
                          );
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.error,
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        child: Card(
                          child: ListTile(
                            title: Text('Кабинка ${booking.cabinNumber}'),
                            subtitle: Text(
                              '${_formatDateTime(booking.startsAt)} – '
                              '${_formatDateTime(booking.endsAt)}',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
