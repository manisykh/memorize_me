import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_settings_provider.dart';
import '../services/api_key_service.dart';
import '../themes/memorize_identity.dart';

class AiConnectionBar extends StatefulWidget {
  final Future<void> Function() onChange;

  const AiConnectionBar({super.key, required this.onChange});

  @override
  State<AiConnectionBar> createState() => _AiConnectionBarState();
}

class _AiConnectionBarState extends State<AiConnectionBar> {
  bool? _connected;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final provider = context.read<AiSettingsProvider>().selectedProvider;
    final key = await ApiKeyService().getApiKey(provider);
    if (mounted) setState(() => _connected = key?.trim().isNotEmpty == true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final settings = context.watch<AiSettingsProvider>();
    final connected = _connected == true;
    final color = connected ? const Color(0xFF19B77A) : theme.colorScheme.error;

    return Material(
      color: identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(color: identity.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        onTap: () async {
          await widget.onChange();
          await _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  connected
                      ? '${settings.selectedProvider.shortLabel} · ${settings.selectedModel}'
                      : '${settings.selectedProvider.shortLabel} 연결 필요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: connected ? const Color(0xFF176A59) : color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '변경',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiDisclosureRow extends StatelessWidget {
  final String summary;
  final String detail;
  final bool expanded;
  final VoidCallback onTap;

  const AiDisclosureRow({
    super.key,
    required this.summary,
    required this.detail,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Material(
      color: identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(color: identity.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle,
                    size: 19,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: expanded ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '자세히',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
