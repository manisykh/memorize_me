import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAccountAvatar extends StatelessWidget {
  const GoogleAccountAvatar({super.key, required this.account, required this.radius});

  final GoogleSignInAccount account;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = account.displayName?.trim();
    final source = name != null && name.isNotEmpty ? name : account.email.trim();
    final initial = source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();
    final fallback = Center(
      child: Text(initial, style: TextStyle(
        color: theme.colorScheme.onPrimaryContainer,
        fontSize: radius,
        fontWeight: FontWeight.w700,
      )),
    );
    final photoUrl = account.photoUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: Stack(fit: StackFit.expand, children: [
            fallback,
            if (photoUrl != null && photoUrl.isNotEmpty)
              Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
          ]),
        ),
      ),
    );
  }
}
