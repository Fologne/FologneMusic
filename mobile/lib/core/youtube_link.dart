final _sharedUrl = RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false);
final _trailingPunctuation = RegExp(r'[.,;:!?)\]}]+$');
final _videoId = RegExp(r'^[a-zA-Z0-9_-]{11}$');
const _youtubeHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
};

Uri? youtubeVideoLink(String text) {
  for (final match in _sharedUrl.allMatches(text)) {
    final candidate = match[0]!.replaceFirst(_trailingPunctuation, '');
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasPort) continue;
    try {
      final segments = uri.pathSegments;
      final id = switch (uri.host) {
        'youtu.be' when segments.length == 1 => segments.single,
        final host when _youtubeHosts.contains(host) => switch (segments) {
          ['watch'] => uri.queryParametersAll['v']?.singleOrNull,
          ['shorts', final id] => id,
          _ => null,
        },
        _ => null,
      };
      if (id != null && _videoId.hasMatch(id)) {
        return Uri.https('www.youtube.com', '/watch', {'v': id});
      }
    } on FormatException {
      continue;
    }
  }
  return null;
}
