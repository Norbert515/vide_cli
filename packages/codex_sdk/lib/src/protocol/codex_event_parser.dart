import 'codex_event.dart';
import 'json_rpc_message.dart';

/// Converts [JsonRpcNotification]s from the transport into [CodexEvent]s.
///
/// The transport layer handles JSONL framing and message routing.
/// This parser just maps typed notification objects to domain events.
class CodexEventParser {
  /// Convert a [JsonRpcNotification] into a [CodexEvent].
  CodexEvent parseNotification(JsonRpcNotification notification) {
    return CodexEvent.fromNotification(notification);
  }
}
