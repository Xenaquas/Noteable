import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/local/databases/app_drift_database.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/task_repository.dart';

/// Bridges stored reminders with the notification plugin.
class NotificationSyncService {
  NotificationSyncService(this._remindersRepo, this._taskRepo) {
    _plugin = FlutterLocalNotificationsPlugin();
  }

  static const _criticalChannelId = 'reminders_critical';
  static const _standardChannelId = 'reminders_standard';

  final ReminderRepository _remindersRepo;
  final TaskRepository _taskRepo;
  late final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<ReminderAlert> _foregroundAlerts =
      StreamController.broadcast();
  final StreamController<NotificationTap> _tapEvents =
      StreamController.broadcast();
  Timer? _foregroundTimer;
  bool _foregroundActive = false;
  bool _initialized = false;

  Stream<ReminderAlert> get foregroundAlerts => _foregroundAlerts.stream;
  Stream<NotificationTap> get tapEvents => _tapEvents.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    final details = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = details?.notificationResponse;
    if (details?.didNotificationLaunchApp == true && launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }
    await _ensureAndroidChannels();
    await _requestPermissions();
  }

  Future<int> scheduleReminder(
    Reminder reminder, {
    String? title,
    String? body,
    ReminderTone tone = ReminderTone.standard,
  }) async {
    final id = reminder.id;
    if (!_foregroundActive) {
      await _plugin.zonedSchedule(
        id,
        reminder.ownerType == 'note' ? 'Note reminder' : title ?? 'Reminder',
        reminder.ownerType == 'note'
            ? 'A note reminder is due. Open the app to view it.'
            : body ?? '${reminder.ownerType} due',
        tz.TZDateTime.from(reminder.fireAt, tz.local),
        _notificationDetails(tone),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
        payload: '${reminder.ownerType}:${reminder.ownerId}',
      );
    }
    await _remindersRepo.setNotificationId(id, id.toString());
    return id;
  }

  Future<void> cancelReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  /// Reschedule all pending reminders up to [untilUtc].
  Future<void> reschedulePending(DateTime untilUtc) async {
    if (_foregroundActive) return;
    final due = await _remindersRepo.dueUntilUtc(untilUtc);
    for (final r in due) {
      final tone = await _toneFor(r);
      final notifId = await scheduleReminder(r, tone: tone);
      await _remindersRepo.markStatus(r.id, kReminderScheduled);
      await _remindersRepo.setNotificationId(r.id, notifId.toString());
    }
  }

  Future<void> enterForeground() async {
    await init();
    if (_foregroundActive) return;
    _foregroundActive = true;
    await _cancelScheduledReminders();
    _startForegroundTimer();
  }

  Future<void> enterBackground() async {
    await init();
    if (!_foregroundActive) return;
    _foregroundActive = false;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    await reschedulePending(DateTime.now().toUtc().add(const Duration(days: 7)));
  }

  Future<void> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = _parsePayload(response.payload);
    if (payload != null) {
      _tapEvents.add(payload);
    }
  }

  NotificationTap? _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final parts = payload.split(':');
    if (parts.length != 2) return null;
    final id = int.tryParse(parts[1]);
    if (id == null) return null;
    return NotificationTap(ownerType: parts[0], ownerId: id);
  }

  void _startForegroundTimer() {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _checkDueReminders(),
    );
    _checkDueReminders();
  }

  Future<void> _checkDueReminders() async {
    final nowUtc = DateTime.now().toUtc();
    final due = await _remindersRepo.dueUntilUtc(nowUtc);
    for (final r in due) {
      await _remindersRepo.markStatus(r.id, kReminderFired);
      _foregroundAlerts.add(
        ReminderAlert(
          ownerType: r.ownerType,
          ownerId: r.ownerId,
          fireAt: r.fireAt,
        ),
      );
    }
  }

  Future<void> _cancelScheduledReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_isReminderPayload(request.payload)) {
        await _plugin.cancel(request.id);
      }
    }
  }

  bool _isReminderPayload(String? payload) {
    if (payload == null) return false;
    return payload.startsWith('task:') ||
        payload.startsWith('schedule:') ||
        payload.startsWith('note:');
  }

  NotificationDetails _notificationDetails(ReminderTone tone) {
    final isCritical = tone == ReminderTone.critical;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        isCritical ? _criticalChannelId : _standardChannelId,
        isCritical ? 'Critical Reminders' : 'Standard Reminders',
        importance: isCritical ? Importance.max : Importance.high,
        priority: Priority.high,
        playSound: isCritical,
        enableVibration: isCritical,
        category: isCritical ? AndroidNotificationCategory.alarm : null,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: isCritical,
      ),
    );
  }

  Future<void> _ensureAndroidChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _criticalChannelId,
        'Critical Reminders',
        description: 'Urgent reminders that need full attention.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _standardChannelId,
        'Standard Reminders',
        description: 'Silent reminders for standard tasks and notes.',
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  Future<bool> supportsNotificationSettingsDeepLinks() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return android != null;
  }

  Future<ReminderTone> _toneFor(Reminder reminder) async {
    if (reminder.ownerType == 'task') {
      final task = await _taskRepo.getTask(reminder.ownerId);
      if (task != null && task.priority == kPriorityHigh) {
        return ReminderTone.critical;
      }
    }
    return ReminderTone.standard;
  }
}

class ReminderAlert {
  const ReminderAlert({
    required this.ownerType,
    required this.ownerId,
    required this.fireAt,
  });

  final String ownerType;
  final int ownerId;
  final DateTime fireAt;
}

class NotificationTap {
  const NotificationTap({
    required this.ownerType,
    required this.ownerId,
  });

  final String ownerType;
  final int ownerId;
}

enum ReminderTone { critical, standard }
