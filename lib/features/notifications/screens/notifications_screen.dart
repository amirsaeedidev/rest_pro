import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/model/notification_model.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _userId;
  Stream<List<NotificationModel>>? _notificationsStream;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    if (_userId != null) {
      _notificationsStream = NotificationService.watchForUser(_userId!);
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = _userId;
    if (userId == null || _markingAll) return;

    setState(() => _markingAll = true);
    try {
      await NotificationService.markAllAsRead(userId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خواندن اعلان‌ها انجام نشد. دوباره تلاش کنید.')),
        );
      }
      debugPrint('Mark all customer notifications read failed: $error');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(NotificationModel notification) async {
    final userId = _userId;
    if (userId == null || notification.isRead) return;
    try {
      await NotificationService.markAsRead(
        userId: userId,
        notificationId: notification.id,
      );
    } catch (error) {
      debugPrint('Mark customer notification read failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final background =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: textColor,
          title: const Text(
            'اعلان‌ها',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          actions: [
            TextButton.icon(
              onPressed: _markingAll ? null : _markAllAsRead,
              icon: _markingAll
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('همه خوانده شوند'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _userId == null
            ? const _NotificationsMessage(
                icon: Icons.lock_outline_rounded,
                title: 'برای مشاهده اعلان‌ها وارد شوید',
                subtitle: 'پس از ورود، اعلان‌های ثبت‌شده در حساب شما نمایش داده می‌شوند.',
              )
            : StreamBuilder<List<NotificationModel>>(
                stream: _notificationsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _NotificationsSkeleton();
                  }
                  if (snapshot.hasError) {
                    return _NotificationsMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'دریافت اعلان‌ها ممکن نشد',
                      subtitle: 'اتصال اینترنت و دسترسی جدول customer_notifications را بررسی کنید.',
                      action: FilledButton.icon(
                        onPressed: () => setState(() {
                          _notificationsStream =
                              NotificationService.watchForUser(_userId!);
                        }),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تلاش دوباره'),
                      ),
                    );
                  }

                  final notifications = snapshot.data ?? const [];
                  final unreadCount =
                      notifications.where((item) => !item.isRead).length;

                  if (notifications.isEmpty) {
                    return const _NotificationsMessage(
                      icon: Icons.notifications_off_outlined,
                      title: 'اعلان تازه‌ای ندارید',
                      subtitle: 'اعلان‌های سفارش، تخفیف و حساب کاربری در همین صفحه نمایش داده می‌شوند.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _notificationsStream =
                            NotificationService.watchForUser(_userId!);
                      });
                      await Future<void>.delayed(
                        const Duration(milliseconds: 250),
                      );
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        if (unreadCount > 0) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '$unreadCount اعلان خوانده‌نشده',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        for (final notification in notifications)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NotificationCard(
                              notification: notification,
                              isDark: isDark,
                              onTap: () => _openNotification(notification),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  final NotificationModel notification;
  final bool isDark;
  final VoidCallback onTap;

  IconData get _icon {
    switch (notification.type) {
      case 'order':
        return Icons.receipt_long_rounded;
      case 'discount':
        return Icons.local_offer_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'reservation':
        return Icons.table_restaurant_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year}  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notification.isRead
                  ? (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05))
                  : AppColors.primary.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: AppColors.primary),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        notification.body,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 12,
                          height: 1.7,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Text(
                      _dateLabel(notification.createdAt),
                      style: TextStyle(color: secondary, fontSize: 10.5),
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

class _NotificationsMessage extends StatelessWidget {
  const _NotificationsMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primary.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.7,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      width: 100,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
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
