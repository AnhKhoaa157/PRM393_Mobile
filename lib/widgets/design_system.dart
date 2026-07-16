part of '../main.dart';

abstract final class AppColors {
  static const canvas = Color(0xfff6f8fc);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xffeef3f9);
  static const foreground = Color(0xff152033);
  static const muted = Color(0xff66758c);
  static const border = Color(0xffdce5f0);
  static const brand = Color(0xff1769e0);
  static const brandDeep = Color(0xff103b78);
  static const brandSoft = Color(0xffe8f1ff);
  static const success = Color(0xff0c8f62);
  static const successSoft = Color(0xffe3f7ef);
  static const warning = Color(0xffb7791f);
  static const warningSoft = Color(0xfffff5dc);
  static const danger = Color(0xffcc3b4a);
  static const dangerSoft = Color(0xffffeaed);
}

abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 26.0;
  static const pill = 999.0;
}

class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.child, this.padding, this.color});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
      color: color ?? AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: const Color(0x1a0c1f3f),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpace.md), child: child));
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800, color: AppColors.foreground))),
        if (action != null) action!,
      ]);
}

class AppPill extends StatelessWidget {
  const AppPill(this.label, {super.key, this.color = AppColors.brandSoft, this.foreground = AppColors.brand});
  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12)));
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState(
      {super.key, required this.icon, required this.title, this.detail, this.action});
  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppPanel(
      padding: const EdgeInsets.all(AppSpace.xl),
      color: AppColors.surface,
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            height: 56,
            width: 56,
            decoration: const BoxDecoration(color: AppColors.brandSoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.brand, size: 28)),
        const SizedBox(height: AppSpace.sm),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.foreground)),
        if (detail != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(detail!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSpace.md),
          action!,
        ]
      ])));
}

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: .16) : AppColors.brandSoft,
          borderRadius: BorderRadius.circular(15)),
      child: Icon(Icons.local_parking_rounded,
          color: dark ? Colors.white : AppColors.brand, size: 28));
}

enum AppNoticeTone { error, success, info }

void showAppNotice(BuildContext context, Object value,
    {AppNoticeTone tone = AppNoticeTone.error}) {
  final message = value.toString().replaceFirst('Exception: ', '');
  final insufficientBalance =
      message.toLowerCase().contains('số dư ví không đủ');
  final title = insufficientBalance
      ? 'Số dư ví không đủ'
      : switch (tone) {
          AppNoticeTone.success => 'Thành công',
          AppNoticeTone.info => 'Thông báo',
          AppNoticeTone.error => 'Không thể hoàn tất thao tác',
        };
  final detail = insufficientBalance
      ? 'Nạp thêm tiền vào ví rồi thử lại.'
      : message;
  final color = switch (tone) {
    AppNoticeTone.success => AppColors.success,
    AppNoticeTone.info => AppColors.brandDeep,
    AppNoticeTone.error => AppColors.danger,
  };
  final icon = switch (tone) {
    AppNoticeTone.success => Icons.check_circle_outline,
    AppNoticeTone.info => Icons.info_outline,
    AppNoticeTone.error => Icons.error_outline,
  };
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
      duration: const Duration(seconds: 5),
      content: Semantics(
          liveRegion: true,
          label: '$title. $detail',
          child: Container(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.xs, AppSpace.sm),
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x330c1f3f),
                        blurRadius: 18,
                        offset: Offset(0, 8))
                  ]),
              child: Row(children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(detail,
                          style: const TextStyle(color: Color(0xe6ffffff)))
                    ])),
                IconButton(
                    tooltip: 'Đóng thông báo',
                    onPressed: messenger.hideCurrentSnackBar,
                    color: Colors.white,
                    icon: const Icon(Icons.close))
              ])))));
}

Future<Plate?> showVehiclePicker(BuildContext context,
    {required List<Plate> plates,
    required String title,
    required String description}) {
  final listHeight =
      (plates.length * 76.0).clamp(76.0, 304.0).toDouble();
  return showDialog<Plate>(
      context: context,
      builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(AppSpace.lg),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Container(
                          height: 46,
                          width: 46,
                          decoration: const BoxDecoration(
                              color: AppColors.brandSoft,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.directions_car_outlined,
                              color: AppColors.brand)),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                            Text(description,
                                style: const TextStyle(color: AppColors.muted))
                          ])),
                      IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close))
                    ]),
                    const SizedBox(height: AppSpace.md),
                    SizedBox(
                        height: listHeight,
                        child: ListView.separated(
                            itemCount: plates.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: AppSpace.xs),
                            itemBuilder: (context, index) {
                              final plate = plates[index];
                              final motorcycle = plate.type == 'motorcycle';
                              return Semantics(
                                  button: true,
                                  label: 'Choose vehicle ${plate.number}',
                                  child: InkWell(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      onTap: () =>
                                          Navigator.pop(dialogContext, plate),
                                      child: Ink(
                                          height: 68,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpace.sm),
                                          decoration: BoxDecoration(
                                              color: AppColors.surfaceMuted,
                                              borderRadius: BorderRadius.circular(
                                                  AppRadius.sm),
                                              border: Border.all(
                                                  color: AppColors.border)),
                                          child: Row(children: [
                                            Container(
                                                height: 42,
                                                width: 42,
                                                decoration: const BoxDecoration(
                                                    color: AppColors.brandSoft,
                                                    shape: BoxShape.circle),
                                                child: Icon(
                                                    motorcycle
                                                        ? Icons.two_wheeler_outlined
                                                        : Icons.directions_car_outlined,
                                                    color: AppColors.brand)),
                                            const SizedBox(width: AppSpace.sm),
                                            Expanded(
                                                child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                  Text(plate.number,
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w900)),
                                                  Text(motorcycle ? 'Motorcycle' : 'Car',
                                                      style: const TextStyle(
                                                          color: AppColors.muted))
                                                ])),
                                            if (plate.isDefault)
                                              const AppPill('Default',
                                                  color: AppColors.successSoft,
                                                  foreground: AppColors.success),
                                            const SizedBox(width: AppSpace.xs),
                                            const Icon(Icons.chevron_right,
                                                color: AppColors.muted)
                                          ]))));
                            })),
                    const SizedBox(height: AppSpace.sm),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'))
                  ])))));
}
