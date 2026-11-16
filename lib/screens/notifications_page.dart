import 'package:flutter/material.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/screens/account_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<_AppNotification> _notifications = const [];
  String _preference = 'important';
  String? _message;
  bool _isLoading = true;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!SocialConfig.isAvailable) {
      setState(() {
        _message = 'Notifications will be available when social features are configured.';
        _isLoading = false;
      });
      return;
    }

    final user = SocialConfig.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _message = 'Sign in to see updates from friends.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final profile = await SocialConfig.client
          .from('profiles')
          .select('notification_preference')
          .eq('id', user.id)
          .maybeSingle();
      final preference = _normalisePreference(
        profile?['notification_preference']?.toString(),
      );

      if (preference == 'off') {
        if (!mounted) return;
        setState(() {
          _preference = preference;
          _notifications = const [];
          _isLoading = false;
        });
        return;
      }

      dynamic request = SocialConfig.client
          .from('app_notifications')
          .select('id, type, importance, title, body, metadata, read_at, created_at')
          .eq('recipient_id', user.id);
      if (preference == 'important') {
        request = request.gte('importance', 2);
      }
      final rows = await request.order('created_at', ascending: false).limit(60);
      final notifications = (rows as List<dynamic>)
          .map((row) => _AppNotification.fromJson(row as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _preference = preference;
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not load notifications yet. Check that the notifications database update has been applied.';
        _isLoading = false;
      });
    }
  }

  Future<void> _markOneRead(_AppNotification notification) async {
    if (notification.isRead || !SocialConfig.isAvailable) return;
    try {
      await SocialConfig.client
          .from('app_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(readAt: DateTime.now())
                  : item,
            )
            .toList();
      });
    } catch (_) {
      // Reading a notification is a convenience, so the screen remains usable.
    }
  }

  Future<void> _markAllRead() async {
    if (_isMarkingRead || !SocialConfig.isAvailable) return;
    final unread = _notifications.where((notification) => !notification.isRead).toList();
    if (unread.isEmpty) return;

    setState(() => _isMarkingRead = true);
    try {
      final user = SocialConfig.client.auth.currentUser;
      if (user == null) return;
      await SocialConfig.client
          .from('app_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', user.id)
          .isFilter('read_at', null);
      if (!mounted) return;
      setState(() {
        final now = DateTime.now();
        _notifications = _notifications
            .map((notification) => notification.copyWith(readAt: now))
            .toList();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark notifications as read.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((notification) => !notification.isRead).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: unreadCount == 0 || _isMarkingRead ? null : _markAllRead,
            child: Text(_isMarkingRead ? 'Reading…' : 'Read all'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            _NotificationPreferenceHint(preference: _preference),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_preference == 'off')
              _NotificationsOff(onOpenSettings: _openSettings)
            else if (_message != null)
              _NotificationMessage(message: _message!, onRetry: _loadNotifications)
            else if (_notifications.isEmpty)
              const _NotificationMessage(
                message: 'Nothing new for now. Friend requests and places shared by friends will appear here.',
              )
            else
              ..._notifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationTile(
                    notification: notification,
                    onTap: () => _markOneRead(notification),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AccountPage()),
    );
    if (mounted) _loadNotifications();
  }
}

class _NotificationPreferenceHint extends StatelessWidget {
  const _NotificationPreferenceHint({required this.preference});

  final String preference;

  @override
  Widget build(BuildContext context) {
    final message = switch (preference) {
      'all' => 'Showing all activity from your friends.',
      _ => 'Showing important updates only. Change this in Account settings.',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, color: Color(0xFF205A78)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _NotificationsOff extends StatelessWidget {
  const _NotificationsOff({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _NotificationMessage(
      message: 'Notifications are turned off. You can re-enable important updates whenever you want.',
      actionLabel: 'Open settings',
      onAction: onOpenSettings,
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onRetry,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              const Icon(Icons.notifications_none_rounded, size: 48, color: Color(0xFF587789)),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null || onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction ?? () => onRetry!(),
                  child: Text(actionLabel ?? 'Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final _AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = notification.isRead
        ? const Color(0xFFF7FAFC)
        : const Color(0xFFEAF6FB);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF2E6F99),
                foregroundColor: Colors.white,
                child: Icon(notification.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!notification.isRead)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.circle, size: 9, color: Color(0xFFE55353)),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notification.body),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: const TextStyle(color: Color(0xFF587789), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppNotification {
  const _AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  factory _AppNotification.fromJson(Map<String, dynamic> json) {
    return _AppNotification(
      id: json['id'].toString(),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Update',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      readAt: json['read_at'] == null
          ? null
          : DateTime.tryParse(json['read_at'].toString()),
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  IconData get icon => switch (type) {
    'friend_request' => Icons.person_add_alt_1_rounded,
    'friend_request_accepted' => Icons.handshake_rounded,
    'friend_place_added' => Icons.place_rounded,
    _ => Icons.notifications_rounded,
  };

  _AppNotification copyWith({DateTime? readAt}) {
    return _AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

String _normalisePreference(String? value) {
  if (value == 'all' || value == 'off' || value == 'important') {
    return value!;
  }
  return 'important';
}

String _relativeTime(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Yesterday';
  return '${difference.inDays} days ago';
}
