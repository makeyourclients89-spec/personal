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
  // Call States
  bool isRinging = true;
  bool isScreening = false;
  bool isTakenOver = false;
  bool isDirectUser = false;
  bool isCallEnded = false;

  // 10-Second Countdown
  int countdownSeconds = 10;
  Timer? _countdownTimer;

  // Active call timers & state
  final List<TranscriptEntry> transcript = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _scriptTimer;
  Timer? _callDurationTimer;
  int _callElapsedSeconds = 0;
  int _currentTurnIndex = 0;
  DateTime? _callStartTime;

  String liveAiSummary = 'Call shuru hone par AI live summary banayega...';

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
    NativeBridge.instance.vibrate(duration: 500);

    // Start 10-second auto-takeover countdown
    _startCountdown();

    // Listen to native speech events
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

  void _startCountdown() {
    countdownSeconds = 10;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !isRinging) {
        timer.cancel();
        return;
      }

      setState(() {
        if (countdownSeconds > 1) {
          countdownSeconds--;
          NativeBridge.instance.vibrate(duration: 80);
        } else {
          // 10 seconds expired: AI automatically takes over!
          countdownSeconds = 0;
          timer.cancel();
          _onCountdownTimeoutAutoTakeover();
        }
      });
    });
  }

  void _onCountdownTimeoutAutoTakeover() {
    NativeBridge.instance.speak('10 seconds complete. AI Assistant taking over call.', lang: 'en');
    startAiScreening(autoTriggered: true);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scriptTimer?.cancel();
    _callDurationTimer?.cancel();
    _pulseController.dispose();
    _scrollController.dispose();
    _eventSubscription?.cancel();
    NativeBridge.instance.stopSpeaking();
    NativeBridge.instance.stopListening();
    super.dispose();
  }

  void _startCallDurationTracker() {
    _callStartTime = DateTime.now();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || isCallEnded) {
        t.cancel();
        return;
      }
      setState(() {
        _callElapsedSeconds++;
      });
    });
  }

  void _acceptPersonally() {
    _countdownTimer?.cancel();
    _startCallDurationTracker();

    setState(() {
      isRinging = false;
      isDirectUser = true;
      isScreening = false;
      isTakenOver = false;
      liveAiSummary = 'User ne call 10s ke andar directly pick kar li. Recording chalu hai.';
      transcript.add(TranscriptEntry(
        speaker: 'user',
        text: 'Aapne call directly connect kar li (User Picked Up).',
      ));
    });

    // Start caller persona dialogue
    _executeNextScriptTurn();
  }

  void startAiScreening({bool autoTriggered = false}) {
    _countdownTimer?.cancel();
    _startCallDurationTracker();

    setState(() {
      isRinging = false;
      isScreening = true;
      isDirectUser = false;
      liveAiSummary = autoTriggered
          ? '10s me pick na hone par AI ne automatically call takeover kar li.'
          : 'User ne AI Call Screening activate ki.';
    });

    if (widget.persona.isLiveMic) {
      _startLiveMicMode();
    } else {
      _executeNextScriptTurn();
    }
  }

  void _executeNextScriptTurn() {
    if (_currentTurnIndex >= widget.persona.script.length) {
      _finishCall(
        status: isTakenOver
            ? CallStatus.takenOver
            : (isDirectUser ? CallStatus.directUser : CallStatus.aiScreened),
      );
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
        _updateLiveSummary(turn);
      });

      _scrollToBottom();

      // Speak AI turns aloud if in AI mode
      if (turn.speaker == 'ai' && !isTakenOver && !isDirectUser) {
        NativeBridge.instance.speak(turn.text, lang: 'hi');
      } else if (turn.speaker == 'caller') {
        // Speak caller line if user is directly on call or taken over
        if (isDirectUser || isTakenOver) {
          NativeBridge.instance.speak(turn.text, lang: 'hi');
        }
      }

      _currentTurnIndex++;
      _executeNextScriptTurn();
    });
  }

  void _updateLiveSummary(ScriptTurn turn) {
    if (turn.speaker == 'caller') {
      final t = turn.text.toLowerCase();
      if (t.contains('swiggy') || t.contains('delivery') || t.contains('flat') || t.contains('guard')) {
        liveAiSummary = 'Live Summary: Delivery partner gate par khada hai, parcel handover request ki gayi.';
      } else if (t.contains('bank') || t.contains('credit card') || t.contains('card') || t.contains('offer')) {
        liveAiSummary = 'Live Summary: Bank marketing call detect hui (Credit card offer).';
      } else if (t.contains('recruitment') || t.contains('google') || t.contains('interview')) {
        liveAiSummary = 'Live Summary: Flutter Lead interview schedule ke regarding HR call hai.';
      } else if (t.contains('lottery') || t.contains('inaam') || t.contains('account')) {
        liveAiSummary = 'Live Summary: Fraud/Lottery scam detect hua! Verification attempt alert.';
      }
    } else if (turn.speaker == 'ai') {
      if (turn.text.contains('DND')) {
        liveAiSummary += ' AI ne offer decline karke DND add karne ko kaha.';
      } else if (turn.text.contains('guard')) {
        liveAiSummary += ' AI ne parcel guard ke paas drop karne ka instruction diya.';
      } else if (turn.text.contains('email')) {
        liveAiSummary += ' AI ne interview details email mangwayi.';
      }
    }
  }

  void _startLiveMicMode() {
    final firstTurn = widget.persona.script.first;
    setState(() {
      transcript.add(TranscriptEntry(
        speaker: firstTurn.speaker,
        text: firstTurn.text,
      ));
    });
    NativeBridge.instance.speak(firstTurn.text, lang: 'hi');
    _scrollToBottom();

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
      liveAiSummary = 'Live Summary: Caller ne kaha "$spokenText". AI jawab tayyar kar raha hai...';
    });
    _scrollToBottom();

    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || isCallEnded) return;

      String aiReply = 'Maine aapki baat note kar li hai: "$spokenText". Kripya purpose confirm karein.';
      final lower = spokenText.toLowerCase();
      if (lower.contains('delivery') || lower.contains('order') || lower.contains('swiggy') || lower.contains('zomato')) {
        aiReply = 'Theek hai, order flat 302 doorstep ya guard ke paas rakh dijiye. Dhanyawad!';
      } else if (lower.contains('loan') || lower.contains('card') || lower.contains('offer') || lower.contains('bank')) {
        aiReply = 'Shukriya, par hume koi credit card ya loan nahi chahiye. Kripya DND list me update karein.';
      } else if (lower.contains('interview') || lower.contains('job')) {
        aiReply = 'Thanks for calling! Kripya JD aur meeting schedule email par forward kar dijiye.';
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

  // USER TAKEOVER BUTTON ACTION
  void _takeOverCall() {
    _scriptTimer?.cancel();
    NativeBridge.instance.stopSpeaking();
    NativeBridge.instance.stopListening();
    NativeBridge.instance.vibrate(duration: 200);

    setState(() {
      isScreening = false;
      isTakenOver = true;
      isDirectUser = true;
      liveAiSummary = 'AI ne call user ko handover kar di. User ab directly caller se baat kar raha hai.';
      transcript.add(TranscriptEntry(
        speaker: 'user',
        text: '👤 [Takeover] Aapne call ka charge le liya hai. Ab aap caller se directly connect hain.',
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Connected! You took over the call from AI Assistant.'),
      ),
    );

    _scrollToBottom();
  }

  void _declineCall() {
    _countdownTimer?.cancel();
    _scriptTimer?.cancel();
    _callDurationTimer?.cancel();
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
      keyIntent: 'Call declined before screening.',
      aiSummary: 'User ne 10-second window ke andar call reject kar di.',
      urgency: 'None',
      hasRecording: false,
      transcript: [
        TranscriptEntry(speaker: 'user', text: 'Call was rejected.'),
      ],
      isSimulated: true,
    );

    CallStore.instance.addRecord(record);
    Navigator.of(context).pop();
  }

  void _finishCall({required CallStatus status}) {
    _countdownTimer?.cancel();
    _scriptTimer?.cancel();
    _callDurationTimer?.cancel();
    NativeBridge.instance.stopSpeaking();
    NativeBridge.instance.stopListening();

    final duration = _callStartTime != null
        ? DateTime.now().difference(_callStartTime!)
        : Duration(seconds: _callElapsedSeconds > 0 ? _callElapsedSeconds : 20);

    final record = CallRecord(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      callerName: widget.persona.name,
      callerNumber: widget.persona.number,
      timestamp: _callStartTime ?? DateTime.now(),
      duration: duration,
      category: widget.persona.category,
      status: status,
      keyIntent: widget.persona.intent,
      aiSummary: liveAiSummary,
      urgency: widget.persona.urgency,
      transcript: List.from(transcript),
      isSimulated: true,
      hasRecording: true,
      recordingDuration: duration,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.status == CallStatus.takenOver
                            ? 'Call Ended (User Taken Over)'
                            : (record.status == CallStatus.directUser ? 'Direct Call Ended' : 'AI Screening Complete'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.mic, size: 14, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Audio Recording Saved',
                            style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow(Icons.label, 'Category', record.category),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.timer, 'Call Duration', '${record.duration.inSeconds} seconds'),
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
              label: const Text('Back to Home (View Recording & Details)'),
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
    final double countdownProgress = countdownSeconds / 10.0;

    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'INCOMING CALL',
          style: TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // Caller Avatar with Pulse
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.persona.color.withOpacity(0.25),
              border: Border.all(color: widget.persona.color, width: 3),
            ),
            child: Icon(widget.persona.icon, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.persona.name,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          widget.persona.number,
          style: const TextStyle(color: Colors.white60, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Chip(
          backgroundColor: widget.persona.color.withOpacity(0.3),
          label: Text(widget.persona.tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),

        const Spacer(),

        // 10-Second Auto-Takeover Countdown Visualizer
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amberAccent.withOpacity(0.2),
                      border: Border.all(color: Colors.amberAccent, width: 2),
                    ),
                    child: Text(
                      '${countdownSeconds}s',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto AI Takeover in 10s',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Aap utha lein to theek, nahi to AI takeover kar lega!',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: countdownProgress,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    countdownSeconds <= 3 ? Colors.redAccent : Colors.amberAccent,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // Action Buttons: Decline | AI Screen Now | Accept Personally
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decline
              Column(
                children: [
                  IconButton.filled(
                    onPressed: _declineCall,
                    icon: const Icon(Icons.call_end, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),

              // AI Screen Now
              Column(
                children: [
                  IconButton.filled(
                    onPressed: () => startAiScreening(autoTriggered: false),
                    icon: const Icon(Icons.auto_mode, size: 30),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('AI Screen Now', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),

              // Pick Personally (Within 10s)
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton.filled(
                      onPressed: _acceptPersonally,
                      icon: const Icon(Icons.call, size: 30),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Pick (Aap Uthayein)', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildActiveCallView() {
    final String minutes = (_callElapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final String seconds = (_callElapsedSeconds % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        // Top Active Call Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E293B),
          child: Column(
            children: [
              Row(
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
                              ? 'Connected to You (AI Handed Over)'
                              : (isDirectUser
                                  ? 'Direct Call (Picked by You in 10s)'
                                  : 'AI Assistant Screening...'),
                          style: TextStyle(
                            color: isTakenOver || isDirectUser ? Colors.greenAccent : Colors.indigoAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recording Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text('REC $minutes:$seconds', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Live Summary Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        liveAiSummary,
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Live mic buffer if mic active
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

        // Live Transcript Chat
        Expanded(
          child: transcript.isEmpty
              ? const Center(
                  child: Text(
                    'Connecting call audio stream...',
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
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: isAi
                              ? const Color(0xFF1E293B)
                              : (isUser ? Colors.green.withOpacity(0.2) : Colors.indigo.withOpacity(0.35)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAi
                                ? Colors.indigoAccent.withOpacity(0.4)
                                : (isUser ? Colors.greenAccent : Colors.teal.withOpacity(0.5)),
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
                                  color: isAi ? Colors.amberAccent : (isUser ? Colors.greenAccent : Colors.tealAccent),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isAi ? 'AI Assistant' : (isUser ? 'You (Takeover)' : widget.persona.name),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isAi ? Colors.amberAccent : (isUser ? Colors.greenAccent : Colors.tealAccent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.text,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Controls: TAKEOVER BUTTON & END CALL
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prominent TAKEOVER BUTTON (When AI is currently screening)
              if (isScreening && !isTakenOver) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: _takeOverCall,
                    icon: const Icon(Icons.phone_forwarded, size: 22, color: Colors.white),
                    label: const Text(
                      'Take Over Call (Call Khud Uthayein)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              Row(
                children: [
                  if (widget.persona.isLiveMic) ...[
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
                        status: isTakenOver
                            ? CallStatus.takenOver
                            : (isDirectUser ? CallStatus.directUser : CallStatus.aiScreened),
                      ),
                      icon: const Icon(Icons.call_end),
                      label: const Text('End Call & Save Recording'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
