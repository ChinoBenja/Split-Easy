import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/balance_model.dart';
import 'person_avatar.dart';

class SettlementSuggestionCard extends StatelessWidget {
  const SettlementSuggestionCard({
    super.key,
    required this.settlement,
    required this.currencyFormat,
    required this.memberPhotoUrls,
    this.onRegisterPayment,
    this.showRegisterPayment = true,
    this.isRegistering = false,
  });

  final SettlementTransaction settlement;
  final NumberFormat currencyFormat;
  final Future<Map<String, String>> memberPhotoUrls;
  final VoidCallback? onRegisterPayment;
  final bool showRegisterPayment;
  final bool isRegistering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, String>>(
      future: memberPhotoUrls,
      builder: (context, snapshot) {
        final photoUrls =
            snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError
            ? snapshot.data ?? const <String, String>{}
            : const <String, String>{};
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF7FBFD)],
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFDCE8EF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF173B75).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PAGO SUGERIDO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF087F8C),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFF78A9BB),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Liquidación simple',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF8093A1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  PersonAvatar(
                    name: settlement.fromName,
                    photoSource: photoUrls[settlement.fromUid],
                    radius: 22,
                    backgroundColor: const Color(0xFFE2F0F6),
                    foregroundColor: const Color(0xFF35536D),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settlement.fromName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF173B75),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'paga a',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF8093A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5F4F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Color(0xFF087F8C),
                    ),
                  ),
                  const SizedBox(width: 9),
                  PersonAvatar(
                    name: settlement.toName,
                    photoSource: photoUrls[settlement.toUid],
                    radius: 22,
                    backgroundColor: const Color(0xFFE5F4F2),
                    foregroundColor: const Color(0xFF087F8C),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      settlement.toName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF173B75),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6F5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: Color(0xFF087F8C),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Monto a transferir',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF526879),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      currencyFormat.format(settlement.amount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF087F8C),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (showRegisterPayment) ...[
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isRegistering ? null : onRegisterPayment,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2457C5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: isRegistering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.receipt_long_rounded, size: 18),
                    label: Text(
                      isRegistering
                          ? 'Registrando pago...'
                          : 'Registrar pago o abono',
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Center(
                  child: Text(
                    'Solo queda constancia; no se transfiere dinero desde la app.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF8093A1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
