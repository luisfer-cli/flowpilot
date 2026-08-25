/// Default task statuses, in a logical pipeline order. Customizable in settings.
const List<String> kDefaultStatuses = [
  'Inbox',
  'Backlog',
  'Next',
  'In Progress',
  'Blocked',
  'Waiting',
  'Done',
  'Cancelled',
];

const String kStatusDone = 'Done';
const String kStatusCancelled = 'Cancelled';

/// Priority values (0 = none, 1 = low, 2 = medium, 3 = high, 4 = urgent).
const int kPriorityNone = 0;

/// Time block types.
const String kBlockTypeFixed = 'fixed';
const String kBlockTypeFlexible = 'flexible';
const String kBlockTypeBuffer = 'buffer';
const String kBlockTypeTransition = 'transition';
const String kBlockTypeEvent = 'event';

/// Life areas used by the goal hierarchy.
const List<String> kDefaultAreas = [
  'Trabajo',
  'Estudio',
  'Salud',
  'Ejercicio',
  'Personal',
  'Familia',
  'Finanzas',
  'Proyectos',
  'Ocio',
];

/// Default contexts.
const List<String> kDefaultContexts = [
  '💻 PC',
  '📱 Teléfono',
  '🏠 Casa',
  '🏢 Trabajo',
  '🚗 Fuera',
  '🧠 Alta concentración',
];

/// Recurrence frequency types.
const String kFreqDaily = 'daily';
const String kFreqWeekly = 'weekly';
const String kFreqMonthly = 'monthly';
const String kFreqEveryXDays = 'every_x_days';
const String kFreqAfterCompletion = 'after_completion';

/// Source of a time entry.
const String kSourceManual = 'manual';
const String kSourceAuto = 'auto';
const String kSourcePomodoro = 'pomodoro';
