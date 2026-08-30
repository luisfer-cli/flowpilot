import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/services/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load locale data used by calendar and reports.
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);
  await NotificationsService.instance.init();
  runApp(const ProviderScope(child: FlowPilotApp()));
}
