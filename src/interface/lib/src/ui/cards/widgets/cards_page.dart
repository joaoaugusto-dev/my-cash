import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:my_cash/src/ui/core/widgets/composer_widgets.dart';
import 'package:my_cash/src/domain/models/card_brand.dart';
import 'package:my_cash/src/data/services/cards_api_service.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({
    super.key,
    required this.apiService,
    required this.refreshTrigger,
    this.onCardsChanged,
    this.spentByCardId = const {},
  });

  final CardsApiService apiService;
  final ValueNotifier<int> refreshTrigger;
  final VoidCallback? onCardsChanged;

  /// Estimated amount already spent this month per card id, used to show the
  /// invoice progress bar. Approximates the invoice by calendar month rather
  /// than the exact closing-day cycle — good enough for an at-a-glance view.
  final Map<String, double> spentByCardId;

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late Future<List<CreditCard>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _cardsFuture = widget.apiService.fetchCards();
    widget.refreshTrigger.addListener(_reload);
  }

  @override
  void dispose() {
    widget.refreshTrigger.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _cardsFuture = widget.apiService.fetchCards();
    });
  }

  /// Opens the same composer used to create a card, prefilled for editing.
  /// Deleting only happens from inside this sheet (see [CardComposerSheet]).
  Future<void> _openEditCardSheet(CreditCard card) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RepaintBoundary(
          child: CardComposerSheet(
            existingCard: card,
            onSubmit: (next) => widget.apiService.updateCard(card.id, next),
            onDelete: () => widget.apiService.deleteCard(card.id),
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    _reload();
    widget.onCardsChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'deleted' ? 'Cartão removido.' : 'Cartão atualizado.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      color: colorScheme.secondary,
      child: FutureBuilder<List<CreditCard>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                mediaQuery.padding.top + 96,
                24,
                200,
              ),
              children: [
                Icon(Icons.warning_rounded, size: 56, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível carregar os cartões.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _reload,
                  child: const Text('Tentar novamente'),
                ),
              ],
            );
          }

          final cards = snapshot.data ?? const [];
          if (cards.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                mediaQuery.padding.top + 96,
                24,
                200,
              ),
              children: [
                Icon(
                  Icons.credit_card_off_rounded,
                  size: 64,
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum cartão cadastrado',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toque no + para adicionar seu primeiro cartão.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              mediaQuery.padding.top + 18,
              20,
              200,
            ),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _CardTile(
                card: card,
                spent: widget.spentByCardId[card.id] ?? 0,
                onTap: () => _openEditCardSheet(card),
              );
            },
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.spent, required this.onTap});

  final CreditCard card;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = CardBrand.fromApiValue(card.brand);
    final gradient = cardGradient(colorFromHex(card.color));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  BrandBadge(brand: brand, customLabel: card.brand),
                  const SizedBox(width: 8),
                  // Explicit affordance: the whole tile is tappable to edit,
                  // this chip just makes that discoverable at a glance.
                  Tooltip(
                    message: 'Editar cartão',
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
          Text(
            '••••  ••••  ••••  ${card.lastDigits}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 16),
          _InvoiceUsageBar(spent: spent, limit: card.limitAmount),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _CardInfoLabel(
                  label: 'Limite',
                  value: formatCurrencyBRL(card.limitAmount),
                ),
              ),
              _CardInfoLabel(label: 'Fecha', value: 'dia ${card.closingDay}'),
              const SizedBox(width: 18),
              _CardInfoLabel(label: 'Vence', value: 'dia ${card.dueDay}'),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formats a value as Brazilian currency, e.g. 1234.5 -> "R$ 1.234,50".
String formatCurrencyBRL(double value) {
  final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
  final parts = fixed.split(',');
  final whole = parts[0];
  final groups = <String>[];
  for (var i = whole.length; i > 0; i -= 3) {
    final start = math.max(0, i - 3);
    groups.insert(0, whole.substring(start, i));
  }
  return 'R\$ ${groups.join('.')},${parts[1]}';
}

/// Shows how much of a card's limit is already committed this invoice.
class _InvoiceUsageBar extends StatelessWidget {
  const _InvoiceUsageBar({required this.spent, required this.limit});

  final double spent;
  final double limit;

  @override
  Widget build(BuildContext context) {
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final isNearLimit = ratio >= 0.9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fatura estimada: ${formatCurrencyBRL(spent)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isNearLimit ? Colors.redAccent.shade100 : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            color: isNearLimit ? Colors.redAccent.shade100 : Colors.white,
          ),
        ),
      ],
    );
  }
}

class _CardInfoLabel extends StatelessWidget {
  const _CardInfoLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Brand mark shown on a card: the official SVG logo on a white chip for
/// known bandeiras, or the user-typed name for "Outra".
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.brand, required this.customLabel});

  final CardBrand brand;
  final String customLabel;

  @override
  Widget build(BuildContext context) {
    if (brand.assetPath == null) {
      return Text(
        customLabel.trim().isEmpty ? 'OUTRA' : customLabel.trim().toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      );
    }

    return Container(
      width: 46,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SvgPicture.asset(brand.assetPath!, fit: BoxFit.contain),
    );
  }
}

/// Compact brand mark sized to sit inside a form field's prefix icon slot.
Widget brandFieldIcon(CardBrand brand) {
  if (brand.assetPath == null) {
    return const Icon(Icons.style_rounded);
  }

  // Card logos are designed for a light background (per brand guidelines),
  // so a small white chip keeps them legible in dark mode too — sized like
  // a normal icon so it doesn't tower over the rest of the field.
  // Wrapped in Center: unlike a plain Icon, this chip's fixed size doesn't
  // fill the prefixIcon slot, so without it the field's InputDecorator
  // pins it to the top instead of centering it against the label+value text.
  return Center(
    child: Container(
      width: 42,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SvgPicture.asset(brand.assetPath!, fit: BoxFit.contain),
    ),
  );
}

/// Reveals [child] with a left-to-right wipe whenever [trigger] changes,
/// mimicking a brand being "written" onto the card instead of a hard swap.
class _RevealOnChange extends StatefulWidget {
  const _RevealOnChange({required this.trigger, required this.child});

  final Object trigger;
  final Widget child;

  @override
  State<_RevealOnChange> createState() => _RevealOnChangeState();
}

class _RevealOnChangeState extends State<_RevealOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void didUpdateWidget(covariant _RevealOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.001, 1),
            child: Opacity(opacity: progress, child: child),
          ),
        );
      },
    );
  }
}

/// Live preview of the card being created. The brand mark "writes itself in"
/// whenever the bandeira changes, instead of a jarring hard swap.
class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.brand,
    required this.customBrandLabel,
    required this.nickname,
    required this.lastDigits,
    required this.color,
  });

  final CardBrand brand;
  final String customBrandLabel;
  final String nickname;
  final String lastDigits;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final gradient = cardGradient(color);

    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 30,
              ),
              const Spacer(),
              _RevealOnChange(
                trigger: '${brand.name}-$customBrandLabel',
                child: BrandBadge(brand: brand, customLabel: customBrandLabel),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '••••  ••••  ••••  ${lastDigits.isEmpty ? '••••' : lastDigits}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            nickname.trim().isEmpty
                ? 'MEU CARTÃO'
                : nickname.trim().toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase caption used to break the card form into visual groups.
class _ComposerSectionLabel extends StatelessWidget {
  const _ComposerSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurface.withValues(alpha: 0.55),
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// Preset colors the user can personalize a card with, independent of brand.
/// (hex, label) pairs — mid-tone so [cardGradient]'s lighten-toward-white
/// stays legible against the app's dark theme.
const _cardColorPresets = <(String, String)>[
  ('#7C3AED', 'Roxo'),
  ('#2563EB', 'Azul'),
  ('#0891B2', 'Ciano'),
  ('#16A34A', 'Verde'),
  ('#CA8A04', 'Dourado'),
  ('#EA580C', 'Laranja'),
  ('#DC2626', 'Vermelho'),
  ('#DB2777', 'Rosa'),
  ('#52525B', 'Grafite'),
];

class CardComposerSheet extends StatefulWidget {
  const CardComposerSheet({
    super.key,
    required this.onSubmit,
    this.existingCard,
    this.onDelete,
  });

  final Future<void> Function(CreditCard card) onSubmit;

  /// When set, the sheet opens pre-filled for editing instead of creating.
  final CreditCard? existingCard;

  /// Only meaningful (and shown) when [existingCard] is set — deleting is
  /// only offered from inside the edit sheet, not from the list.
  final Future<void> Function()? onDelete;

  @override
  State<CardComposerSheet> createState() => _CardComposerSheetState();
}

class _CardComposerSheetState extends State<CardComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastDigitsController = TextEditingController();
  final _limitController = TextEditingController();
  final _customBrandController = TextEditingController();
  final _closingDayController = TextEditingController();
  final _dueDayController = TextEditingController();
  late CardBrand _brand;
  late String _colorHex;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isEditing => widget.existingCard != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCard;
    if (existing == null) {
      _brand = CardBrand.visa;
      _colorHex = _cardColorPresets.first.$1;
      return;
    }

    _nameController.text = existing.name;
    _lastDigitsController.text = existing.lastDigits;
    _limitController.text = formatCurrencyBRL(
      existing.limitAmount,
    ).replaceFirst('R\$ ', '');
    _closingDayController.text = existing.closingDay.toString();
    _dueDayController.text = existing.dueDay.toString();
    _brand = CardBrand.fromApiValue(existing.brand);
    if (_brand == CardBrand.outra) {
      _customBrandController.text = existing.brand;
    }
    _colorHex = existing.color;
  }

  Future<void> _pickBrand() async {
    final selected = await showComposerOptionsSheet<CardBrand>(
      context: context,
      title: 'Bandeira',
      selectedValue: _brand,
      options: [
        for (final brand in CardBrand.known)
          SheetOption(
            value: brand,
            label: brand.label,
            icon: Icons.credit_card_rounded,
            leading: BrandBadge(brand: brand, customLabel: brand.label),
          ),
        const SheetOption(
          value: CardBrand.outra,
          label: 'Outra',
          icon: Icons.edit_rounded,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _brand = selected.value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existingCard;
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(
        CreditCard(
          id: existing?.id ?? 'pending',
          userId: existing?.userId ?? 'pending',
          name: _nameController.text.trim(),
          brand: _brand == CardBrand.outra
              ? _customBrandController.text.trim()
              : _brand.label,
          lastDigits: _lastDigitsController.text.trim(),
          limitAmount: parseCurrencyInput(_limitController.text),
          closingDay: int.parse(_closingDayController.text),
          dueDay: int.parse(_dueDayController.text),
          color: _colorHex,
          createdAt: existing?.createdAt ?? '',
          updatedAt: existing?.updatedAt ?? '',
        ),
      );

      if (mounted) Navigator.of(context).pop('saved');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao salvar cartão: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final card = widget.existingCard;
    final onDelete = widget.onDelete;
    if (card == null || onDelete == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover cartão?'),
        content: Text('O cartão "${card.name}" será removido da sua lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await onDelete();
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao remover cartão. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _nameController,
        _lastDigitsController,
        _customBrandController,
      ]),
      builder: (context, _) {
        return ComposerSheetShell(
          title: _isEditing ? 'Editar cartão' : 'Novo cartão',
          subtitle: _isEditing
              ? 'Atualize os dados do seu cartão.'
              : 'Cadastre em segundos, do jeito MyCash.',
          onClose: () => Navigator.of(context).pop(null),
          formKey: _formKey,
          children: [
            CardPreview(
              brand: _brand,
              customBrandLabel: _customBrandController.text,
              nickname: _nameController.text,
              lastDigits: _lastDigitsController.text,
              color: colorFromHex(_colorHex),
            ),
            const SizedBox(height: 20),
            const _ComposerSectionLabel('Estilo'),
            const SizedBox(height: 8),
            ComposerPanel(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final preset in _cardColorPresets)
                    _ColorSwatchButton(
                      hex: preset.$1,
                      label: preset.$2,
                      selected: _colorHex == preset.$1,
                      onTap: () => setState(() => _colorHex = preset.$1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _ComposerSectionLabel('Identificação'),
            const SizedBox(height: 8),
            ComposerPanel(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Apelido do cartão',
                      hintText: 'Ex.: Nubank, Inter, C6...',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Dê um apelido ao cartão'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final brandField = ComposerSelectorField(
                        controller: TextEditingController(text: _brand.label),
                        label: 'Bandeira',
                        hint: 'Selecione',
                        icon: Icons.credit_card_rounded,
                        iconWidget: brandFieldIcon(_brand),
                        onTap: _pickBrand,
                      );
                      final digitsField = TextFormField(
                        controller: _lastDigitsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'Últimos 4 dígitos',
                          counterText: '',
                          prefixIcon: Icon(Icons.pin_rounded),
                        ),
                        validator: (value) =>
                            RegExp(r'^\d{4}$').hasMatch((value ?? '').trim())
                            ? null
                            : 'Informe 4 dígitos',
                      );
                      final brandColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          brandField,
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: _brand == CardBrand.outra
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: TextFormField(
                                      controller: _customBrandController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: const InputDecoration(
                                        labelText: 'Nome da bandeira',
                                        hintText:
                                            'Digite a bandeira do seu cartão',
                                        prefixIcon: Icon(Icons.style_rounded),
                                      ),
                                      validator: (value) =>
                                          _brand == CardBrand.outra &&
                                              (value ?? '').trim().isEmpty
                                          ? 'Informe o nome da bandeira'
                                          : null,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 430) {
                        return Column(
                          children: [
                            brandColumn,
                            const SizedBox(height: 12),
                            digitsField,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: brandColumn),
                          const SizedBox(width: 12),
                          Expanded(child: digitsField),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _ComposerSectionLabel('Limite e datas'),
            const SizedBox(height: 8),
            ComposerPanel(
              child: Column(
                children: [
                  TextFormField(
                    controller: _limitController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Limite total',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    validator: (value) => parseCurrencyInput(value ?? '') <= 0
                        ? 'Informe um limite válido'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final closingField = TextFormField(
                        controller: _closingDayController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: 'Fechamento',
                          hintText: '10',
                          counterText: '',
                          prefixText: 'Dia ',
                          prefixIcon: Icon(Icons.event_busy_rounded),
                        ),
                        validator: _validateDay,
                      );
                      final dueField = TextFormField(
                        controller: _dueDayController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: 'Vencimento',
                          hintText: '17',
                          counterText: '',
                          prefixText: 'Dia ',
                          prefixIcon: Icon(Icons.event_available_rounded),
                        ),
                        validator: _validateDay,
                      );

                      if (constraints.maxWidth < 430) {
                        return Column(
                          children: [
                            closingField,
                            const SizedBox(height: 12),
                            dueField,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: closingField),
                          const SizedBox(width: 12),
                          Expanded(child: dueField),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _isSaving
                    ? const SizedBox(
                        key: ValueKey('saving'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, key: ValueKey('save')),
              ),
              label: Text(
                _isSaving
                    ? 'Salvando...'
                    : (_isEditing ? 'Salvar alterações' : 'Salvar cartão'),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isSaving || _isDeleting ? null : _delete,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                label: Text(
                  'Excluir cartão',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String? _validateDay(String? value) {
    final parsed = int.tryParse(value ?? '');
    return (parsed == null || parsed < 1 || parsed > 31)
        ? 'Dia entre 1 e 31'
        : null;
  }
}

/// A tappable color circle used to pick the card's face color.
class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.hex,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(hex);

    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
