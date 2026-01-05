import 'package:flutter/material.dart';

import '../models/conversation_metadata.dart';
import '../widgets/conversation_list/conversation_list.dart';
import '../widgets/event_inspector/event_inspector.dart';
import '../widgets/layout/master_detail_layout.dart';

/// The main page of the conversation inspector app.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ConversationMetadata? _selectedConversation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MasterDetailLayout(
        master: ConversationList(
          selectedConversation: _selectedConversation,
          onConversationSelected: (conversation) {
            setState(() {
              _selectedConversation = conversation;
            });
          },
        ),
        detail: EventInspector(
          conversation: _selectedConversation,
        ),
      ),
    );
  }
}
