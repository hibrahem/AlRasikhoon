import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

/// Guards an online-only action — management writes and Cloud Function calls
/// (docs/superpowers/specs/2026-07-19-offline-mode-design.md §5). These are
/// deliberately NOT queued offline: account creation cannot run without the
/// server, and management edits carry conflict risk a queued session save
/// does not.
///
/// Call at the top of the submit handler:
/// `if (!ensureOnline(context, ref)) return;`
bool ensureOnline(BuildContext context, WidgetRef ref) {
  if (ref.read(isConnectedProvider)) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('هذا الإجراء يتطلب اتصالًا بالإنترنت')),
  );
  return false;
}
