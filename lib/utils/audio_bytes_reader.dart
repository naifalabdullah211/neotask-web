/// Platform-aware reader that turns whatever `path` the `record` package
/// returns from `AudioRecorder.stop()` into raw bytes:
///   - Web: `record_web` returns a `blob:` URL — fetchable via `http.get`
///     because blob: URLs are resolvable by the browser's own fetch/XHR
///     within the same page context (standard browser behavior, not a
///     Flutter-specific trick).
///   - Android/IO: `record_android` returns a real filesystem path —
///     read directly via `dart:io`'s `File`.
///
/// Conditional export selects the correct implementation at compile time
/// so neither platform's file ends up importing the other's unavailable
/// API (`dart:io` doesn't exist on Web; `dart:html`/browser fetch
/// semantics don't apply on Android).
library;

export 'audio_bytes_reader_io.dart'
    if (dart.library.html) 'audio_bytes_reader_web.dart';
