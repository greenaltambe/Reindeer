import 'package:flutter/material.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/refills/application/pharmacy_store_service.dart';

/// Shows an elderly-friendly modal bottom sheet with direct options to order
/// medicine online or find the nearest government Jan Aushadhi generic store.
Future<void> showBuyMedicineOptionsSheet(
  BuildContext context, {
  required MedicationPlan plan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _BuyMedicineView(plan: plan),
  );
}

class _BuyMedicineView extends StatelessWidget {
  const _BuyMedicineView({required this.plan});

  final MedicationPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final hasSalt = plan.composition.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: scheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasSalt)
                          Text(
                            plan.composition,
                            style: t.bodySmall?.copyWith(color: scheme.outline),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Jan Aushadhi generic savings card (India-focused)
              Card(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings, color: scheme.primary, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('Save 50% to 80% with Jan Aushadhi'),
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasSalt
                            ? trf(
                                'Government Jan Aushadhi stores have the same salt ({n}) at a much lower price.',
                                {'n': plan.composition},
                              )
                            : tr(
                                'Government Jan Aushadhi stores offer genuine generic medicines at up to 80% discount.',
                              ),
                        style: t.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          PharmacyStoreService.openStore(
                            store: PharmacyStore.janAushadhi,
                            query: plan.name,
                            composition: plan.composition,
                          );
                        },
                        icon: const Icon(Icons.location_on_outlined, size: 20),
                        label: Text(tr('Find Jan Aushadhi store near me')),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              Text(
                tr('Order for home delivery:'),
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Store Option: Tata 1mg
              _StoreListTile(
                title: 'Tata 1mg',
                subtitle: tr('Doorstep delivery across India'),
                icon: Icons.local_shipping_outlined,
                badge: tr('Popular'),
                badgeColor: scheme.tertiary,
                onTap: () {
                  PharmacyStoreService.openStore(
                    store: PharmacyStore.tata1mg,
                    query: plan.name,
                    composition: plan.composition,
                  );
                },
              ),
              const SizedBox(height: 8),

              // Store Option: Apollo Pharmacy
              _StoreListTile(
                title: 'Apollo Pharmacy',
                subtitle: tr('Express delivery from Apollo Pharmacy'),
                icon: Icons.local_hospital_outlined,
                badge: tr('Fast'),
                badgeColor: Colors.teal,
                onTap: () {
                  PharmacyStoreService.openStore(
                    store: PharmacyStore.apollo,
                    query: plan.name,
                    composition: plan.composition,
                  );
                },
              ),
              const SizedBox(height: 8),

              // Store Option: Netmeds
              _StoreListTile(
                title: 'Netmeds',
                subtitle: tr('Trusted online chronic medicine pharmacy'),
                icon: Icons.medication_outlined,
                badge: tr('Reliable'),
                badgeColor: Colors.indigo,
                onTap: () {
                  PharmacyStoreService.openStore(
                    store: PharmacyStore.netmeds,
                    query: plan.name,
                    composition: plan.composition,
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),
              Text(
                tr(
                  'Note: Reindeer does not sell medicines directly. Tapping opens the pharmacy search in your browser.',
                ),
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreListTile extends StatelessWidget {
  const _StoreListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: t.labelSmall?.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: t.bodySmall?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: scheme.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
