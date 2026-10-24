import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/call_record.dart';
import '../services/native_bridge.dart';

class CallDetailScreen extends StatefulWidget {
  final CallRecord record;

  const CallDetailScreen({super.key, required this.record});

  @override
  State<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends State<CallDetailScreen> with SingleTickerProviderStateMixin {
  bool isPlayingRecording = false;
  int currentPlayingLineIndex = -1;
  Timer? _playbackTimer;
  double playbackProgress = 0.0;
  Timer? _progressTimer;

  late AnimationController _waveAnimController;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _stopRecordingPlayback();
    _waveAnimController.dispose();
    super.dispose();
  }

  void _startRecordingPlayback() {
    if (widget.record.transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Is call ki koi audio recording transcript uplabdh nahi hai.')),
      );
      return;
    }

    setState(() {
      isPlayingRecording = true;
      currentPlayingLineIndex = 0;
      playbackProgress = 0.0;
    });

    _playTranscriptSequence(0);

    // Progress timer
    final totalDuration = widget.record.duration.inSeconds > 0 ? widget.record.duration.inSeconds : 15;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted || !isPlayingRecording) {
        t.cancel();
        return;
      }
      setState(() {
        playbackProgress += 0.2 / totalDuration;
        if (playbackProgress > 1.0) playbackProgress = 1.0;
      });
    });
  }

  void _playTranscriptSequence(int index) {
    if (!mounted || !isPlayingRecording) return;

    if (index >= widget.record.transcript.length) {
      _stopRecordingPlayback();
      return;
    }

    setState(() {
      currentPlayingLineIndex = index;
    });

    final entry = widget.record.transcript[index];
    NativeBridge.instance.speak(entry.text, lang: 'hi');

    // Estimate speaking duration: roughly 2.5 to 4 seconds per sentence
    final estimatedSeconds = (entry.text.length / 15).clamp(2.5, 5.0).toDouble();
    _playbackTimer?.cancel();
    _playbackTimer = Timer(Duration(milliseconds: (estimatedSeconds * 1000).toInt()), () {
      if (mounted && isPlayingRecording) {
        _playTranscriptSequence(index + 1);
      }
    });
  }

  void _stopRecordingPlayback() {
    _playbackTimer?.cancel();
    _progressTimer?.cancel();
    NativeBridge.instance.stopSpeaking();
    if (mounted) {
      setState(() {
        isPlayingRecording = false;
        currentPlayingLineIndex = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Details & Recording'),
        actions: [
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
                const SnackBar(content: Text('Transcript clipboard par copy ho gaya!')),
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
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                      _buildInfoCol('Status', _getStatusLabel(record.status)),
                      _buildInfoCol('Urgency', record.urgency),
                      _buildInfoCol('Duration', '${record.duration.inSeconds}s'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AUDIO RECORDING PLAYER CARD
          if (record.hasRecording) ...[
            _buildAudioRecordingPlayerCard(record),
            const SizedBox(height: 16),
          ],

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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    record.aiSummary,
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Conversation Transcript',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isPlayingRecording)
                const Row(
                  children: [
                    Icon(Icons.volume_up, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text('Playing audio...', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Transcript List
          if (record.transcript.isEmpty)
            const Text('Is call ka koi transcript nahi hai.', style: TextStyle(color: Colors.grey))
          else
            ...record.transcript.asMap().entries.map((entry) {
              final idx = entry.key;
              final t = entry.value;
              final isAi = t.speaker == 'ai';
              final isUser = t.speaker == 'user';
              final isCurrentlyPlaying = idx == currentPlayingLineIndex;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrentlyPlaying
                      ? Colors.amber.withOpacity(0.2)
                      : (isAi
                          ? Colors.indigo.withOpacity(0.08)
                          : (isUser ? Colors.green.withOpacity(0.08) : Colors.grey.withOpacity(0.08))),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentlyPlaying
                        ? Colors.amber.shade700
                        : (isAi
                            ? Colors.indigo.withOpacity(0.2)
                            : (isUser ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2))),
                    width: isCurrentlyPlaying ? 2 : 1,
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
                          color: isAi ? Colors.indigo : (isUser ? Colors.green : Colors.grey[700]),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAi ? 'AI Assistant' : (isUser ? 'You (Takeover)' : record.callerName),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isAi ? Colors.indigo : (isUser ? Colors.green.shade800 : Colors.grey[800]),
                          ),
                        ),
                        if (isCurrentlyPlaying) ...[
                          const Spacer(),
                          const Icon(Icons.graphic_eq, color: Colors.amber, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.text,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAudioRecordingPlayerCard(CallRecord record) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.withOpacity(0.2)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.red.shade900.withOpacity(0.08), Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Call Audio Recording',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Recorded audio duration: ${record.recordingDuration.inSeconds}s',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Play / Pause Button
                IconButton.filled(
                  onPressed: isPlayingRecording ? _stopRecordingPlayback : _startRecordingPlayback,
                  icon: Icon(isPlayingRecording ? Icons.pause : Icons.play_arrow),
                  style: IconButton.styleFrom(
                    backgroundColor: isPlayingRecording ? Colors.orange : Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Animated Waveform or Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: isPlayingRecording ? playbackProgress : 0.0,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPlayingRecording ? 'Audio Playing (${(playbackProgress * 100).toInt()}%)' : 'Tap play to listen to call recording',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: isPlayingRecording ? Colors.redAccent : Colors.grey[600],
                    fontWeight: isPlayingRecording ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '${record.recordingDuration.inSeconds}s',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(CallStatus status) {
    switch (status) {
      case CallStatus.aiScreened:
        return 'AI Screened';
      case CallStatus.takenOver:
        return 'Taken Over by You';
      case CallStatus.directUser:
        return 'Direct User Call';
      case CallStatus.declined:
        return 'Declined';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.realScreened:
        return 'Real Telephony';
    }
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
