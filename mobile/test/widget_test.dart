import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_booking/main.dart';
import 'package:shower_booking/theme/app_theme.dart';

void main() {
  testWidgets('renders the app with its base theme', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ShowerBookingApp()),
    );

    expect(find.text('Sign in'), findsNWidgets(2));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme, same(AppTheme.light));
    expect(materialApp.theme!.colorScheme.primary, AppColors.primary);
    expect(materialApp.theme!.textTheme.bodyMedium!.fontFamily, 'Roboto');
  });
}
