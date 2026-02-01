import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'connection_state.freezed.dart';
part 'connection_state.g.dart';

/// Connection status states.
enum ConnectionStatus {
  disconnected,
  testing,
  connected,
  error,
}

/// State for managing server connection.
@freezed
class ConnectionState with _$ConnectionState {
  const factory ConnectionState({
    @Default('localhost') String host,
    @Default(8080) int port,
    @Default(ConnectionStatus.disconnected) ConnectionStatus status,
    String? error,
  }) = _ConnectionState;
}

/// Provider for connection state management.
@riverpod
class ConnectionNotifier extends _$ConnectionNotifier {
  @override
  ConnectionState build() {
    return const ConnectionState();
  }

  void setHost(String host) {
    state = state.copyWith(host: host.trim());
  }

  void setPort(int port) {
    state = state.copyWith(port: port);
  }

  void setPortFromString(String portStr) {
    final port = int.tryParse(portStr);
    if (port != null && port > 0 && port <= 65535) {
      state = state.copyWith(port: port);
    }
  }

  Future<bool> testConnection() async {
    if (state.host.isEmpty) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        error: 'Host is required',
      );
      return false;
    }

    state = state.copyWith(status: ConnectionStatus.testing, error: null);

    try {
      final protocol = state.host.startsWith('localhost') ? 'http' : 'http';
      final url = Uri.parse('$protocol://${state.host}:${state.port}/health');

      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Connection timed out'),
      );

      if (response.statusCode == 200) {
        state = state.copyWith(status: ConnectionStatus.connected);
        return true;
      } else {
        state = state.copyWith(
          status: ConnectionStatus.error,
          error: 'Server returned status ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() {
    state = const ConnectionState();
  }
}
