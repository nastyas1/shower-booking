import 'package:material_ui/material_ui.dart';

import 'theme/app_theme.dart';

void main() {
  runApp(const ShowerBookingApp());
}

class ShowerBookingApp extends StatelessWidget {
  const ShowerBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shower Booking',
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Text('Shower Booking'),
        ),
      ),
    );
  }
}
