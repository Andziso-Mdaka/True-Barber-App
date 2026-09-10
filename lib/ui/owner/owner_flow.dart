import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../controllers/app_provider.dart';
import '../widgets/custom_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/outline_button.dart';
import '../widgets/metric_card.dart';
import 'location_picker_screen.dart';

class OwnerFlow extends StatefulWidget {
  const OwnerFlow({super.key});

  @override
  State<OwnerFlow> createState() => _OwnerFlowState();
}

class _OwnerFlowState extends State<OwnerFlow> {
  final nameCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final chairsCtrl = TextEditingController();
  LatLng? pickedLocation;
  final newBarberCtrl = TextEditingController();
  final newServiceCtrl = TextEditingController();
  bool showStaff = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.ownerShop == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('List your shop', style: TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Set a monthly price, and let regulars walk in without booking.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 18),
          CustomField(label: 'Shop name', controller: nameCtrl, hint: 'e.g. Corner Cuts'),
          CustomField(label: 'Area / suburb', controller: areaCtrl, hint: 'e.g. Rosebank'),
          Row(children: [
            Expanded(child: CustomField(label: 'Price / month (R)', controller: priceCtrl, hint: '450', numeric: true)),
            const SizedBox(width: 12),
            Expanded(child: CustomField(label: 'Chairs', controller: chairsCtrl, hint: '3', numeric: true)),
          ]),
          const Text('LOCATION', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: pickedLocation)),
              );
              if (result != null) setState(() => pickedLocation = result);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(pickedLocation == null ? Icons.add_location_alt_outlined : Icons.check_circle,
                      color: pickedLocation == null ? AppColors.textMuted : AppColors.brass, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    pickedLocation == null ? 'Set on map (optional, but recommended)' : 'Location set — tap to adjust',
                    style: TextStyle(color: pickedLocation == null ? AppColors.textMuted : AppColors.text, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (provider.createShopError != null) ...[
            Text(provider.createShopError!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          PrimaryButton(
            label: 'Create shop',
            loading: provider.creatingShop,
            onTap: () {
              final price = int.tryParse(priceCtrl.text) ?? 0;
              final chairs = int.tryParse(chairsCtrl.text) ?? 0;
              if (nameCtrl.text.isEmpty || areaCtrl.text.isEmpty || price == 0 || chairs == 0) {
                showSnack('Fill in every field first', isError: true);
                return;
              }
              provider.createShop(nameCtrl.text, areaCtrl.text, price, chairs, pickedLocation);
            },
          ),
        ],
      );
    }

    final shop = provider.ownerShop!;
    final activeStaffCount = shop.staff.where((b) => b.active).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (shop.status != 'approved') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: (shop.status == 'rejected' ? AppColors.red : AppColors.brass).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (shop.status == 'rejected' ? AppColors.red : AppColors.brass).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  shop.status == 'rejected' ? Icons.block : Icons.hourglass_top,
                  color: shop.status == 'rejected' ? AppColors.red : AppColors.brass,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    shop.status == 'rejected'
                        ? "This shop wasn't approved and isn't visible to customers."
                        : "Waiting for approval — customers can't find or subscribe to this shop yet.",
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: provider.uploadingPhoto ? null : provider.uploadShopPhoto,
          child: Container(
            width: double.infinity,
            height: 140,
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
              image: shop.photoUrl != null
                  ? DecorationImage(image: NetworkImage(shop.photoUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: Stack(
              children: [
                if (shop.photoUrl == null)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted, size: 26),
                        SizedBox(height: 6),
                        Text('Add a shop photo', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                if (provider.uploadingPhoto)
                  Container(
                    color: Colors.black.withOpacity(0.4),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.brass),
                    ),
                  )
                else if (shop.photoUrl != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.bg.withOpacity(0.75), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Change photo', style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('PORTFOLIO', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
            if (provider.uploadingPortfolio)
               const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brass))
            else
               GestureDetector(
                 onTap: provider.uploadPortfolioPhoto,
                 child: const Text('+ Add Photo', style: TextStyle(color: AppColors.brass, fontSize: 12, fontWeight: FontWeight.bold)),
               )
          ],
        ),
        const SizedBox(height: 8),
        if (shop.portfolioUrls.isEmpty)
          const Text("Show off your cuts. Add some photos to your gallery.", style: TextStyle(color: AppColors.textFaint, fontSize: 12))
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: shop.portfolioUrls.length,
              itemBuilder: (context, i) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(image: NetworkImage(shop.portfolioUrls[i]), fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 24),
        
        const Text('SERVICES', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newServiceCtrl,
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'e.g. Skin Fade',
                  hintStyle: const TextStyle(color: AppColors.textFaint),
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) {
                  provider.addService(newServiceCtrl.text);
                  newServiceCtrl.clear();
                },
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                provider.addService(newServiceCtrl.text);
                newServiceCtrl.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brass,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shop.services.isEmpty)
          const Text("Add some services so customers know what you offer.", style: TextStyle(color: AppColors.textFaint, fontSize: 13))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shop.services.map((service) => Container(
              padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(service, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => provider.removeService(service),
                    child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                  ),
                ],
              ),
            )).toList(),
          ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name, style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.bold)),
                  Text('${shop.area} · ${shop.chairs} chairs', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => setState(() => showStaff = !showStaff),
              style: OutlinedButton.styleFrom(
                foregroundColor: showStaff ? AppColors.brass : AppColors.textMuted,
                side: BorderSide(color: showStaff ? AppColors.brass : AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(showStaff ? 'Queue' : 'Staff'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final initial = shop.latitude != null && shop.longitude != null
                ? LatLng(shop.latitude!, shop.longitude!)
                : null;
            final result = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: initial)),
            );
            if (result != null) provider.updateShopLocation(result);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(
                  shop.latitude == null ? Icons.location_off_outlined : Icons.location_on_outlined,
                  color: shop.latitude == null ? AppColors.red.withOpacity(0.8) : AppColors.brass,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop.latitude == null ? "No location set — you won't show on the map" : 'Location set — tap to update',
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!showStaff) ...[
          Row(children: [
            Expanded(child: MetricCard(label: 'Subscribers', value: '${shop.subscriberCount}')),
            const SizedBox(width: 10),
            Expanded(child: MetricCard(label: 'Monthly revenue', value: 'R${shop.subscriberCount * shop.price}', accent: true)),
            const SizedBox(width: 10),
            Expanded(child: MetricCard(label: 'In queue', value: '${shop.queue.where((q) => q.status == 'waiting').length}')),
          ]),
          const SizedBox(height: 16),
          CustomOutlineButton(
            label: 'Refresh queue',
            loading: provider.refreshingQueue,
            onTap: provider.refreshOwnerShop,
          ),
          const SizedBox(height: 18),
          const Text("TODAY'S QUEUE", style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          if (shop.queue.isEmpty)
            const Text("Nobody's waiting right now.", style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ...shop.queue.map((q) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(text: '#${q.ticketNo} ', style: const TextStyle(color: AppColors.brass, fontWeight: FontWeight.bold)),
                            TextSpan(text: '${q.name} → ${q.barber}', style: const TextStyle(color: AppColors.text)),
                          ])),
                          if (q.status == 'called') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.brass.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: const Text('CALLED', style: TextStyle(color: AppColors.brass, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (q.status == 'waiting')
                          GestureDetector(
                            onTap: () => provider.callCustomer(q.id),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Text('Call', style: TextStyle(color: AppColors.brass, decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => provider.completeQueueEntry(q.id),
                          child: const Text('Done', style: TextStyle(color: AppColors.textMuted, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ] else ...[
          Text(
            '$activeStaffCount of ${shop.staff.length} barbers on duty · ${shop.chairs} chairs',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newBarberCtrl,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: "Barber's name",
                    hintStyle: const TextStyle(color: AppColors.textFaint),
                    filled: true,
                    fillColor: AppColors.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) {
                    provider.addBarber(newBarberCtrl.text);
                    newBarberCtrl.clear();
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  provider.addBarber(newBarberCtrl.text);
                  newBarberCtrl.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (shop.staff.isEmpty)
            const Text(
              "No barbers on the team yet. Add one above so walk-ins can be assigned.",
              style: TextStyle(color: AppColors.textFaint, fontSize: 13),
            ),
          ...shop.staff.map((b) {
            final onDutyCount = shop.queue.where((q) => q.barber == b.name).length;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            style: TextStyle(
                              color: b.active ? AppColors.text : AppColors.textFaint,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                        Text(
                          b.active ? '$onDutyCount in queue now' : 'Off duty',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: b.active,
                    onChanged: (_) => provider.toggleBarberActive(b.id),
                    activeColor: AppColors.brass,
                  ),
                  GestureDetector(
                    onTap: () => provider.removeBarber(b.id),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('Remove', style: TextStyle(color: AppColors.red, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}