import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/balance_model.dart';
import '../../services/firestore_service.dart';

class SettlementDraft {
  const SettlementDraft({
    required this.amount,
    required this.note,
    required this.imageBase64,
    required this.imageContentType,
  });

  final double amount;
  final String? note;
  final String? imageBase64;
  final String? imageContentType;
}

class RegisterSettlementDialog extends StatefulWidget {
  const RegisterSettlementDialog({
    super.key,
    required this.settlement,
    required this.currencyFormat,
  });

  final SettlementTransaction settlement;
  final NumberFormat currencyFormat;

  @override
  State<RegisterSettlementDialog> createState() =>
      _RegisterSettlementDialogState();
}

class _RegisterSettlementDialogState extends State<RegisterSettlementDialog> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.settlement.amount % 1 == 0
        ? widget.settlement.amount.toStringAsFixed(0)
        : widget.settlement.amount.toStringAsFixed(2),
  );
  final _noteController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageBase64;
  String? _imageContentType;
  String? _validationMessage;
  bool _isPickingImage = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    if (_isPickingImage) return;
    setState(() {
      _isPickingImage = true;
      _validationMessage = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (!mounted || image == null) return;
      final bytes = await image.readAsBytes().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'No se pudo leer la imagen del dispositivo.',
        ),
      );
      final encodedImage = base64Encode(bytes);
      if (encodedImage.length > FirestoreService.maxChatImageBase64Length) {
        setState(() {
          _imageBytes = null;
          _imageBase64 = null;
          _imageContentType = null;
          _validationMessage =
              'El comprobante comprimido supera los 700 KB. '
              'Recórtalo o selecciona una imagen más liviana.';
        });
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageBase64 = encodedImage;
        final mimeType = image.mimeType;
        _imageContentType = mimeType != null && mimeType.startsWith('image/')
            ? mimeType
            : 'image/jpeg';
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _validationMessage = 'No se pudo adjuntar el comprobante: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _submit() {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _validationMessage = 'Ingresa un monto válido mayor que 0.');
      return;
    }
    if (amount > widget.settlement.amount + 0.01) {
      setState(
        () => _validationMessage =
            'El abono no puede superar la deuda pendiente '
            '(${widget.currencyFormat.format(widget.settlement.amount)}).',
      );
      return;
    }
    if (_noteController.text.trim().length >
        FirestoreService.maxSettlementNoteLength) {
      setState(
        () => _validationMessage =
            'La nota no puede superar '
            '${FirestoreService.maxSettlementNoteLength} caracteres.',
      );
      return;
    }
    Navigator.of(context).pop(
      SettlementDraft(
        amount: amount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        imageBase64: _imageBase64,
        imageContentType: _imageContentType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 21, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3F8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF087F8C),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Registrar pago',
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF173B75),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.settlement.fromName} → ${widget.settlement.toName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF35536D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Deuda pendiente: ${widget.currencyFormat.format(widget.settlement.amount)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF687C8D),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto pagado o abonado',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: const Color(0xFFF3F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: FirestoreService.maxSettlementNoteLength,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Nota (opcional)',
                  hintText: 'Ej. Transferencia del 22 de noviembre',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFFF3F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_imageBytes case final imageBytes?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    imageBytes,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _imageBytes = null;
                      _imageBase64 = null;
                      _imageContentType = null;
                    }),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Quitar comprobante'),
                  ),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _isPickingImage ? null : _pickReceipt,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: const Color(0xFF087F8C),
                    side: const BorderSide(color: Color(0xFFB7DCE8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isPickingImage
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(
                    _isPickingImage
                        ? 'Preparando imagen...'
                        : 'Adjuntar comprobante',
                  ),
                ),
              if (_validationMessage case final validationMessage?) ...[
                const SizedBox(height: 10),
                Text(
                  validationMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFD94E61),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E8),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFF3D7A7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFB27216),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esto solo registra el pago para el grupo. La app no realiza transferencias.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF77551F),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isPickingImage ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2457C5),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Guardar registro'),
        ),
      ],
    );
  }
}
