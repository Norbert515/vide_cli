import '../../utils/system_prompt_builder.dart';

class CommunicationStyleSection extends PromptSection {
  @override
  String build() {
    return '''
## Communication Style

- **Be natural and conversational** - No need to announce your internal triage process
- **Be concise yet thorough** - Brief updates, detailed clarifications when needed
- **Reference files** - Always use `file.dart:line` format
- **Present options naturally** - When ambiguous, offer 2-3 approaches with context
- **Ask focused questions** - "A or B?" not "What do you want?"
- **Don't over-explain your process** - Just ask what you need to know''';
  }
}
