import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';
import '../../booking/presentation/booking_sheet.dart';
import '../data/availability_repository.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 90)),
      ),
    );
    if (selected != null) {
      setState(() => _selectedDate = DateUtils.dateOnly(selected));
    }
  }

  Future<void> _openBooking(CabinAvailability cabin, DateTime slot) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BookingSheet(
        cabinId: cabin.id,
        cabinNumber: cabin.number,
        startsAt: slot,
      ),
    );
    if (created == true && mounted) {
      ref.invalidate(availableCabinsProvider(_selectedDate));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Бронь успешно создана')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(availableCabinsProvider(_selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание'),
        actions: [
          IconButton(
            key: const Key('open-date-picker'),
            tooltip: 'Выбрать дату',
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(availableCabinsProvider(_selectedDate).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Выберите день',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _DateSelector(
              selectedDate: _selectedDate,
              onSelected: (date) => setState(() => _selectedDate = date),
            ),
            const SizedBox(height: 24),
            Text(
              'Свободные кабинки',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            availability.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _AvailabilityError(
                error: error,
                onRetry: () =>
                    ref.invalidate(availableCabinsProvider(_selectedDate)),
              ),
              data: (cabins) {
                if (cabins.isEmpty) {
                  return const _EmptyAvailability();
                }
                return Column(
                  children: [
                    for (final cabin in cabins)
                      _CabinCard(
                        cabin: cabin,
                        onSlotSelected: (slot) => _openBooking(cabin, slot),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.selectedDate, required this.onSelected});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  static const _weekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _monthNames = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = today.add(Duration(days: index));
          final selected = DateUtils.isSameDay(date, selectedDate);
          final weekday = _weekdayNames[date.weekday - 1];
          return ChoiceChip(
            key: Key('date-${date.toIso8601String().substring(0, 10)}'),
            selected: selected,
            onSelected: (_) => onSelected(date),
            label: SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(weekday),
                  const SizedBox(height: 4),
                  Text('${date.day} ${_monthNames[date.month - 1]}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CabinCard extends StatelessWidget {
  const _CabinCard({required this.cabin, required this.onSlotSelected});

  final CabinAvailability cabin;
  final ValueChanged<DateTime> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Кабинка ${cabin.number}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (cabin.slots.isEmpty)
              const Text('Нет свободных 15-минутных слотов')
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final slot in cabin.slots)
                    ActionChip(
                      key: Key('slot-${cabin.id}-${slot.toIso8601String()}'),
                      avatar: const Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: Text(_formatTime(slot)),
                      onPressed: () => onSlotSelected(slot),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

class _AvailabilityError extends StatelessWidget {
  const _AvailabilityError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  String get _message {
    if (error is DioException) {
      final statusCode = (error as DioException).response?.statusCode;
      if (statusCode != null) {
        return 'Не удалось загрузить расписание ($statusCode).';
      }
      return 'Не удалось подключиться к серверу. Проверьте подключение.';
    }
    if (error is FormatException) {
      return 'Сервер вернул некорректное расписание.';
    }
    return 'Не удалось загрузить расписание.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(_message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class _EmptyAvailability extends StatelessWidget {
  const _EmptyAvailability();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 40, color: AppColors.mutedInk),
          SizedBox(height: 12),
          Text('На этот день свободных кабинок нет'),
        ],
      ),
    );
  }
}
