import 'dart:async';
import 'package:flutter/material.dart';
import '../models/call_record.dart';
import '../models/persona.dart';
import '../services/call_store.dart';
import '../services/native_bridge.dart';

class DemoCallScreen extends StatefulWidget {
  final DemoPersona persona;

  const DemoCallScreen({super.key, required this.persona});

  @override
  State<DemoCallScreen> createState() => _DemoCallScreenState();
}

class _DemoCallScreenState extends State<DemoCallScreen> with SingleTickerProviderStateMixin {
  bool isRinging = true;
  bool isScreening = false;
  bool isTakenOver = false;
  bool isCallEnded = false;

  final List<TranscriptEntry> transcript = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _ringTimer;
  Timer? _scriptTimer;
  int _currentTurnIndex = 0;
  DateTime? _callStartTime;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _eventSubscription;
  bool _isListeningMic = false;
  String _liveMicBuffer = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial ring vibration
    NativeBridge.instance.vibrate(duration: 600);

    // Auto-screen timer: 5 seconds if user does not click
    _ringTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && isRinging) {
        startAiScreening();
      }
    });

    // Listen to native events (mic recognition, TTS events)
    _eventSubscription = NativeBridge.instance.events.listen((event) {
      final type = event['event'] as String?;
      if (type == 'speech_result') {
        final text = event['text'] as String? ?? '';
        if (text.isNotEmpty) {
          _handleUserLiveSpeech(text);
        }
      } else if (type == 'speech_partial') {
        setState(() {
          _liveMicBuffer = event['text'] as String? ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _scriptTimer?.cancel();
    _pulseController.dispose();
    _scrollController.dispose();
    _eventSubscription?.cancel();
    NativeBridge.instance.stopSpeaking();
    NativeBridge.instance.stopListening();
    super.dispose();
  }

  void startAiScreening() {
    _ringTimer?.cancel();
    setState(() {
      isRinging = false;
      isScreening = true;
      _callStartTime = DateTime.now();
    });

    if (widget.persona.isLiveMic) {
      _startLiveMicMode();
    } else {
      _executeNextScriptTurn();
    }
  }

  void _executeNextScriptTurn() {
    if (_currentTurnIndex >= widget.persona.script.length) {
      _finishCall(status: CallStatus.aiScreened);
      return;
    }

    final turn = widget.persona.script[_currentTurnIndex];
    _scriptTimer = Timer(turn.delay, () {
      if (!mounted || isCallEnded) return;

      setState(() {
        transcript.add(TranscriptEntry(
          speaker: turn.speaker,
          text: turn.text,
        ));
      });

      _scrollToBottom();

      // Speak AI turns aloud
      if (turn.speaker == 'ai') {
        NativeBridge.instance.speak(turn.text, lang: 'hi');
      }

      _currentTurnIndex++;
      _executeNextScriptTurn();
    });
  }

  void _startLiveMicMode() {
    // Initial welcome turn
    final firstTurn = widget.persona.script.first;
    setState(() {
      transcript.add(TranscriptEntry(
        speaker: firstTurn.speaker,
        text: firstTurn.text,
      ));
    });
    NativeBridge.instance.speak(firstTurn.text, lang: 'hi');
    _scrollToBottom();

    // Start mic listening
    Timer(const Duration(seconds: 3), () {
      if (mounted && !isCallEnded) {
        _startListening();
      }
    });
  }

  void _startListening() {
    setState(() {
      _isListeningMic = true;
      _liveMicBuffer = '';
    });
    NativeBridge.instance.startListening();
  }

  void _handleUserLiveSpeech(String spokenText) {
    if (!mounted || isCallEnded) return;

    setState(() {
      _isListeningMic = false;
      _liveMicBuffer = '';
      transcript.add(TranscriptEntry(
        speaker: 'caller',
        text: spokenText,
      ));
    });
    _scrollToBottom();

    // AI dynamic response
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || isCallEnded) return;

      String aiReply = 'Maine aapki baat note kar li hai: "$spokenText". Kripya apna naam aur purpose bataiye.';
      final lower = spokenText.toLowerCase();
      if (lower.contains('delivery') || lower.contains('order') || lower.contains('swiggy') || lower.contains('zomato')) {
        aiReply = 'Theek hai, order doorstep ya guard ke paas rakh dijiye. Thank you!';
      } else if (lower.contains('loan') || lower.contains('card') || lower.contains('offer') || lower.contains('bank')) {
        aiReply = 'Shukriya, par hume koi promotional loan ya card nahi chahiye. Please DND list me update karein.';
      } else if (lower.contains('interview') || lower.contains('job') || lower.contains('hiring')) {
        aiReply = 'Thank you for reaching out! Kripya assessment schedule aur JD email par forward kar dein.';
      }

      setState(() {
        transcript.add(TranscriptEntry(
          speaker: 'ai',
          text: aiReply,
        ));
      });
      NativeBridge.instance.speak(aiReply, lang: 'hi');
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _takeOverCall() {
    _scriptTimer?.cancel();
    NativeBridge.instance.stopSpeaking();
    NativeBridge.instance.stopListening();
    setState(() {
      isScreening = false;
      isTakenOver = true;
      transcript.add(TranscriptEntry(
        speaker: 'user',
        text: 'User ne AI screening se call takeover kar liya.',
      ));
    });
    _scrollToBottom();
  }

  void _declineCall() {
    _ringTimer?.cancel();
    _scriptTimer?.cancel();
    NativeBridge.instance.stopSpeaking();
    NativeBridge.instance.stopListening();

    final record = CallRecord(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      callerName: widget.persona.name,
      callerNumber: widget.persona.number,
      timestamp: DateTime.now(),
      duration: Duration.zero,
      category: widget.persona.category,
      status: CallStatus.declined,
      keyIntent: 'Call declined by user.',
      aiSummary: 'User ne incoming call ko screen hone se pehle decline kar diya.',
      urgency: 'None',
      transcript: [
        TranscriptEntry(speaker: 'user', text: 'Call was rejected.'),
      ],
      isSimulated: true,
    );

    CallStore.instance.addRecord(record);
    Navigator.of(context).pop();
  }

  void _finishCall({required CallStatus status}) {
    _scriptTimer?.cancel();
    NativeBridge.instance.stopSpeaking();
    NativeBridge.instance.stopListening();

    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!)
        : const Duration(seconds: 20);

    final record = CallRecord(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      callerName: widget.persona.name,
      callerNumber: widget.persona.number,
      timestamp: _callStartTime ?? DateTime.now(),
      duration: duration,
      category: widget.persona.category,
      status: status,
      keyIntent: widget.persona.intent,
      aiSummary: 'AI Assistant ne "${widget.persona.tag}" call successfully screen ki. Intent identify kiya gaya aur conversation log generate kiya gaya.',
      urgency: widget.persona.urgency,
      transcript: List.from(transcript),
      isSimulated: true,
    );

    CallStore.instance.addRecord(record);

    setState(() {
      isCallEnded = true;
    });

    _showSummaryDialog(record);
  }

  void _showSummaryDialog(CallRecord record) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Call Screening Completed',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'AI summary & transcript saved',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _buildDetailRow(Icons.label, 'Category', record.category),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.priority_high, 'Urgency', record.urgency),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.lightbulb_outline, 'Key Intent', record.keyIntent),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                record.aiSummary,
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Home (View in Recent Calls)'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.indigo),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: isRinging ? _buildRingingView() : _buildActiveCallView(),
      ),
    );
  }

  Widget _buildRingingView() {
    return Column(
      children: [
        const Spacer(flex: 1),
        const Text(
          'INCOMING CALL',
          style: TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.persona.color.withOpacity(0.2),
              border: Border.all(color: widget.persona.color, width: 3),
            ),
            child: Icon(widget.persona.icon, size: 54, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.persona.name,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          widget.persona.number,
          style: const TextStyle(color: Colors.white60, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Chip(
          backgroundColor: widget.persona.color.withOpacity(0.3),
          label: Text(widget.persona.tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const Spacer(flex: 2),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Assistant auto-screening in 5s...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decline
              Column(
                children: [
                  IconButton.filled(
                    onPressed: _declineCall,
                    icon: const Icon(Icons.call_end, size: 30),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              // AI Screening (Primary Highlighted Action)
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton.filled(
                      onPressed: startAiScreening,
                      icon: const Icon(Icons.auto_mode, size: 36),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('AI Screen Call', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              // Accept personally
              Column(
                children: [
                  IconButton.filled(
                    onPressed: () {
                      _ringTimer?.cancel();
                      setState(() {
                        isRinging = false;
                        isTakenOver = true;
                      });
                    },
                    icon: const Icon(Icons.call, size: 30),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildActiveCallView() {
    return Column(
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.persona.color.withOpacity(0.3),
                child: Icon(widget.persona.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.persona.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      isTakenOver
                          ? 'Call Taken Over by You'
                          : (isScreening ? 'AI Assistant Screening...' : 'Call Ended'),
                      style: TextStyle(
                        color: isTakenOver ? Colors.greenAccent : Colors.indigoAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isScreening)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigoAccent),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, color: Colors.amberAccent, size: 14),
                      SizedBox(width: 4),
                      Text('AI Voice Active', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Animated sound wave or pulse banner
        if (isScreening)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.indigo.withOpacity(0.15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(Icons.graphic_eq, color: Colors.indigoAccent, size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live speech recognition & audio synthesizer enabled',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

        // Live mic buffer if user is speaking
        if (_isListeningMic)
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.teal.withOpacity(0.25),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Colors.tealAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _liveMicBuffer.isEmpty ? 'Listening to your voice...' : _liveMicBuffer,
                    style: const TextStyle(color: Colors.tealAccent, fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Live Transcript Chat Stream
        Expanded(
          child: transcript.isEmpty
              ? const Center(
                  child: Text(
                    'Initializing AI assistant voice bridge...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: transcript.length,
                  itemBuilder: (context, index) {
                    final item = transcript[index];
                    final isAi = item.speaker == 'ai';
                    final isUser = item.speaker == 'user';

                    return Align(
                      alignment: isAi ? Alignment.centerLeft : (isUser ? Alignment.center : Alignment.centerRight),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: isAi
                              ? const Color(0xFF1E293B)
                              : (isUser ? Colors.orange.withOpacity(0.2) : Colors.indigo.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAi
                                ? Colors.indigoAccent.withOpacity(0.4)
                                : (isUser ? Colors.orangeAccent : Colors.teal.withOpacity(0.5)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAi ? Icons.auto_awesome : (isUser ? Icons.person : Icons.phone_in_talk),
                                  size: 14,
                                  color: isAi ? Colors.amberAccent : Colors.tealAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isAi ? 'AI Assistant' : (isUser ? 'You' : widget.persona.name),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isAi ? Colors.amberAccent : Colors.tealAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.text,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              if (isScreening && !isTakenOver) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takeOverCall,
                    icon: const Icon(Icons.phone_forwarded, color: Colors.greenAccent),
                    label: const Text('Take Over', style: TextStyle(color: Colors.greenAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (widget.persona.isLiveMic && isScreening) ...[
                IconButton.filled(
                  onPressed: _isListeningMic ? () => NativeBridge.instance.stopListening() : _startListening,
                  icon: Icon(_isListeningMic ? Icons.mic_off : Icons.mic),
                  style: IconButton.styleFrom(
                    backgroundColor: _isListeningMic ? Colors.red : Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _finishCall(
                    status: isTakenOver ? CallStatus.takenOver : CallStatus.aiScreened,
                  ),
                  icon: const Icon(Icons.call_end),
                  label: const Text('End Call'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
