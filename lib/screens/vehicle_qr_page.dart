part of '../main.dart';

class VehicleQrPage extends StatefulWidget {
  const VehicleQrPage({super.key, required this.session, this.onAddVehicle});
  final SessionController session;
  final VoidCallback? onAddVehicle;

  @override
  State<VehicleQrPage> createState() => _VehicleQrPageState();
}

class _VehicleQrPageState extends State<VehicleQrPage> {
  Plate? selected;
  final _vehicleScrollController = ScrollController();

  List<Plate> get qrPlates => (widget.session.user?.plates ?? const <Plate>[])
      .where((plate) => plate.qrCode.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    final plates = qrPlates;
    if (plates.isNotEmpty) {
      selected =
          plates.firstWhere((plate) => plate.isDefault, orElse: () => plates.first);
    }
  }

  @override
  void dispose() {
    _vehicleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plates = qrPlates;
    return PageFrame(
        title: 'Vehicle QR check-in',
        child: plates.isEmpty ? _emptyState() : _content(plates));
  }

  Widget _emptyState() =>
      ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AppEmptyState(
                    icon: Icons.qr_code_2_outlined,
                    title: 'No vehicle QR available',
                    detail:
                        'Add a license plate to your parking profile to get a gate QR code.',
                    action: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onAddVehicle?.call();
                        },
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Add a vehicle in Profile'))))),
      ]);

  Widget _content(List<Plate> plates) {
    final plate = plates.firstWhere((candidate) => candidate.id == selected?.id,
        orElse: () => plates.first);
    final motorcycle = plate.type == 'motorcycle';
    return ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
      Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (plates.length > 1) ...[
                  Row(children: [
                    const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Choose a vehicle'),
                      SizedBox(height: AppSpace.xxs),
                      Text('Swipe or use the arrows to switch',
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ])),
                    _scrollButton(Icons.chevron_left, 'Show previous vehicles', -1),
                    const SizedBox(width: AppSpace.xxs),
                    _scrollButton(Icons.chevron_right, 'Show more vehicles', 1),
                  ]),
                  const SizedBox(height: AppSpace.xs),
                  SizedBox(
                      height: 64,
                      child: ListView.separated(
                          controller: _vehicleScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: plates.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpace.xs),
                          itemBuilder: (context, index) =>
                              _vehicleChip(plates[index], plate))),
                  const SizedBox(height: AppSpace.md),
                ],
                AppPanel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpace.md),
                          color: AppColors.brandDeep,
                          child: const Row(children: [
                            Icon(Icons.qr_code_scanner_outlined, color: Colors.white),
                            SizedBox(width: AppSpace.sm),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  Text('Gate pass',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16)),
                                  SizedBox(height: AppSpace.xxs),
                                  Text('Ready to scan at the parking entrance',
                                      style: TextStyle(color: Color(0xffd9e8ff), fontSize: 12)),
                                ])),
                            Icon(Icons.verified_outlined, color: Color(0xff8ee7c1)),
                          ])),
                      Padding(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Column(children: [
                            Container(
                                padding: const EdgeInsets.all(AppSpace.sm),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    border: Border.all(color: AppColors.brandSoft, width: 2)),
                                child: QrImageView(data: plate.qrCode, size: 220)),
                            const SizedBox(height: AppSpace.md),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(
                                  motorcycle
                                      ? Icons.two_wheeler_outlined
                                      : Icons.directions_car_outlined,
                                  color: AppColors.brand),
                              const SizedBox(width: AppSpace.xs),
                              Text(plate.number,
                                  style: const TextStyle(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18)),
                              if (plate.isDefault) ...[
                                const SizedBox(width: AppSpace.xs),
                                const AppPill('Default',
                                    color: AppColors.successSoft,
                                    foreground: AppColors.success),
                              ],
                            ]),
                            const SizedBox(height: AppSpace.xxs),
                            Text(motorcycle ? 'Motorcycle' : 'Car',
                                style: const TextStyle(color: AppColors.muted)),
                            const SizedBox(height: AppSpace.md),
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.sm, vertical: AppSpace.xs),
                                decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: const Text(
                                    'Show this code to staff at the gate to identify your vehicle.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.muted, fontSize: 13))),
                          ])),
                    ])),
                const SizedBox(height: AppSpace.xl),
              ])))
    ]);
  }

  Widget _scrollButton(IconData icon, String tooltip, int direction) => Tooltip(
      message: tooltip,
      child: Semantics(
          button: true,
          label: tooltip,
          child: IconButton(
              onPressed: () => _scrollVehicles(direction),
              icon: Icon(icon),
              color: AppColors.brand,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44))));

  void _scrollVehicles(int direction) {
    if (!_vehicleScrollController.hasClients) return;
    final position = _vehicleScrollController.position;
    final target = (position.pixels + (direction * 220))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _vehicleScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _vehicleChip(Plate plate, Plate selectedPlate) {
    final active = plate.id == selectedPlate.id;
    final motorcycle = plate.type == 'motorcycle';
    return Semantics(
        button: true,
        selected: active,
        label: 'Select vehicle ${plate.number}',
        child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => setState(() => selected = plate),
            child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                decoration: BoxDecoration(
                    color: active ? AppColors.brandSoft : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                        color: active ? AppColors.brand : AppColors.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      motorcycle
                          ? Icons.two_wheeler_outlined
                          : Icons.directions_car_outlined,
                      size: 20,
                      color: active ? AppColors.brand : AppColors.muted),
                  const SizedBox(width: AppSpace.xs),
                  Text(plate.number,
                      style: TextStyle(
                          color: active ? AppColors.brand : AppColors.foreground,
                          fontWeight: active ? FontWeight.w900 : FontWeight.w700)),
                  if (plate.isDefault) ...[
                    const SizedBox(width: AppSpace.xs),
                    const AppPill('Default',
                        color: AppColors.successSoft,
                        foreground: AppColors.success),
                  ],
                ]))));
  }
}
