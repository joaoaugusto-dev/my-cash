import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:my_cash/src/domain/models/card_brand.dart';
import 'package:my_cash/src/domain/models/card_recommendation.dart';
import 'package:my_cash/src/ui/cards/widgets/cards_page.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';
import 'package:my_cash/src/domain/models/financial_transaction.dart';
import 'package:my_cash/src/domain/models/installments.dart';
import 'package:my_cash/src/ui/core/widgets/composer_widgets.dart';
import '../../core/widgets/picker_sheet_wrapper.dart';
import '../../core/widgets/wheel_number_picker_grid.dart';

class TransactionComposerSheet extends StatefulWidget {
  const TransactionComposerSheet({
    super.key,
    required this.onSubmit,
    this.cards = const [],
    this.spentByCardId = const {},
  });

  final Future<void> Function(FinancialTransaction transaction) onSubmit;
  final List<CreditCard> cards;
  final Map<String, double> spentByCardId;

  @override
  State<TransactionComposerSheet> createState() =>
      _TransactionComposerSheetState();
}

class _TransactionComposerSheetState extends State<TransactionComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _cardController = TextEditingController();
  CreditCard? _selectedCard;
  final _dateController = TextEditingController();
  final _installmentsController = TextEditingController(text: '1');
  final _customRecurrenceIntervalController = TextEditingController(text: '1');
  final _amountFocusNode = FocusNode();
  FinancialTransactionType _type = FinancialTransactionType.expense;
  _TransactionPaymentMethod? _paymentMethod;
  _TransactionRecurrence _recurrence = _TransactionRecurrence.monthly;
  _CustomRecurrenceUnit _customRecurrenceUnit = _CustomRecurrenceUnit.days;
  DateTime _occurredAt = DateTime.now();
  bool _isRecurring = false;
  bool _isInstallment = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _syncDateText();
    _amountFocusNode.addListener(_syncAmountCursorToEnd);
  }

  List<SheetOption<String>> get _categoryOptions {
    if (_type == FinancialTransactionType.income) {
      return const [
        SheetOption(
          value: 'Salário',
          label: 'Salário',
          icon: Icons.work_rounded,
        ),
        SheetOption(
          value: 'Freelance',
          label: 'Freelance',
          icon: Icons.laptop_mac_rounded,
        ),
        SheetOption(value: 'Vendas', label: 'Vendas', icon: Icons.sell_rounded),
        SheetOption(
          value: 'Reembolso',
          label: 'Reembolso',
          icon: Icons.reply_all_rounded,
        ),
        SheetOption(
          value: 'Investimentos',
          label: 'Investimentos',
          icon: Icons.trending_up_rounded,
        ),
        SheetOption(
          value: 'Outros',
          label: 'Outros',
          icon: Icons.category_rounded,
        ),
      ];
    }

    return const [
      SheetOption(
        value: 'Alimentação',
        label: 'Alimentação',
        icon: Icons.restaurant_rounded,
      ),
      SheetOption(value: 'Moradia', label: 'Moradia', icon: Icons.home_rounded),
      SheetOption(
        value: 'Transporte',
        label: 'Transporte',
        icon: Icons.directions_car_filled_rounded,
      ),
      SheetOption(value: 'Saúde', label: 'Saúde', icon: Icons.favorite_rounded),
      SheetOption(
        value: 'Educação',
        label: 'Educação',
        icon: Icons.school_rounded,
      ),
      SheetOption(value: 'Lazer', label: 'Lazer', icon: Icons.movie_rounded),
      SheetOption(
        value: 'Assinaturas',
        label: 'Assinaturas',
        icon: Icons.subscriptions_rounded,
      ),
      SheetOption(
        value: 'Compras',
        label: 'Compras',
        icon: Icons.shopping_bag_rounded,
      ),
      SheetOption(
        value: 'Outros',
        label: 'Outros',
        icon: Icons.category_rounded,
      ),
    ];
  }

  List<SheetOption<_TransactionPaymentMethod>> get _paymentOptions {
    if (_type == FinancialTransactionType.income) {
      // Money coming in isn't "paid" by debit/credit card — swap those for
      // deposit, which credit/debit have no equivalent of on the expense side.
      return const [
        SheetOption(
          value: _TransactionPaymentMethod.pix,
          label: 'Pix',
          icon: Icons.bolt_rounded,
        ),
        SheetOption(
          value: _TransactionPaymentMethod.transfer,
          label: 'Transferência',
          icon: Icons.compare_arrows_rounded,
        ),
        SheetOption(
          value: _TransactionPaymentMethod.deposit,
          label: 'Depósito',
          icon: Icons.account_balance_rounded,
        ),
        SheetOption(
          value: _TransactionPaymentMethod.cash,
          label: 'Dinheiro',
          icon: Icons.payments_rounded,
        ),
        SheetOption(
          value: _TransactionPaymentMethod.boleto,
          label: 'Boleto',
          icon: Icons.receipt_long_rounded,
        ),
      ];
    }

    return const [
      SheetOption(
        value: _TransactionPaymentMethod.pix,
        label: 'Pix',
        icon: Icons.bolt_rounded,
      ),
      SheetOption(
        value: _TransactionPaymentMethod.debit,
        label: 'Débito',
        icon: Icons.credit_card_rounded,
      ),
      SheetOption(
        value: _TransactionPaymentMethod.credit,
        label: 'Cartão',
        icon: Icons.credit_card_rounded,
      ),
      SheetOption(
        value: _TransactionPaymentMethod.cash,
        label: 'Dinheiro',
        icon: Icons.payments_rounded,
      ),
      SheetOption(
        value: _TransactionPaymentMethod.transfer,
        label: 'Transferência',
        icon: Icons.compare_arrows_rounded,
      ),
      SheetOption(
        value: _TransactionPaymentMethod.boleto,
        label: 'Boleto',
        icon: Icons.receipt_long_rounded,
      ),
    ];
  }

  /// Cards ranked from best to worst to spend on right now (see [rankCards]).
  List<SheetOption<CreditCard>> get _cardOptions {
    final ranked = rankCards(widget.cards, widget.spentByCardId);
    return [
      for (final card in ranked)
        SheetOption(
          value: card,
          label: card.name,
          icon: Icons.credit_card_rounded,
          leading: BrandBadge(
            brand: CardBrand.fromApiValue(card.brand),
            customLabel: card.brand,
          ),
        ),
    ];
  }

  void _syncDateText() {
    _dateController.text =
        '${_occurredAt.day.toString().padLeft(2, '0')}/${_occurredAt.month.toString().padLeft(2, '0')}/${_occurredAt.year}';
  }

  bool get _isCardPayment => _paymentMethod == _TransactionPaymentMethod.credit;

  void _syncAmountCursorToEnd() {
    if (!_amountFocusNode.hasFocus) {
      return;
    }

    final text = _amountController.text;
    _amountController.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _amountFocusNode
      ..removeListener(_syncAmountCursorToEnd)
      ..dispose();
    _categoryController.dispose();
    _paymentMethodController.dispose();
    _cardController.dispose();
    _dateController.dispose();
    _installmentsController.dispose();
    _customRecurrenceIntervalController.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final selected = await _showOptionsSheet<String>(
      title: 'Categoria',
      options: _categoryOptions,
      selectedValue: _categoryController.text.trim(),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _categoryController.text = selected.value;
    });
  }

  Future<void> _pickPaymentMethod() async {
    final selected = await _showOptionsSheet<_TransactionPaymentMethod>(
      title: 'Forma de pagamento',
      options: _paymentOptions,
      selectedValue: _paymentMethod,
    );
    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _paymentMethod = selected.value;
      _paymentMethodController.text = selected.label;
      if (!_isCardPayment) {
        _cardController.clear();
        _selectedCard = null;
        _isInstallment = false;
        _installmentsController.text = '1';
      }
    });
  }

  Future<void> _pickCard() async {
    final selected = await _showOptionsSheet<CreditCard>(
      title: 'Cartão',
      options: _cardOptions,
      selectedValue: _selectedCard,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _selectedCard = selected.value;
      _cardController.text = selected.value.name;
    });
  }

  Future<SheetOption<T>?> _showOptionsSheet<T>({
    required String title,
    required List<SheetOption<T>> options,
    required T? selectedValue,
  }) {
    return showComposerOptionsSheet<T>(
      context: context,
      title: title,
      options: options,
      selectedValue: selectedValue,
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _occurredAt = selected;
      _syncDateText();
    });
  }

  // The field shows "N vezes" instead of a bare number, so every read of
  // its value goes through this instead of int.tryParse on the raw text.
  int _installmentsCount() {
    final match = RegExp(
      r'^\d+',
    ).firstMatch(_installmentsController.text.trim());
    return int.tryParse(match?.group(0) ?? '') ?? 1;
  }

  void _pickInstallments() {
    var picked = _installmentsCount();
    if (picked < 2 || picked > 36) picked = 2;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return RepaintBoundary(
          child: PickerSheetWrapper(
            child: WheelNumberPickerGrid(
              title: 'Número de parcelas',
              values: List.generate(35, (index) => index + 2),
              selectedValue: picked,
              confirmLabel: (value) => 'Selecionar ${value}x',
              onChanged: (value) => picked = value,
              onConfirm: () {
                Navigator.of(ctx).pop();
                setState(() => _installmentsController.text = '$picked vezes');
              },
            ),
          ),
        );
      },
    );
  }

  String _buildSource() {
    if (_paymentMethod == null) {
      return '';
    }

    final paymentLabel = _paymentOptions
        .firstWhere((option) => option.value == _paymentMethod)
        .label;
    if (_isCardPayment && _cardController.text.trim().isNotEmpty) {
      return '$paymentLabel • ${_cardController.text.trim()}';
    }
    return paymentLabel;
  }

  String _buildNotes() {
    final details = <String>[];
    if (_isCardPayment && _isInstallment) {
      details.add('Parcelado em ${_installmentsCount()}x');
    }
    if (_isRecurring) {
      if (_recurrence == _TransactionRecurrence.custom) {
        details.add(
          'Recorrência a cada ${_customRecurrenceIntervalController.text.trim()} ${_customRecurrenceUnit.label.toLowerCase()}',
        );
      } else {
        details.add('Recorrência ${_recurrence.label.toLowerCase()}');
      }
    }
    return details.join(' • ');
  }

  double _parseAmountValue() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return 0;
    }
    return int.parse(digits) / 100;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (final transaction in _buildTransactions()) {
        await widget.onSubmit(transaction);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao salvar lançamento: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// One transaction, or one per installment (each dated a month apart) when
  /// paying by card with parcelas enabled — so future months already show them.
  List<FinancialTransaction> _buildTransactions() {
    final now = DateTime.now().toUtc().toIso8601String();
    final notes = _buildNotes();
    final source = _buildSource();
    final cardId = _isCardPayment ? _selectedCard?.id : null;
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final title = description.isEmpty ? category : description;
    final totalAmount = _parseAmountValue();

    final installmentCount = _isCardPayment && _isInstallment
        ? _installmentsCount()
        : 1;
    final amounts = splitIntoInstallments(totalAmount, installmentCount);

    return [
      for (var i = 0; i < amounts.length; i++)
        FinancialTransaction(
          id: 'pending',
          userId: 'pending',
          title: amounts.length > 1
              ? '$title (${i + 1}/${amounts.length})'
              : title,
          amount: amounts[i],
          type: _type,
          category: category,
          occurredAt: DateTime(
            _occurredAt.year,
            _occurredAt.month + i,
            _occurredAt.day,
          ).toUtc().toIso8601String(),
          notes: notes.isEmpty ? null : notes,
          source: source.isEmpty ? null : source,
          cardId: cardId,
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(
                alpha: isDark ? 0.86 : 0.82,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.outline.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nova transação',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rápido, limpo e no estilo do app.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.62,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          ComposerCloseButton(
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ComposerTypeSwitcher(
                        type: _type,
                        onChanged: (type) {
                          setState(() {
                            _type = type;
                            if (!_categoryOptions.any(
                              (option) =>
                                  option.value ==
                                  _categoryController.text.trim(),
                            )) {
                              _categoryController.clear();
                            }
                            if (_paymentMethod != null &&
                                !_paymentOptions.any(
                                  (option) => option.value == _paymentMethod,
                                )) {
                              _paymentMethod = null;
                              _paymentMethodController.clear();
                              _cardController.clear();
                              _selectedCard = null;
                              _isInstallment = false;
                              _installmentsController.text = '1';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'R\$',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    focusNode: _amountFocusNode,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [CurrencyInputFormatter()],
                                    onTap: _syncAmountCursorToEnd,
                                    textAlign: TextAlign.left,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.8,
                                        ),
                                    decoration: const InputDecoration(
                                      hintText: '0,00',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    validator: (value) {
                                      if (_parseAmountValue() <= 0) {
                                        return 'Informe um valor válido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.calculate_rounded,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 1,
                              color: colorScheme.outline.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 430;
                          final categoryField = ComposerSelectorField(
                            controller: _categoryController,
                            label: 'Categoria',
                            hint: 'Selecione',
                            icon: Icons.sell_rounded,
                            onTap: _pickCategory,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Escolha a categoria';
                              }
                              return null;
                            },
                          );
                          final paymentField = ComposerSelectorField(
                            controller: _paymentMethodController,
                            label: 'Pagamento',
                            hint: 'Selecione',
                            icon: Icons.account_balance_wallet_rounded,
                            onTap: _pickPaymentMethod,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Escolha a forma';
                              }
                              return null;
                            },
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                categoryField,
                                const SizedBox(height: 12),
                                paymentField,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: categoryField),
                              const SizedBox(width: 12),
                              Expanded(child: paymentField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ComposerSelectorField(
                        controller: _dateController,
                        label: 'Data',
                        hint: 'Selecione',
                        icon: Icons.calendar_month_rounded,
                        onTap: _pickDate,
                        trailingIcon: Icons.event_available_rounded,
                      ),
                      const SizedBox(height: 12),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: _isCardPayment
                            ? ComposerPanel(
                                child: Column(
                                  children: [
                                    ComposerSelectorField(
                                      controller: _cardController,
                                      label: 'Cartão',
                                      hint: 'Selecione o cartão',
                                      icon: Icons.credit_card_rounded,
                                      iconWidget: _selectedCard == null
                                          ? null
                                          : brandFieldIcon(
                                              CardBrand.fromApiValue(
                                                _selectedCard!.brand,
                                              ),
                                            ),
                                      onTap: _pickCard,
                                      validator: (value) {
                                        if (_isCardPayment &&
                                            (value ?? '').trim().isEmpty) {
                                          return 'Escolha o cartão';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    ComposerSwitchTile(
                                      title: 'Parcelado',
                                      subtitle:
                                          'Ative para informar as parcelas.',
                                      value: _isInstallment,
                                      onChanged: (value) {
                                        setState(() {
                                          _isInstallment = value;
                                          if (!_isInstallment) {
                                            _installmentsController.text = '1';
                                          } else {
                                            final current =
                                                _installmentsCount();
                                            if (current < 2 || current > 36) {
                                              _installmentsController.text =
                                                  '2 vezes';
                                            }
                                          }
                                        });
                                      },
                                    ),
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      child: _isInstallment
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                top: 12,
                                              ),
                                              child: ComposerSelectorField(
                                                controller:
                                                    _installmentsController,
                                                label: 'Número de parcelas',
                                                hint: 'Selecione',
                                                icon: Icons
                                                    .calendar_view_month_rounded,
                                                onTap: _pickInstallments,
                                                validator: (value) {
                                                  if (!_isInstallment) {
                                                    return null;
                                                  }
                                                  final parsed =
                                                      _installmentsCount();
                                                  if (parsed < 2 ||
                                                      parsed > 36) {
                                                    return 'Escolha entre 2 e 36 parcelas';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      ComposerPanel(
                        child: Column(
                          children: [
                            ComposerSwitchTile(
                              title: 'Recorrente',
                              subtitle:
                                  'Repete automaticamente esse lançamento.',
                              value: _isRecurring,
                              activeColor: colorScheme.primary,
                              onChanged: (value) {
                                setState(() {
                                  _isRecurring = value;
                                });
                              },
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: _isRecurring
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: _ComposerRecurrenceRow(
                                        recurrence: _recurrence,
                                        onChanged: (value) {
                                          setState(() {
                                            _recurrence = value;
                                          });
                                        },
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child:
                                  _isRecurring &&
                                      _recurrence ==
                                          _TransactionRecurrence.custom
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final intervalField = TextFormField(
                                            controller:
                                                _customRecurrenceIntervalController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: const InputDecoration(
                                              labelText: 'A cada',
                                              hintText: '1',
                                            ),
                                            validator: (value) {
                                              if (!_isRecurring ||
                                                  _recurrence !=
                                                      _TransactionRecurrence
                                                          .custom) {
                                                return null;
                                              }
                                              final parsed = int.tryParse(
                                                value ?? '',
                                              );
                                              if (parsed == null ||
                                                  parsed < 1) {
                                                return 'Digite um intervalo';
                                              }
                                              return null;
                                            },
                                          );
                                          final unitField =
                                              _ComposerCustomUnitRow(
                                                unit: _customRecurrenceUnit,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _customRecurrenceUnit =
                                                        value;
                                                  });
                                                },
                                              );

                                          if (constraints.maxWidth < 430) {
                                            return Column(
                                              children: [
                                                intervalField,
                                                const SizedBox(height: 12),
                                                unitField,
                                              ],
                                            );
                                          }

                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: intervalField),
                                              const SizedBox(width: 12),
                                              Expanded(child: unitField),
                                            ],
                                          );
                                        },
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComposerPanel(
                        child: TextFormField(
                          controller: _descriptionController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Descrição (opcional)',
                            hintText:
                                'Ex.: mercado, aluguel, cliente, serviço...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _isSaving
                              ? const SizedBox(
                                  key: ValueKey('saving'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_rounded,
                                  key: ValueKey('save'),
                                ),
                        ),
                        label: Text(
                          _isSaving ? 'Salvando...' : 'Salvar transação',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _TransactionPaymentMethod {
  pix,
  debit,
  credit,
  cash,
  transfer,
  boleto,
  deposit,
}

enum _TransactionRecurrence {
  weekly('Semanal'),
  monthly('Mensal'),
  yearly('Anual'),
  custom('Personalizado');

  const _TransactionRecurrence(this.label);

  final String label;
}

enum _CustomRecurrenceUnit {
  days('Dias'),
  months('Meses'),
  years('Anos');

  const _CustomRecurrenceUnit(this.label);

  final String label;
}

class _ComposerTypeSwitcher extends StatelessWidget {
  const _ComposerTypeSwitcher({required this.type, required this.onChanged});

  final FinancialTransactionType type;
  final ValueChanged<FinancialTransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isIncome = type == FinancialTransactionType.income;

    return Row(
      children: [
        Expanded(
          child: _ComposerTypeButton(
            label: 'Receita',
            icon: Icons.arrow_upward_rounded,
            selected: isIncome,
            accentColor: const Color(0xFF16A34A),
            onTap: () => onChanged(FinancialTransactionType.income),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ComposerTypeButton(
            label: 'Despesa',
            icon: Icons.arrow_downward_rounded,
            selected: !isIncome,
            accentColor: const Color(0xFFEF4444),
            onTap: () => onChanged(FinancialTransactionType.expense),
          ),
        ),
      ],
    );
  }
}

class _ComposerTypeButton extends StatelessWidget {
  const _ComposerTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 58,
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.1)
              : colorScheme.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.9)
                : colorScheme.outline.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? accentColor : colorScheme.onSurface),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? accentColor : colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerRecurrenceRow extends StatelessWidget {
  const _ComposerRecurrenceRow({
    required this.recurrence,
    required this.onChanged,
  });

  final _TransactionRecurrence recurrence;
  final ValueChanged<_TransactionRecurrence> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final options = _TransactionRecurrence.values;
        final isCompact = constraints.maxWidth < 430;

        if (isCompact) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: _ComposerRecurrenceButton(
                    label: option.label,
                    selected: option == recurrence,
                    onTap: () => onChanged(option),
                  ),
                ),
            ],
          );
        }

        return Row(
          children: [
            for (final option in options) ...[
              Expanded(
                child: _ComposerRecurrenceButton(
                  label: option.label,
                  selected: option == recurrence,
                  onTap: () => onChanged(option),
                ),
              ),
              if (option != options.last) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _ComposerCustomUnitRow extends StatelessWidget {
  const _ComposerCustomUnitRow({required this.unit, required this.onChanged});

  final _CustomRecurrenceUnit unit;
  final ValueChanged<_CustomRecurrenceUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Unidade'),
      child: Row(
        children: [
          for (final option in _CustomRecurrenceUnit.values) ...[
            Expanded(
              child: _ComposerMiniChoiceButton(
                label: option.label,
                selected: unit == option,
                onTap: () => onChanged(option),
              ),
            ),
            if (option != _CustomRecurrenceUnit.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ComposerMiniChoiceButton extends StatelessWidget {
  const _ComposerMiniChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surface.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.6)
                : colorScheme.outline.withValues(alpha: 0.35),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerRecurrenceButton extends StatelessWidget {
  const _ComposerRecurrenceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 48,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFF8B2CEB)],
                )
              : null,
          color: selected ? null : colorScheme.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.18)
                : colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
