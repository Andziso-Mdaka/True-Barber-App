import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../widgets/outline_button.dart';

class AccountScreen extends StatelessWidget {
  final List<Shop> shops;
  final String? cancellingShopId;
  final void Function(String shopId) onCancel;
  final bool notificationsEnabled;
  final bool checkingNotificationPermission;
  final Future<void> Function() onEnableNotifications;
  const AccountScreen({
    super.key,
    required this.shops,
    required this.cancellingShopId,
    required this.onCancel,
    required this.notificationsEnabled,
    required this.checkingNotificationPermission,
    required this.onEnableNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!checkingNotificationPermission && !notificationsEnabled)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.brass.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.brass.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_none, color: AppColors.brass, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Get notified the moment your barber calls you',
                          style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomOutlineButton(label: 'Enable notifications', onTap: onEnableNotifications),
              ],
            ),
          ),
        if (shops.isEmpty)
          const Text("No active subscriptions yet. Find a shop from the home tab to get started.",
              style: TextStyle(color: AppColors.textFaint, fontSize: 13))
        else ...[
          Text(
            shops.length == 1 ? 'Active subscription' : '${shops.length} active subscriptions',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final shop in shops)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${shop.area} · R${shop.price}/mo', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 14),
                  CustomOutlineButton(
                    label: 'Cancel subscription',
                    color: AppColors.red,
                    onTap: () => onCancel(shop.id),
                    loading: cancellingShopId == shop.id,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
