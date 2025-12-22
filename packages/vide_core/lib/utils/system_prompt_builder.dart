/// Abstract base class for prompt sections
abstract class PromptSection {
  String build();
}

/// Builder class for composing system prompts from modular sections
class SystemPromptBuilder {
  final List<PromptSection> _sections = [];

  SystemPromptBuilder addSection(PromptSection section) {
    _sections.add(section);
    return this;
  }

  String build() {
    return _sections.map((s) => s.build()).join('\n\n');
  }
}
