/// A stream wrapper that buffers events until the first listener subscribes.
///
/// This solves the race where events can be emitted before UI components have a
/// chance to subscribe. Data/error events are buffered, then replayed to the
/// first subscriber before switching to live streaming.
///
/// After the first listener subscribes, this behaves like a standard broadcast
/// stream for all subsequent listeners.
library;

import 'dart:async';

class BufferedEventStream<T> {
  final Stream<T> _source;
  final List<_BufferedEntry<T>> _buffer = [];
  StreamSubscription<T>? _sourceSubscription;
  StreamController<T>? _outputController;
  bool _hasHadListener = false;
  bool _sourceClosedBeforeFirstListener = false;

  BufferedEventStream(this._source) {
    _sourceSubscription = _source.listen(
      (event) => _buffer.add(_BufferedData<T>(event)),
      onError: (error, stackTrace) {
        _buffer.add(_BufferedError<T>(error, stackTrace));
      },
      onDone: () {
        _sourceClosedBeforeFirstListener = true;
      },
    );
  }

  /// Stream that replays buffered events to the first listener, then emits
  /// live events from the source stream.
  Stream<T> get stream {
    _outputController ??= StreamController<T>.broadcast(
      onListen: _onFirstListen,
    );
    return _outputController!.stream;
  }

  void _onFirstListen() {
    if (_hasHadListener) return;
    _hasHadListener = true;

    _sourceSubscription?.cancel();
    _sourceSubscription = null;

    final output = _outputController;
    if (output == null) return;

    for (final entry in _buffer) {
      entry.replayTo(output);
    }
    _buffer.clear();

    if (_sourceClosedBeforeFirstListener) {
      output.close();
      return;
    }

    _sourceSubscription = _source.listen(
      output.add,
      onError: output.addError,
      onDone: output.close,
    );
  }

  /// Dispose all subscriptions/controllers owned by this wrapper.
  void dispose() {
    _sourceSubscription?.cancel();
    _sourceSubscription = null;
    _outputController?.close();
    _outputController = null;
    _buffer.clear();
  }
}

sealed class _BufferedEntry<T> {
  void replayTo(StreamController<T> controller);
}

final class _BufferedData<T> implements _BufferedEntry<T> {
  final T value;

  _BufferedData(this.value);

  @override
  void replayTo(StreamController<T> controller) {
    controller.add(value);
  }
}

final class _BufferedError<T> implements _BufferedEntry<T> {
  final Object error;
  final StackTrace? stackTrace;

  _BufferedError(this.error, this.stackTrace);

  @override
  void replayTo(StreamController<T> controller) {
    controller.addError(error, stackTrace);
  }
}
