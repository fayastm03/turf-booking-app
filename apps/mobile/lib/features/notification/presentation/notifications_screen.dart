import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../bloc/notification_bloc.dart';
import '../domain/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Load notifications on mount
    context.read<NotificationBloc>().add(LoadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              if (state is NotificationLoaded && state.unreadCount > 0) {
                return TextButton.icon(
                  onPressed: () {
                    context.read<NotificationBloc>().add(MarkAllNotificationsAsRead());
                  },
                  icon: const Icon(Icons.done_all, size: 16, color: Colors.green),
                  label: const Text('Read All', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Failed to load notifications: ${state.error}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<NotificationBloc>().add(LoadNotifications()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is NotificationLoaded) {
            final notifications = state.notifications;

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_off_outlined, size: 64, color: Colors.white38),
                    const SizedBox(height: 16),
                    const Text(
                      'All caught up!',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'No new notifications at this time.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Explore fields to book'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<NotificationBloc>().add(LoadNotifications());
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _buildNotificationCard(context, notif, primaryColor);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel notif, Color primaryColor) {
    final date = DateTime.parse(notif.createdAt);
    final formattedDate = DateFormat('MMM d, HH:mm').format(date);

    final isUnread = !notif.isRead;
    final leadingIcon = _getNotificationIcon(notif.type);
    final iconColor = _getNotificationColor(notif.type, primaryColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFF1B243B) : const Color(0xFF131A26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? primaryColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: isUnread ? 1.2 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: () {
          if (isUnread) {
            context.read<NotificationBloc>().add(MarkNotificationAsRead(notif.id));
          }
        },
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(leadingIcon, color: iconColor, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                notif.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedDate,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(
            notif.body,
            style: TextStyle(
              color: isUnread ? Colors.white : Colors.white60,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
        trailing: isUnread
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toUpperCase()) {
      case 'BOOKING_CONFIRMED':
        return Icons.check_circle_outline;
      case 'BOOKING_CANCELLED':
        return Icons.cancel_outlined;
      case 'WALLET_TOPUP':
        return Icons.add_circle_outline;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getNotificationColor(String type, Color primaryColor) {
    switch (type.toUpperCase()) {
      case 'BOOKING_CONFIRMED':
        return Colors.green;
      case 'BOOKING_CANCELLED':
        return Colors.redAccent;
      case 'WALLET_TOPUP':
        return primaryColor;
      default:
        return Colors.white60;
    }
  }
}
