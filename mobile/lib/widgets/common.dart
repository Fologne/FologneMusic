import 'dart:math' as math;
import 'dart:typed_data';

import '../library/media_library.dart';
import 'playlist_actions.dart';

import '../l10n/localization.dart';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../library/music_controller.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.cover});
  final Widget child;
  final Track? cover;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).scaffoldBackgroundColor;
    final navy = dark == AppColors.background
        ? AppColors.navy
        : const Color(0xFF0B1018);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy, dark],
          stops: [0, .8],
        ),
      ),
      child: cover == null
          ? child
          : Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: FutureBuilder<Uint8List?>(
                      key: ValueKey(cover!.id),
                      future: _loadCover(cover!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        return ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: .23),
                              Colors.transparent,
                            ],
                            stops: const [0, .72],
                          ).createShader(bounds),
                          blendMode: BlendMode.dstIn,
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                child,
              ],
            ),
    );
  }
}

final Map<String, Future<Uint8List?>> _covers = {};
Future<Uint8List?> _loadCover(Track track) {
  final key = '${track.id}:${track.addedAt}';
  final cached = _covers.remove(key);
  if (_covers.length >= 96) _covers.remove(_covers.keys.first);
  return _covers[key] =
      cached ??
      AndroidMediaLibrary.artwork(track.id).catchError((Object _) => null);
}

class CoverArt extends StatefulWidget {
  const CoverArt({super.key, required this.track, this.size = 56});
  final Track track;
  final double size;
  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt> {
  late Future<Uint8List?> bytes;

  @override
  void initState() {
    super.initState();
    bytes = _loadCover(widget.track);
  }

  @override
  void didUpdateWidget(CoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id ||
        oldWidget.track.addedAt != widget.track.addedAt) {
      bytes = _loadCover(widget.track);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.coverArtFor(widget.track.title),
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.size > 100 ? 24 : 12),
      child: SizedBox.square(
        dimension: widget.size,
        child: FutureBuilder<Uint8List?>(
          future: bytes,
          builder: (context, snapshot) {
            final fallback = CustomPaint(
              size: Size.square(widget.size),
              painter: _CoverPainter(widget.track.color, widget.track.style),
            );
            return snapshot.data == null
                ? fallback
                : Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => fallback,
                  );
          },
        ),
      ),
    ),
  );
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.color, this.style);
  final Color color;
  final int style;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [color, const Color(0xFF070D19)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    final glow = Paint()..color = const Color(0xFFD6EBFF).withValues(alpha: .6);
    canvas.drawCircle(
      Offset(size.width * .65, size.height * .29),
      size.width * .12,
      glow,
    );
    for (var i = 0; i < 8; i++) {
      final path = Path()..moveTo(0, size.height * (.52 + i * .07));
      for (var x = 0.0; x <= size.width; x += size.width / 40) {
        final wave = math.sin(x / size.width * math.pi * (style + 1) + i * .5);
        path.lineTo(
          x,
          size.height * (.52 + i * .07) + wave * size.height * .07,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .015,
      );
    }
    canvas.drawLine(
      Offset(size.width * .12, size.height * .15),
      Offset(size.width * .36, size.height * .15),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CoverPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.style != style;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: AppColors.accent),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 20), child: action),
      ],
    ),
  );
}

String durationLabel(num seconds) =>
    '${seconds ~/ 60}:${(seconds.toInt() % 60).toString().padLeft(2, '0')}';

Future<void> _deleteTrack(
  BuildContext context,
  MusicController state,
  Track track,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.deleteFromThisDevice),
      content: Text(context.l10n.deleteFileNotice(track.title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.deleteFile),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  bool deleted;
  try {
    if (!await state.deleteFromDevice(track)) return;
    deleted = true;
  } catch (_) {
    deleted = false;
  }
  if (context.mounted) {
    final message = deleted
        ? context.l10n.trackDeletedFromThisDevice
        : context.l10n.deleteFileFailed;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.trailing,
    this.onLongPress,
  });
  final VoidCallback? onLongPress;
  final Track track;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final state = MusicScope.of(context);
    final selected = state.current?.id == track.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CoverArt(track: track),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? AppColors.accent : AppColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        track.available
            ? context.localizedMessage(track.artist)
            : context.l10n.fileUnavailable,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.muted),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      trailing:
          trailing ??
          PopupMenuButton<String>(
            tooltip: context.l10n.optionsFor(track.title),
            onSelected: (value) {
              if (value == 'favorite') state.toggleFavorite(track);
              if (value == 'playlist') addTracksToPlaylist(context, [track]);
              if (value == 'delete') _deleteTrack(context, state, track);
              if (value == 'info') {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(track.title),
                    content: Text(
                      '${context.localizedMessage(track.artist)}\n${context.localizedMessage(track.album)}\n${durationLabel(track.seconds)}\n\n${track.folder}\n${track.available ? context.l10n.localFile : context.l10n.fileUnavailable}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.close),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'favorite',
                child: Text(
                  state.favorites.contains(track.id)
                      ? context.l10n.removeFromFavorites
                      : context.l10n.addToFavorites,
                ),
              ),
              PopupMenuItem(
                value: 'playlist',
                child: Text(context.l10n.addToPlaylist),
              ),
              PopupMenuItem(value: 'info', child: Text(context.l10n.details)),
              if (track.available)
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.l10n.deleteFromDevice),
                ),
            ],
          ),
    );
  }
}
