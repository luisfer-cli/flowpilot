import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_screen.dart' show appSettingsProvider;
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';
import '../core/utils/time_utils.dart';

class FlowPilotApp extends ConsumerStatefulWidget {
  const FlowPilotApp({super.key});

  @override
  ConsumerState<FlowPilotApp> createState() => _FlowPilotAppState();
}

class _FlowPilotAppState extends ConsumerState<FlowPilotApp> {
  late final router = AppRouter.router();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    configureTimeFormatting(
      languageCode: settings.languageCode,
      dateFormat: settings.dateFormat.name,
      hourFormat: settings.hourFormat.name,
      weekStartsMonday: settings.weekStartsMonday,
    );
    final seed = ref.watch(seedProvider);

    return MaterialApp.router(
      title: 'FlowPilot',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.languageCode),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (context, child) {
        return seed.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              Scaffold(body: Center(child: Text('Error inicializando: $e'))),
          data: (_) => child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
