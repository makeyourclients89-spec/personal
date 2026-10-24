import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/call_record.dart';
import '../services/native_bridge.dart';

class CallDetailScreen extends StatelessWidget {
  final CallRecord record;

  const CallDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Details & AI Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Read Summary Aloud',
            onPressed: () {
              NativeBridge.instance.speak(record.aiSummary, lang: 'hi');
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Transcript',
            onPressed: () {
              final buffer = StringBuffer();
              buffer.writeln('Call with: ${record.callerName} (${record.callerNumber})');
              buffer.writeln('Intent: ${record.keyIntent}');
              buffer.writeln('Summary: ${record.aiSummary}');
              buffer.writeln('\n--- Transcript ---');
              for (final t in record.transcript) {
                buffer.writeln('[${t.speaker.toUpperCase()}]: ${t.text}');
              }
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transcript copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.indigo.withOpacity(0.15),
                        child: const Icon(Icons.phone, color: Colors.indigo),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.callerName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              record.callerNumber,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          record.category,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: Colors.indigo.withOpacity(0.1),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCol('Status', record.status.name),
                      _buildInfoCol('Urgency', record.urgency),
                      _buildInfoCol('Duration', '${record.duration.inSeconds}s'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AI Summary Card
          Card(
            color: Colors.indigo.withOpacity(0.05),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.indigo.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.indigo, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AI Generated Call Summary',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    record.aiSummary,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Key Intent: ${record.keyIntent}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Transcript Header
          const Text(
            'Conversation Transcript',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Transcript List
          if (record.transcript.isEmpty)
            const Text('No transcript available for this call.', style: TextStyle(color: Colors.grey))
          else
            ...record.transcript.map((t) {
              final isAi = t.speaker == 'ai';
              final isUser = t.speaker == 'user';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAi
                      ? Colors.indigo.withOpacity(0.08)
                      : (isUser ? Colors.orange.withOpacity(0.08) : Colors.grey.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAi
                        ? Colors.indigo.withOpacity(0.2)
                        : (isUser ? Colors.orange.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAi ? Icons.auto_awesome : (isUser ? Icons.person : Icons.phone_in_talk),
                          size: 14,
                          color: isAi ? Colors.indigo : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAi ? 'AI Assistant' : (isUser ? 'You' : record.callerName),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isAi ? Colors.indigo : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
