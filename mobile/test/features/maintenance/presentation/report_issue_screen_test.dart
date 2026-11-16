import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_booking/core/router/app_router.dart';
import 'package:shower_booking/features/maintenance/data/maintenance_repository.dart';
import 'package:shower_booking/features/schedule/data/availability_repository.dart';
import 'package:shower_booking/main.dart';

class _FakeAvailabilityRepository extends AvailabilityRepository {
  _FakeAvailabilityRepository() : super(Dio());

  @override
  Future<List<CabinAvailability>> getAvailableCabins(DateTime date) async => [
    const CabinAvailability(id: 7, number: 'A-07', slots: []),
  ];
}

class _FakeMaintenanceRepository extends MaintenanceRepository {
  _FakeMaintenanceRepository() : super(Dio());

  int? cabinId;
  String? description;

  @override
  Future<void> createReport({
    required int cabinId,
    required String description,
  }) async {
    this.cabinId = cabinId;
    this.description = description;
  }
}

void main() {
  testWidgets('submits a fault report for the selected cabin', (tester) async {
    final maintenanceRepository = _FakeMaintenanceRepository();
    final container = ProviderContainer(
      overrides: [
        availabilityRepositoryProvider.overrideWithValue(
          _FakeAvailabilityRepository(),
        ),
        maintenanceRepositoryProvider.overrideWithValue(maintenanceRepository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShowerBookingApp(),
      ),
    );
    container.read(appRouterProvider).go('/report-issue');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('issue-cabin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кабинка A-07'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('issue-description')),
      'Слабый напор воды',
    );
    await tester.ensureVisible(find.byKey(const Key('issue-submit')));
    await tester.tap(find.byKey(const Key('issue-submit')));
    await tester.pumpAndSettle();

    expect(maintenanceRepository.cabinId, 7);
    expect(maintenanceRepository.description, 'Слабый напор воды');
    expect(find.text('Заявка отправлена'), findsOneWidget);
  });
}
