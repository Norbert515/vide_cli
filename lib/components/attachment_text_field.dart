import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:claude_api/claude_api.dart';
import 'package:path/path.dart' as path;
import 'package:vide_cli/constants/text_opacity.dart';

/// A text field that automatically detects image paths, converts them to attachments,
/// and provides a complete Message object on submit.
///
/// Features:
/// - Automatic path detection (handles escaped/unescaped paths)
/// - Placeholder management (replaces paths with [Image #N])
/// - Deletion handling (removes attachments when placeholders are deleted)
/// - Visual feedback (shows attached images above the text field)
/// - Clean output (strips placeholders from final message text)
class AttachmentTextField extends StatefulComponent {
  final bool enabled;
  final bool focused;
  final String? placeholder;
  final void Function(Message message)? onSubmit;
  final void Function(List<Attachment> attachments)? onAttachmentsChanged;
  final Component? agentTag;

  /// Called when Escape is pressed and the text field is empty.
  final void Function()? onEscape;

  /// Called when the text content changes (for idle detection, etc.)
  final void Function(String text)? onChanged;

  const AttachmentTextField({
    this.enabled = true,
    this.focused = true,
    this.placeholder,
    this.onSubmit,
    this.onAttachmentsChanged,
    this.agentTag,
    this.onEscape,
    this.onChanged,
    super.key,
  });

  @override
  State<AttachmentTextField> createState() => _AttachmentTextFieldState();
}

class _AttachmentTextFieldState extends State<AttachmentTextField> {
  late final _AttachmentTextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _AttachmentTextEditingController();
    _controller.onAttachmentsChanged = (attachments) {
      setState(() {}); // Rebuild to show attachment indicators
      component.onAttachmentsChanged?.call(attachments);
    };
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    component.onChanged?.call(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();

    if (text.isEmpty && _controller.attachments.isEmpty) {
      return;
    }

    // Replace placeholders with actual content
    var finalText = text;
    final imageAttachments = <Attachment>[];

    // Process attachments in reverse order to maintain correct indices
    for (var i = _controller.attachments.length - 1; i >= 0; i--) {
      final attachment = _controller.attachments[i];

      if (attachment.type == 'document' && attachment.content != null) {
        // Replace text content placeholder with actual content inline
        final placeholder = '[Pasted Content #${i + 1}]';
        finalText = finalText.replaceAll(placeholder, attachment.content!);
      } else if (attachment.type == 'image') {
        // Keep image attachments and remove their placeholders
        imageAttachments.insert(0, attachment);
        final placeholder = '[Image #${i + 1}]';
        finalText = finalText.replaceAll(placeholder, '');
      }
    }

    finalText = finalText.trim();
    final messageText = finalText.isEmpty && imageAttachments.isNotEmpty ? 'Attached image(s)' : finalText;

    final message = Message(text: messageText, attachments: imageAttachments.isEmpty ? null : imageAttachments);

    component.onSubmit?.call(message);

    // Clear
    _controller.clearAttachments();
    _controller.clear();
  }

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: component.focused,
      onKeyEvent: (event) {
        // Check for Escape
        if (event.logicalKey == LogicalKey.escape) {
          // If we have text or attachments, clear them and consume the event
          if (_controller.text.isNotEmpty || _controller.attachments.isNotEmpty) {
            _controller.clearAttachments();
            _controller.clear();
            setState(() {});
            return true;
          }
          // Call the callback for external handling (e.g., abort)
          component.onEscape?.call();
          return true;
        }

        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachments row
          if (_controller.attachments.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
              child: Row(
                children: [
                  for (var i = 0; i < _controller.attachments.length; i++) ...[
                    Text(
                      _controller.attachments[i].type == 'image'
                          ? '📎 ${path.basename(_controller.attachments[i].path ?? "image")}'
                          : '📎 Pasted content (${_controller.attachments[i].content?.length ?? 0} chars)',
                      style: TextStyle(color: Colors.white.withOpacity(TextOpacity.secondary)),
                    ),
                    if (i < _controller.attachments.length - 1) SizedBox(width: 2),
                  ],
                ],
              ),
            ),

          // Text field
          Container(
            padding: EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(border: BoxBorder.all(color: Colors.grey)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agent tag (if provided)
                if (component.agentTag != null) ...[component.agentTag!, SizedBox(width: 1)],
                Text('>', style: TextStyle(color: Colors.white)),
                SizedBox(width: 1),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: component.enabled,
                    focused: component.focused,
                    cursorBlinkRate: null,
                    maxLines: null,
                    style: TextStyle(color: Colors.white),
                    placeholder: component.placeholder ?? 'Type a message...',
                    placeholderStyle: TextStyle(color: Colors.white.withOpacity(TextOpacity.tertiary)),
                    onPaste: _controller.handlePaste,
                    onSubmitted: (_) {
                      _handleSubmit();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom TextEditingController that manages attachments and text updates natively
class _AttachmentTextEditingController extends TextEditingController {
  final List<Attachment> attachments = [];
  final Map<int, String> _placeholderToPath = {};
  final Map<int, String> _placeholderToContent = {}; // Store full text content
  bool _isInternalUpdate = false; // Flag to prevent recursive updates
  static const _longTextThreshold = 500; // Characters

  void Function(List<Attachment>)? onAttachmentsChanged;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  set text(String newText) {
    // If this is an internal update (we're setting the text ourselves), just update directly
    if (_isInternalUpdate) {
      super.text = newText;
      return;
    }

    // Check for placeholder deletions on normal text changes
    _handlePlaceholderDeletion(newText);
    super.text = newText;
  }

  /// Handle pasted text - runs image path detection only on paste events.
  /// Returns `true` if the paste was handled (suppress default insertion),
  /// `false` to let TextField handle normal paste.
  bool handlePaste(String pastedText) {
    final trimmedText = pastedText.trim();

    // Try to extract image path(s) from pasted text
    final imagePath = _extractImagePath(trimmedText);
    if (imagePath != null) {
      _addAttachment(imagePath);
      return true; // Handled - don't insert the path, it's been converted to attachment
    }

    // Check if pasted text is long content that should become an attachment
    if (pastedText.length > _longTextThreshold) {
      _addTextAttachment(pastedText);
      return true; // Handled
    }

    // Normal paste - let TextField handle it
    return false;
  }

  /// Extract an image path from pasted text.
  /// Handles escaped paths (with `\ ` for spaces) and finds paths ending in image extensions.
  /// Returns null if no valid image path found.
  String? _extractImagePath(String text) {
    // Quick check: does this even contain an image extension?
    final lower = text.toLowerCase();
    if (!lower.contains('.png') &&
        !lower.contains('.jpg') &&
        !lower.contains('.jpeg') &&
        !lower.contains('.gif') &&
        !lower.contains('.webp')) {
      return null;
    }

    // Try the whole text first (common case: single path pasted)
    if (_couldBeImagePath(text)) {
      if (_isImagePath(text)) {
        return text;
      }
    }

    // Find image extensions and work backwards to find the path start
    final extensionPatterns = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];

    for (final ext in extensionPatterns) {
      var searchStart = 0;
      while (true) {
        final extIndex = lower.indexOf(ext, searchStart);
        if (extIndex == -1) break;

        // Find the end of this path (extension + possible trailing chars)
        final pathEnd = extIndex + ext.length;

        // Find the start of this path (look for / or start of string)
        // Account for escaped spaces by looking for unescaped whitespace or start
        var pathStart = extIndex;
        while (pathStart > 0) {
          final char = text[pathStart - 1];
          // Check for unescaped whitespace (path boundary)
          if (char == ' ' || char == '\t' || char == '\n') {
            // Check if it's escaped
            if (pathStart >= 2 && text[pathStart - 2] == '\\') {
              // Escaped space, continue searching
              pathStart--;
            } else {
              // Unescaped whitespace = path boundary
              break;
            }
          } else {
            pathStart--;
          }
        }

        final candidatePath = text.substring(pathStart, pathEnd).trim();

        // Validate this candidate
        if (_couldBeImagePath(candidatePath) && _isImagePath(candidatePath)) {
          return candidatePath;
        }

        // Continue searching after this extension
        searchStart = pathEnd;
      }
    }

    return null;
  }

  /// Add an image attachment from a path, replacing text with placeholder
  void _addAttachment(String imagePath) {
    final unescapedPath = _unescapePath(imagePath.trim());

    // Check for duplicates
    final isDuplicate = attachments.any((attachment) => attachment.path == unescapedPath);
    if (isDuplicate) {
      return; // Don't add duplicate, don't modify text
    }

    final index = attachments.length;
    final placeholder = '[Image #${index + 1}]';

    attachments.add(Attachment.image(unescapedPath));
    _placeholderToPath[index] = imagePath;

    // Insert placeholder at cursor position
    final currentText = text;
    final cursorPos = selection.baseOffset;
    final newText = currentText.substring(0, cursorPos) + placeholder + currentText.substring(cursorPos);

    _isInternalUpdate = true;
    super.text = newText;
    selection = TextSelection.collapsed(offset: cursorPos + placeholder.length);
    _isInternalUpdate = false;

    onAttachmentsChanged?.call(attachments);
  }

  /// Add a text content attachment, replacing text with placeholder
  void _addTextAttachment(String content) {
    final index = attachments.length;
    final placeholder = '[Pasted Content #${index + 1}]';

    attachments.add(Attachment.documentText(text: content));
    _placeholderToContent[index] = content;

    // Insert placeholder at cursor position
    final currentText = text;
    final cursorPos = selection.baseOffset;
    final newText = currentText.substring(0, cursorPos) + placeholder + currentText.substring(cursorPos);

    _isInternalUpdate = true;
    super.text = newText;
    selection = TextSelection.collapsed(offset: cursorPos + placeholder.length);
    _isInternalUpdate = false;

    onAttachmentsChanged?.call(attachments);
  }

  void _handlePlaceholderDeletion(String currentText) {
    final existingPlaceholders = <int>[];

    for (var i = 0; i < attachments.length; i++) {
      final isImage = attachments[i].type == 'image';
      final placeholder = isImage ? '[Image #${i + 1}]' : '[Pasted Content #${i + 1}]';
      if (currentText.contains(placeholder)) {
        existingPlaceholders.add(i);
      }
    }

    if (existingPlaceholders.length != attachments.length) {
      final newAttachments = <Attachment>[];
      final newPlaceholderToPath = <int, String>{};
      final newPlaceholderToContent = <int, String>{};

      for (var i = 0; i < attachments.length; i++) {
        if (existingPlaceholders.contains(i)) {
          newAttachments.add(attachments[i]);
          final newIndex = newAttachments.length - 1;
          if (_placeholderToPath.containsKey(i)) {
            newPlaceholderToPath[newIndex] = _placeholderToPath[i]!;
          }
          if (_placeholderToContent.containsKey(i)) {
            newPlaceholderToContent[newIndex] = _placeholderToContent[i]!;
          }
        }
      }

      attachments.clear();
      attachments.addAll(newAttachments);
      _placeholderToPath.clear();
      _placeholderToPath.addAll(newPlaceholderToPath);
      _placeholderToContent.clear();
      _placeholderToContent.addAll(newPlaceholderToContent);

      // Renumber placeholders
      var updatedText = currentText;
      for (var i = 0; i < attachments.length; i++) {
        final isImage = attachments[i].type == 'image';
        final oldPattern = isImage ? RegExp(r'\[Image #\d+\]') : RegExp(r'\[Pasted Content #\d+\]');
        if (oldPattern.hasMatch(updatedText)) {
          final newPlaceholder = isImage ? '[Image #${i + 1}]' : '[Pasted Content #${i + 1}]';
          updatedText = updatedText.replaceFirst(oldPattern, newPlaceholder);
        }
      }

      if (updatedText != currentText) {
        _isInternalUpdate = true;
        super.text = updatedText;
        selection = TextSelection.collapsed(offset: updatedText.length);
        _isInternalUpdate = false;
      }

      onAttachmentsChanged?.call(attachments);
    }
  }

  String _unescapePath(String path) {
    return path.replaceAll(r'\ ', ' ').replaceAll(r'\(', '(').replaceAll(r'\)', ')');
  }

  /// Fast pre-check: could this string possibly be an image path?
  /// This uses only string operations - NO filesystem access.
  bool _couldBeImagePath(String text) {
    if (text.isEmpty || text.length > 2000) return false;

    // Unescape first to check the actual path
    final cleanPath = _unescapePath(text.trim());
    if (cleanPath.isEmpty) return false;

    // Must start with / (absolute), ~ (home), or . (relative)
    final firstChar = cleanPath[0];
    if (firstChar != '/' && firstChar != '~' && firstChar != '.') {
      return false;
    }

    // Must have an image extension
    final lower = cleanPath.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  /// Check if text is a valid image file path.
  /// Only call this AFTER _couldBeImagePath returns true to avoid unnecessary I/O.
  bool _isImagePath(String filePath) {
    final cleanPath = _unescapePath(filePath.trim());

    // Double-check extension (defensive)
    final ext = cleanPath.toLowerCase();
    final hasImageExtension = ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp');

    if (!hasImageExtension) return false;

    // Single filesystem check
    return File(cleanPath).existsSync();
  }

  void clearAttachments() {
    attachments.clear();
    _placeholderToPath.clear();
    _placeholderToContent.clear();
    onAttachmentsChanged?.call(attachments);
  }
}
