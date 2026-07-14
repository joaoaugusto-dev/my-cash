import 'package:flutter/material.dart';

import 'package:my_cash/src/domain/models/card_brand.dart';
import 'package:my_cash/src/domain/models/card_recommendation.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_panel.dart';

class SmartCardRecommendation extends StatelessWidget {
  const SmartCardRecommendation({
    super.key,
    required this.cards,
    required this.spentByCardId,
    required this.onViewCards,
    required this.onAddCard,
  });

  final List<CreditCard> cards;
  final Map<String, double> spentByCardId;
  final VoidCallback onViewCards;
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recommended = recommendBestCard(cards, spentByCardId: spentByCardId);

    return SoftPanel(
      padding: const EdgeInsets.all(18),
      tint: colorScheme.secondary.withValues(alpha: 0.07),
      child: recommended == null
          ? _SmartCardEmptyState(onAddCard: onAddCard)
          : LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                final brand = CardBrand.fromApiValue(recommended.brand);
                final gradient = cardGradient(colorFromHex(recommended.color));
                final closing = nextClosingDate(
                  recommended.closingDay,
                  DateTime.now(),
                );
                final closingLabel =
                    '${closing.day.toString().padLeft(2, '0')}/${closing.month.toString().padLeft(2, '0')}';

                final cardPreview = Container(
                  width: isNarrow ? double.infinity : 186,
                  height: 126,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.last.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.credit_card_rounded,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '**** ${recommended.lastDigits}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '* INTELIGÊNCIA MyCash',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Melhor cartão para hoje',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recommended.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Fecha em $closingLabel. Ideal para compras até o fechamento.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                        height: 1.25,
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cardPreview,
                      const SizedBox(height: 18),
                      copy,
                      const SizedBox(height: 14),
                      _LightActionChip(
                        label: 'Ver cartões',
                        onTap: onViewCards,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    cardPreview,
                    const SizedBox(width: 20),
                    Expanded(child: copy),
                    const SizedBox(width: 12),
                    _LightActionChip(label: 'Ver cartões', onTap: onViewCards),
                  ],
                );
              },
            ),
    );
  }
}

class _SmartCardEmptyState extends StatelessWidget {
  const _SmartCardEmptyState({required this.onAddCard});

  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.credit_card_rounded, color: colorScheme.primary, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cadastre um cartão',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Assim indicamos o melhor cartão para usar hoje.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _LightActionChip(label: 'Adicionar', onTap: onAddCard),
      ],
    );
  }
}

class _LightActionChip extends StatelessWidget {
  const _LightActionChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
