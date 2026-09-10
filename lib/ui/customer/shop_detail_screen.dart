import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../widgets/primary_button.dart';
import '../widgets/outline_button.dart';

class ShopDetailScreen extends StatelessWidget {
  final Shop shop;
  final bool isSubscribed;
  final bool subscribing;
  final bool joiningQueue;
  final bool cancelling;
  final bool queuedElsewhere;
  final VoidCallback onBack;
  final VoidCallback onSubscribe;
  final VoidCallback onWalkIn;
  final VoidCallback onCancel;

  const ShopDetailScreen({
    super.key,
    required this.shop,
    required this.isSubscribed,
    required this.subscribing,
    required this.joiningQueue,
    required this.cancelling,
    required this.queuedElsewhere,
    required this.onBack,
    required this.onSubscribe,
    required this.onWalkIn,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textMuted), onPressed: onBack),
          Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        if (shop.photoUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              shop.photoUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 12),
        ],if (shop.portfolioUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("PORTFOLIO", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: shop.portfolioUrls.length,
              itemBuilder: (context, i) {
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: DecorationImage(image: NetworkImage(shop.portfolioUrls[i]), fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text('${shop.area} · ${shop.chairs} chairs · ${shop.rating}★',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: 'R${shop.price}',
                style: const TextStyle(color: AppColors.brass, fontSize: 32, fontWeight: FontWeight.bold)),
            const TextSpan(text: ' / month', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ),
        const Text('Includes one cut every week. Cancel anytime.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const Divider(color: AppColors.line, height: 32),
        Text(
          shop.queueCount == 0 ? 'No wait right now' : '${shop.queueCount} people in the queue right now',
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (isSubscribed) ...[
          const Text("✓ YOU'RE A MEMBER HERE",
              style: TextStyle(color: AppColors.brass, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (queuedElsewhere) ...[
            const Text("You're already waiting in a queue at another shop. Leave that one before joining this one.",
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            const SizedBox(height: 10),
          ],
          PrimaryButton(label: 'Walk in now', onTap: onWalkIn, loading: joiningQueue, disabled: queuedElsewhere),
          const SizedBox(height: 10),
          CustomOutlineButton(label: 'Cancel subscription', color: AppColors.red, onTap: onCancel, loading: cancelling),
        ] else ...[
          PrimaryButton(label: 'Subscribe — R${shop.price}/month', onTap: onSubscribe, loading: subscribing),
          const SizedBox(height: 8),
          const Text("You'll be taken to PayFast to complete payment securely.",
              style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ],
      ],
    );
  }
}