import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../widgets/outline_button.dart';

final supabase = Supabase.instance.client;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> shops = [];
  Map<String, String> ownerNames = {};
  bool loading = true;
  String filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await supabase.from('shops').select().order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rows);
      final ownerIds = list.map((s) => s['owner_id'] as String).toSet().toList();
      final profileRows = ownerIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await supabase.from('profiles').select('id, full_name').inFilter('id', ownerIds);
      setState(() {
        shops = list;
        ownerNames = {
          for (final p in profileRows) p['id'] as String: (p['full_name'] as String?)?.trim().isNotEmpty == true ? p['full_name'] as String : 'Unnamed'
        };
      });
    } catch (e) {
      showSnack('Could not load shops', isError: true);
      debugPrint('Admin load failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _setStatus(String shopId, String status) async {
    try {
      await supabase.from('shops').update({'status': status}).eq('id', shopId);
      setState(() {
        final idx = shops.indexWhere((s) => s['id'] == shopId);
        if (idx != -1) shops[idx] = {...shops[idx], 'status': status};
      });
      showSnack(status == 'approved' ? 'Shop approved' : 'Shop rejected');
    } catch (e) {
      showSnack('Failed to update shop', isError: true);
      debugPrint('Admin status update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'all' ? shops : shops.where((s) => s['status'] == filter).toList();
    final pendingCount = shops.where((s) => s['status'] == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Admin · Shops', style: TextStyle(color: AppColors.text, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.textMuted), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brass))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _FilterChip(label: 'Pending', count: pendingCount, selected: filter == 'pending', onTap: () => setState(() => filter = 'pending')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Approved', selected: filter == 'approved', onTap: () => setState(() => filter = 'approved')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Rejected', selected: filter == 'rejected', onTap: () => setState(() => filter = 'rejected')),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'All', selected: filter == 'all', onTap: () => setState(() => filter = 'all')),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('No ${filter == 'all' ? '' : filter} shops', style: const TextStyle(color: AppColors.textFaint, fontSize: 13)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final s = filtered[i];
                            return _AdminShopCard(
                              shop: s,
                              ownerName: ownerNames[s['owner_id']] ?? '—',
                              onApprove: () => _setStatus(s['id'] as String, 'approved'),
                              onReject: () => _setStatus(s['id'] as String, 'rejected'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.brass : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.brass : AppColors.line),
        ),
        child: Text(
          count != null && count! > 0 ? '$label ($count)' : label,
          style: TextStyle(
            color: selected ? AppColors.bg : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AdminShopCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final String ownerName;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _AdminShopCard({required this.shop, required this.ownerName, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final status = shop['status'] as String;
    final hasLocation = shop['latitude'] != null;
    final createdAt = DateTime.tryParse(shop['created_at'] as String? ?? '');
    final statusColor = status == 'approved' ? AppColors.brass : (status == 'rejected' ? AppColors.red : AppColors.textMuted);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(shop['name'] as String,
                    style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${shop['area']} · R${shop['price']}/mo · ${shop['chairs']} chairs',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 2),
          Text('Owner: $ownerName', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(hasLocation ? Icons.location_on : Icons.location_off, size: 12, color: AppColors.textFaint),
              const SizedBox(width: 4),
              Text(hasLocation ? 'Location set' : 'No location', style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
              if (createdAt != null) ...[
                const Text('  ·  ', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                Text('Created ${createdAt.toLocal().toString().split(' ').first}',
                    style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomOutlineButton(
                  label: 'Approve',
                  color: AppColors.brass,
                  onTap: status == 'approved' ? () {} : onApprove,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomOutlineButton(
                  label: 'Reject',
                  color: AppColors.red,
                  onTap: status == 'rejected' ? () {} : onReject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}