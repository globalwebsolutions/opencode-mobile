import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/models.dart';

/// A user message, rendered as a right-aligned bubble (chat style),
/// including any attached images.
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.message});

  final OcMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = (message.text ?? '').trim().isNotEmpty;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.14),
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(20),
            topEnd: Radius.circular(20),
            bottomStart: Radius.circular(20),
            bottomEnd: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.files.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: hasText ? 8 : 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final file in message.files)
                      if (file.isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 260,
                              maxHeight: 260,
                            ),
                            child: Image.memory(
                              base64Decode(file.dataBase64),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox
                                  .shrink(),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            if (hasText)
              SelectionArea(
                child: Text(
                  message.text!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
