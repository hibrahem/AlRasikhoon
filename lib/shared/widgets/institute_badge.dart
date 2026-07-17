import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// Small text badge naming the institute a student belongs to. Text-based
/// (not colour-only) so the affiliation is accessible. Shown wherever a
/// student appears in a cross-institute context — on student cards when a
/// list spans more than one institute (#53), and on the admin's student
/// progress header, where the admin sees students from every institute.
class InstituteBadge extends StatelessWidget {
  final String name;

  const InstituteBadge({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance, size: 12, color: tokens.green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: tokens.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
