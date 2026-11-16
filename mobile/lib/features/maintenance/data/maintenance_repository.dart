import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(ref.watch(apiClientProvider).dio),
);

class MaintenanceRepository {
  const MaintenanceRepository(this._dio);

  final Dio _dio;

  Future<void> createReport({
    required int cabinId,
    required String description,
  }) async {
    await _dio.post<void>(
      'maintenance',
      data: {'cabin_id': cabinId, 'description': description},
    );
  }
}
