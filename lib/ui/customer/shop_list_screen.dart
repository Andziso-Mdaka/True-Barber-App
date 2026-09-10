import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';

class ShopListScreen extends StatelessWidget {
  final List<Shop> shops;
  final void Function(Shop) onOpen;
  final bool refreshingShops;
  final Future<void> Function() onRefreshShops;
  const ShopListScreen({
    super.key,
    required this.shops,
    required this.onOpen,
    required this.refreshingShops,
    required this.onRefreshShops,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.brass,
      backgroundColor: AppColors.surface,
      onRefresh: onRefreshShops,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "One monthly fee. Unlimited weekly cuts. Walk in, no booking needed.",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
              IconButton(
                icon: refreshingShops
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass),
                      )
                    : const Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
                onPressed: refreshingShops ? null : onRefreshShops,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (shops.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('No shops yet — pull down to refresh.', style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
              ),
            ),
          ...shops.map((s) => _ShopCard(shop: s, onTap: () => onOpen(s))),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;
  const _ShopCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: shop.isMine ? AppColors.brass : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shop.photoUrl != null)
              Image.network(
                shop.photoUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(shop.name,
                          style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (shop.isMine)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.brass, borderRadius: BorderRadius.circular(4)),
                          child: const Text('YOURS',
                              style: TextStyle(color: AppColors.bg, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${shop.area} · ${shop.chairs} chairs · ${shop.rating}★',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('R${shop.price}/mo · unlimited cuts',
                          style: const TextStyle(color: AppColors.brass, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        shop.queueCount == 0 ? 'No wait' : '${shop.queueCount} in queue',
                        style: TextStyle(color: shop.queueCount == 0 ? AppColors.textFaint : AppColors.text, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}