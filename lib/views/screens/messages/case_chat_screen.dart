import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/case_message_service.dart';

void _showConversationInfo(BuildContext context, {String? caseCode}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  caseCode == null ? 'Private messages' : 'Case $caseCode',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              onPressed: () => Navigator.pop(sheetContext),
              tooltip: 'Close details',
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.verified_user_outlined, color: AppColors.teal),
            title: Text('Assigned case only'),
            subtitle: Text(
                'Only the Patient and assigned verified Doctor can read these messages.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_outlined, color: AppColors.teal),
            title: Text('Not continuously monitored'),
            subtitle: Text('For urgent symptoms, seek in-person care.'),
          ),
        ]),
      ),
    ),
  );
}

class CaseConversationsScreen extends StatefulWidget {
  const CaseConversationsScreen({
    super.key,
    required this.isDoctor,
    this.embedded = false,
    this.service,
    this.onOpen,
  });

  final bool isDoctor;
  final bool embedded;
  final CaseMessageService? service;
  final ValueChanged<CaseConversation>? onOpen;

  @override
  State<CaseConversationsScreen> createState() =>
      _CaseConversationsScreenState();
}

class _CaseConversationsScreenState extends State<CaseConversationsScreen> {
  late final service = widget.service ?? CaseMessageService();
  late Future<List<CaseConversation>> conversations = service.conversations();

  void _refresh() => setState(() => conversations = service.conversations());

  @override
  void dispose() {
    if (widget.service == null) service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: FutureBuilder<List<CaseConversation>>(
        future: conversations,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.teal, size: 38),
                        const SizedBox(height: 14),
                        const Text('Conversations are unavailable.'),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ]),
                    )
                  : const CircularProgressIndicator(),
            );
          }
          final rows = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await conversations;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                        widget.isDoctor ? 'Patient conversations' : 'Messages',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton(
                    onPressed: () => _showConversationInfo(context),
                    icon: const Icon(Icons.info_outline_rounded),
                    tooltip: 'Message details',
                  ),
                ]),
                const Text(
                  'Private case messages · not an emergency service',
                  style:
                      TextStyle(color: AppColors.secondaryText, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                      child: Column(children: [
                        const Icon(Icons.forum_outlined,
                            color: AppColors.teal, size: 40),
                        const SizedBox(height: 14),
                        Text('No conversations yet',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          widget.isDoctor
                              ? 'A conversation appears when a Patient assigns a screening to your verified account.'
                              : 'Select a verified Doctor from a screening result to start a private case conversation.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.secondaryText, height: 1.4),
                        ),
                      ]),
                    ),
                  ),
                for (final conversation in rows) ...[
                  _ConversationCard(
                    conversation: conversation,
                    isDoctor: widget.isDoctor,
                    onTap: () async {
                      final open = widget.onOpen;
                      if (open != null) {
                        open(conversation);
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CaseThreadScreen(
                              conversation: conversation,
                              isDoctor: widget.isDoctor,
                            ),
                          ),
                        );
                        if (mounted) _refresh();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Messages')), body: content);
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.isDoctor,
    required this.onTap,
  });

  final CaseConversation conversation;
  final bool isDoctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortCase = (conversation.screeningId.length >= 8
            ? conversation.screeningId.substring(0, 8)
            : conversation.screeningId)
        .toUpperCase();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                  isDoctor
                      ? Icons.folder_shared_outlined
                      : Icons.medical_services_outlined,
                  color: AppColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isDoctor ? 'Case $shortCase' : conversation.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                      conversation.lastMessagePreview ??
                          'Open the private case conversation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 4),
                  Text(conversation.isActive ? 'Active' : 'Closed',
                      style: TextStyle(
                          color: conversation.isActive
                              ? AppColors.teal
                              : AppColors.secondaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondaryText),
          ]),
        ),
      ),
    );
  }
}

class CaseThreadScreen extends StatefulWidget {
  const CaseThreadScreen({
    super.key,
    required this.conversation,
    required this.isDoctor,
    this.embedded = false,
    this.onBack,
    this.service,
  });

  final CaseConversation conversation;
  final bool isDoctor;
  final bool embedded;
  final VoidCallback? onBack;
  final CaseMessageService? service;

  @override
  State<CaseThreadScreen> createState() => _CaseThreadScreenState();
}

class _CaseThreadScreenState extends State<CaseThreadScreen> {
  late final service = widget.service ?? CaseMessageService();
  final composer = TextEditingController();
  final scroll = ScrollController();
  final messages = <CaseMessage>[];
  Timer? refreshTimer;
  bool loading = true;
  bool refreshing = false;
  bool recentLoaded = false;
  bool loadingEarlier = false;
  bool hasEarlier = false;
  bool sending = false;
  late bool active = widget.conversation.isActive;
  String? error;
  String? pendingId;
  String? pendingBody;

  @override
  void initState() {
    super.initState();
    _refresh();
    refreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    composer.dispose();
    scroll.dispose();
    if (widget.service == null) service.close();
    super.dispose();
  }

  void _merge(Iterable<CaseMessage> incoming) {
    final byId = {for (final item in messages) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    messages
      ..clear()
      ..addAll(byId.values);
    messages.sort((a, b) {
      final order = a.createdAt.compareTo(b.createdAt);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  }

  Future<void> _refresh() async {
    if (!mounted || loadingEarlier || refreshing) return;
    refreshing = true;
    try {
      final latest = await service.messages(widget.conversation.assignmentId);
      if (!mounted) return;
      setState(() {
        _merge(latest);
        if (!recentLoaded) hasEarlier = latest.length == 50;
        recentLoaded = true;
        loading = false;
        error = null;
      });
      if (messages.length == latest.length) _scrollToBottom();
    } on CaseMessageException catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception.message;
        if (exception.message.contains('no longer available')) active = false;
      });
    } finally {
      refreshing = false;
    }
  }

  Future<void> _loadEarlier() async {
    if (loadingEarlier || messages.isEmpty) return;
    setState(() => loadingEarlier = true);
    try {
      final page = await service.messages(widget.conversation.assignmentId,
          before: messages.first);
      if (!mounted) return;
      setState(() {
        _merge(page);
        hasEarlier = page.length == 50;
        error = null;
      });
    } on CaseMessageException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loadingEarlier = false);
    }
  }

  Future<void> _send() async {
    final body = composer.text.trim();
    if (!active || sending || body.isEmpty) return;
    final id = pendingBody == body && pendingId != null
        ? pendingId!
        : CaseMessageService.newMessageId();
    setState(() {
      sending = true;
      pendingId = id;
      pendingBody = body;
      error = null;
    });
    try {
      final message = await service.send(widget.conversation.assignmentId, body,
          clientMessageId: id);
      if (!mounted) return;
      setState(() {
        _merge([message]);
        composer.clear();
        pendingId = null;
        pendingBody = null;
      });
      _scrollToBottom();
    } on CaseMessageException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.message;
        if (exception.message.contains('no longer available')) active = false;
      });
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.animateTo(scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screeningId = widget.conversation.screeningId;
    final shortCase =
        (screeningId.length >= 8 ? screeningId.substring(0, 8) : screeningId)
            .toUpperCase();
    final content = SafeArea(
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: AppColors.surface,
          child: Row(children: [
            const CircleAvatar(
              backgroundColor: AppColors.successSoft,
              child: Icon(Icons.shield_outlined, color: AppColors.teal),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    widget.isDoctor
                        ? 'Case $shortCase'
                        : widget.conversation.doctorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(active ? 'Private assigned case' : 'Conversation closed',
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 12)),
              ],
            )),
            IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh messages'),
            IconButton(
                onPressed: () =>
                    _showConversationInfo(context, caseCode: shortCase),
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: 'Case message details'),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    controller: scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      if (hasEarlier)
                        Center(
                            child: TextButton(
                                onPressed: loadingEarlier ? null : _loadEarlier,
                                child: Text(loadingEarlier
                                    ? 'Loading…'
                                    : 'Load earlier messages'))),
                      if (messages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(children: [
                            const Icon(Icons.mark_chat_unread_outlined,
                                size: 38, color: AppColors.teal),
                            const SizedBox(height: 14),
                            Text('Start the conversation',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 7),
                            const Text(
                              'Only the Patient and assigned verified Doctor can read case messages.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ]),
                        ),
                      for (final message in messages)
                        _MessageBubble(message: message),
                    ],
                  ),
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child:
                Text(error!, style: const TextStyle(color: AppColors.danger)),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
              controller: composer,
              enabled: active && !sending,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: active ? 'Write a case message' : 'Messaging closed',
                counterText: '',
                isDense: true,
              ),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: active && !sending ? _send : null,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_upward_rounded),
              tooltip: 'Send message',
            ),
          ]),
        ),
      ]),
    );
    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Case messages')), body: content);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final CaseMessage message;

  @override
  Widget build(BuildContext context) {
    final local = message.createdAt.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment:
          message.senderIsSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
        decoration: BoxDecoration(
          color: message.senderIsSelf ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: message.senderIsSelf
              ? null
              : Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(message.body,
              style: TextStyle(
                  color: message.senderIsSelf ? Colors.white : AppColors.text,
                  height: 1.4)),
          const SizedBox(height: 5),
          Text(time,
              style: TextStyle(
                  fontSize: 11,
                  color: message.senderIsSelf
                      ? Colors.white70
                      : AppColors.secondaryText)),
        ]),
      ),
    );
  }
}
