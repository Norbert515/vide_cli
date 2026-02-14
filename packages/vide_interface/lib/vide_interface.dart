/// vide_interface - Shared interface, models, and events for the Vide ecosystem.
///
/// This package defines the canonical types used across all Vide packages:
/// - [VideSession] - Abstract session interface
/// - [VideEvent] hierarchy - Unified event types with serialization
/// - [VideAgent], [VideMessage] - Core models
/// - [ConversationStateManager] - UI state accumulator
///
/// ```dart
/// import 'package:vide_interface/vide_interface.dart';
/// ```
library vide_interface;

// =============================================================================
// Session Interface
// =============================================================================
export 'src/session.dart';
export 'src/session_manager.dart';

// =============================================================================
// Events
// =============================================================================
export 'src/events/vide_event.dart';
export 'src/events/agent_info.dart';

// =============================================================================
// Models
// =============================================================================
export 'src/models/enums.dart';
export 'src/models/filesystem.dart';
export 'src/models/git_status.dart';
export 'src/models/vide_agent.dart';
export 'src/models/vide_config.dart';
export 'src/models/vide_message.dart';
export 'src/models/vide_permission.dart';

// =============================================================================
// State Management
// =============================================================================
export 'src/state/conversation_state.dart';
