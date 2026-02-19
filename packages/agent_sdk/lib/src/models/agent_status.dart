/// Processing status of the underlying AI coding agent.
enum AgentProcessingStatus {
  /// Agent is idle and ready for input.
  ready,

  /// Agent is processing the request.
  processing,

  /// Agent is in the thinking phase (extended thinking).
  thinking,

  /// Agent is generating output.
  responding,

  /// Agent finished the current operation.
  completed,

  /// Agent encountered an error.
  error,

  /// Status not recognized (forward compatibility).
  unknown,
}
