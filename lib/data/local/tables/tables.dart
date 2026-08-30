import 'package:drift/drift.dart';

/// Life area (Trabajo, Estudio, Salud, ...).
class Areas extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0x8E9AAF))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Hierarchical goal: type 'area' or 'objective'. parentId nests objectives
/// under areas.
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get type => text().withDefault(const Constant('objective'))();
  TextColumn get parentId => text().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get targetMinutes => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get goalId => text().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0x5B8DEF))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Milestones extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get title => text()();
  DateTimeColumn get deadline => dateTime().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Customizable task status (Inbox, Backlog, Next, In Progress, ...).
@DataClassName('TaskStatus')
class TaskStatuses extends Table {
  TextColumn get name => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  IntColumn get color => integer().withDefault(const Constant(0x9AA5B1))();
}

class Contexts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0x8E9AAF))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0x8E9AAF))();
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0x8E9AAF))();
}

class TaskTags extends Table {
  TextColumn get taskId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Pendiente'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get contextId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get goalId => text().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get estimatedMinutes => integer().nullable()();
  IntColumn get actualMinutes => integer().withDefault(const Constant(0))();
  IntColumn get energyRequired => integer().nullable()();
  IntColumn get focusRequired => integer().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get checklistJson => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get recurrenceId => text().nullable()();
  BoolColumn get isEvent => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Recurrence rules for tasks (daily, weekly, days of week, monthly, every X).
class RecurrenceRules extends Table {
  TextColumn get id => text()();
  TextColumn get frequency => text()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get daysOfWeekJson => text().nullable()();
  IntColumn get dayOfMonth => integer().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A scheduled block in the calendar (time blocking).
class TimeBlocks extends Table {
  TextColumn get id => text()();
  IntColumn get dayKey => integer()();
  IntColumn get startMinutes => integer()();
  IntColumn get endMinutes => integer()();
  TextColumn get taskId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get type => text().withDefault(const Constant('flexible'))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().nullable()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Reusable weekly schedule template.
class ScheduleTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A block belonging to a weekly schedule template.
class ScheduleTemplateBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  IntColumn get weekday => integer()();
  IntColumn get startMinutes => integer()();
  IntColumn get endMinutes => integer()();
  TextColumn get title => text()();
  TextColumn get type => text().withDefault(const Constant('fixed'))();
}

/// Manual time tracking entries. A running entry has [end] == null.
class TimeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ActivityCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0x5B8DEF))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PomodoroSessions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime().nullable()();
  IntColumn get plannedMinutes => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get interruptions => integer().withDefault(const Constant(0))();
  BoolColumn get abandoned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get frequency => text()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get daysOfWeekJson => text().nullable()();
  TextColumn get goalId => text().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0x5B8DEF))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class HabitCompletions extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get stepsJson => text().withDefault(const Constant('[]'))();
  IntColumn get timeOfDayMinutes => integer().nullable()();
  IntColumn get endTimeMinutes => integer().nullable()();
  TextColumn get daysOfWeekJson => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class RoutineCompletions extends Table {
  TextColumn get routineId => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {routineId, date};
}

/// Standalone calendar events (incl. external calendars later).
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get externalId => text().nullable()();
  TextColumn get calendarName => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0x5B8DEF))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  DateTimeColumn get triggerAt => dateTime()();
  TextColumn get message => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  TextColumn get source => text().withDefault(const Constant('text'))();
  TextColumn get relatedType => text().nullable()();
  TextColumn get relatedId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Generic graph relations (goal <-> project <-> task <-> pomodoro <-> entry).
class Relations extends Table {
  TextColumn get id => text()();
  TextColumn get fromType => text()();
  TextColumn get fromId => text()();
  TextColumn get toType => text()();
  TextColumn get toId => text()();
  TextColumn get relationType => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class EnergyLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get energy => integer()();
  TextColumn get mood => text().nullable()();
  TextColumn get note => text().nullable()();
}

class AutomationRules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get trigger => text()();
  TextColumn get condition => text().nullable()();
  TextColumn get actionsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Personal journal entries. Each day can have one entry.
class JournalEntries extends Table {
  TextColumn get id => text()();
  IntColumn get dayKey => integer().unique()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  IntColumn get mood => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
