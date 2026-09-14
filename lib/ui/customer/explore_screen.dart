import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/shop.dart';
import '../../controllers/app_provider.dart';

class ExploreScreen extends StatefulWidget {
  final Function(Shop) onOpen;
  final bool refreshingShops;
  final VoidCallback onRefreshShops;

  const ExploreScreen({
    super.key,
    required this.onOpen,
    required this.refreshingShops,
    required this.onRefreshShops,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    
    final activeShops = provider.shops.where((s) => s.status == 'approved').toList();
    final displayedShops = activeShops.where((s) {
      final query = searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(query) || s.area.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Find your cut', style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
                    if (widget.refreshingShops)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.textMuted),
                        onPressed: widget.onRefreshShops,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Search shops or areas...',
                    hintStyle: const TextStyle(color: AppColors.textFaint),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brass,
            onRefresh: () async => widget.onRefreshShops(),
            child: displayedShops.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text("No shops found.", style: TextStyle(color: AppColors.textMuted))),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayedShops.length,
                    itemBuilder: (context, index) {
                      final shop = displayedShops[index];
                      return GestureDetector(
                        onTap: () => widget.onOpen(shop),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  image: shop.photoUrl != null
                                      ? DecorationImage(image: NetworkImage(shop.photoUrl!), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: shop.photoUrl == null
                                    ? const Center(child: Icon(Icons.storefront, color: AppColors.textMuted, size: 40))
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(shop.area, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: AppColors.brass, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${shop.rating.toStringAsFixed(1)} (${shop.reviews.length})', 
                                                style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('R${shop.price}', style: const TextStyle(color: AppColors.brass, fontSize: 16, fontWeight: FontWeight.bold)),
                                        const Text('/ month', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}