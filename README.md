# FlowPilot

FlowPilot is a personal productivity planner for organizing tasks, schedules,
routines, focus sessions, time tracking, and reports in one Flutter app.

## Highlights

- Task workflow with pending, in-progress, and completed states.
- Daily, weekly, and monthly calendar views with time blocks.
- Global categories shared by tasks, routines, schedules, time tracking, and
  reports.
- Repeatable routines with daily completion tracking.
- Weekly schedules for courses, shifts, and recurring activities.
- Pomodoro timer and manual time tracking.
- Reports for time, focus, Pomodoro sessions, routines, schedules, and
  categories.
- Spanish and English interface options, configurable theme, date/time format,
  and week start day.
- Light, dark, and system theme modes.

## Android Downloads

Every push to the primary branch that changes application code creates an APK
release automatically. Download the latest build from the
[Releases page](https://github.com/luisfer-cli/flowpilot/releases).

Documentation, license, and GitHub configuration changes do not create an APK
release.

## Development

### Requirements

- Flutter stable
- Dart SDK bundled with Flutter
- Android SDK for Android builds
- JDK 17

### Run locally

```bash
flutter pub get
flutter run
```

### Verify changes

```bash
flutter analyze
flutter test
```

### Build an APK

```bash
flutter build apk --release
```

The output is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```text
lib/
  app/          Application shell, routing, theme, and providers
  data/         Drift database and repositories
  features/     Product modules
  shared/       Reusable UI components
  l10n/         Spanish and English translations
test/           Automated tests
```

## Releases

The GitHub Actions workflow at
`.github/workflows/android-release.yml` builds and publishes an APK when code
is pushed to `main` or `master`. Each build receives its own GitHub Release.

The current Android release configuration uses the signing setup defined in
`android/app/build.gradle.kts`. Configure production signing before publishing
to an app store.

## License

FlowPilot is released under the [MIT License](LICENSE).
