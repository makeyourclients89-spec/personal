import 'dart:async';
import 'package:flutter/material.dart';
import 'models/call_record.dart';
import 'models/persona.dart';
import 'screens/call_detail_screen.dart';
import 'screens/deep_research_dialog.dart';
import 'screens/demo_call_screen.dart';
import 'services/call_store.dart';
import 'services/native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CallAssistantApp());
}

class CallAssistantApp extends StatelessWidget {
  const CallAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Call Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
          secondary: Colors.amber,
          surface: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> permStatus = {
    'phoneState': false,
    'callLog': false,
    'audio': false,
    'notification': false,
    'screeningRole': false,
    'roleSupported': true,
  };

  DemoPersona selectedPersona = DemoPersona.presets.first;
  StreamSubscription? _eventSub;
  String? realCallState;
  String? realCallNumber;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();

    // Listen to real-time telephony and screening events
    _eventSub = NativeBridge.instance.events.listen((event) {
      final type = event['event'] as String?;
      if (type == 'call_state') {
        setState(() {
          realCallState = event['state'] as String?;
          realCallNumber = event['phoneNumber'] as String?;
        });
        if (realCallState == 'RINGING') {
          _handleIncomingRealCall(realCallNumber ?? 'Unknown');
        }
      } else if (type == 'call_screened') {
        final number = event['phoneNumber'] as String? ?? 'Screened Caller';
        _handleScreenedRealCall(number);
      } else if (type == 'permissions_updated') {
        final status = event['status'];
        if (status is Map) {
          setState(() {
            permStatus = Map<String, dynamic>.from(status);
          });
        }
      } else if (type == 'role_updated') {
        final held = event['held'] == true;
        setState(() {
          permStatus['screeningRole'] = held;
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    final status = await NativeBridge.instance.getPermissionsStatus();
    if (mounted) {
      setState(() {
        permStatus = status;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final res = await NativeBridge.instance.requestRuntimePermissions();
    if (res == 'ALL_GRANTED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sabhi runtime permissions pehle se granted hain!')),
      );
    }
    await _refreshPermissions();
  }

  Future<void> _requestRole() async {
    final res = await NativeBridge.instance.requestCallScreeningRole();
    if (res == 'ALREADY_HELD') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call Screening role pehle se active hai! Default apps settings khol rahe hain...')),
      );
      await NativeBridge.instance.openDefaultAppsSettings();
    } else if (res.startsWith('ERROR')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role request error: $res')),
      );
    }
    await _refreshPermissions();
  }

  void _handleIncomingRealCall(String number) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.indigo,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Real Incoming Call Detected: $number',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleScreenedRealCall(String number) {
    final record = CallRecord(
      id: 'real_${DateTime.now().millisecondsSinceEpoch}',
      callerName: 'Real Screened Call',
      callerNumber: number,
      timestamp: DateTime.now(),
      duration: const Duration(seconds: 15),
      category: 'Incoming Telephony',
      status: CallStatus.realScreened,
      keyIntent: 'Real incoming call screened via Android CallScreeningService',
      aiSummary: 'Device par aayi real phone call ko CallScreeningService ne intercept karke log kiya.',
      urgency: 'Medium',
      transcript: [
        TranscriptEntry(speaker: 'caller', text: 'Incoming call received from $number'),
        TranscriptEntry(speaker: 'ai', text: 'Call screened and allowed by Android service filter.'),
      ],
      isSimulated: false,
    );
    CallStore.instance.addRecord(record);
  }

  void _startDemoCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DemoCallScreen(persona: selectedPersona),
      ),
    );
  }

  void _openResearchGuide() {
    showDialog(
      context: context,
      builder: (_) => const DeepResearchDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Call Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology, color: Colors.indigo),
            tooltip: 'Deep Architecture & Bugs Research',
            onPressed: _openResearchGuide,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _refreshPermissions,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: CallStore.instance,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Real Call Alert Banner if active
              if (realCallState == 'RINGING') ...[
                _buildRealCallBanner(),
                const SizedBox(height: 16),
              ],

              // 1. Interactive Demo Call Hero Card
              _buildDemoCallHeroCard(),
              const SizedBox(height: 16),

              // 2. Permission Diagnostic & Setup Card
              _buildPermissionsCard(),
              const SizedBox(height: 20),

              // 3. Recent Calls Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Calls & Transcripts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${CallStore.instance.records.length} calls',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (CallStore.instance.records.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Abhi koi call log nahi hai. Upar demo call shuru karein!'),
                    ),
                  ),
                )
              else
                ...CallStore.instance.records.map((r) => _buildCallRecordItem(r)),

              const SizedBox(height: 24),
              // Technical Footer Card
              _buildTechnicalFooter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRealCallBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.ring_volume, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PHONE RINGING NOW (Real Call)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  realCallNumber ?? 'Incoming caller',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              setState(() {
                realCallState = 'IDLE';
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCallHeroCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.indigo.shade900, Colors.indigo.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assistant Simulator',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Live Hindi/English Speech & Screening',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white70),
                  onPressed: _openResearchGuide,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Caller Scenario to Test:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: DemoPersona.presets.map((p) {
                  final isSelected = p.id == selectedPersona.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      avatar: Icon(p.icon, size: 16, color: isSelected ? Colors.indigo.shade900 : Colors.white),
                      label: Text(p.tag),
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.indigo.shade900 : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => selectedPersona = p),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: selectedPersona.color.withOpacity(0.3),
                    child: Icon(selectedPersona.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPersona.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          selectedPersona.isLiveMic ? 'Speak using your phone mic' : selectedPersona.number,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _startDemoCall,
              icon: const Icon(Icons.ring_volume, color: Colors.indigo),
              label: const Text('Demo Call शुरू करें', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo.shade900,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard() {
    final bool phoneState = permStatus['phoneState'] == true;
    final bool callLog = permStatus['callLog'] == true;
    final bool audio = permStatus['audio'] == true;
    final bool notification = permStatus['notification'] == true;
    final bool screeningRole = permStatus['screeningRole'] == true;

    final int grantedCount = [phoneState, callLog, audio, notification, screeningRole].where((b) => b).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security, color: Colors.indigo, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Android Permissions & Role Health',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: grantedCount == 5 ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$grantedCount/5 Ready',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: grantedCount == 5 ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPermBadge('Phone State', phoneState),
                _buildPermBadge('Call Log', callLog),
                _buildPermBadge('Microphone', audio),
                _buildPermBadge('Notifications', notification),
                _buildPermBadge('Screening Role', screeningRole),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _requestPermissions,
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text('Grant Permissions', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _requestRole,
                    icon: const Icon(Icons.settings_phone, size: 16),
                    label: const Text('Enable Screening Role', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermBadge(String label, bool isGranted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGranted ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: isGranted ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isGranted ? Colors.green.shade900 : Colors.red.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallRecordItem(CallRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: record.category == 'Food Delivery'
              ? Colors.deepOrange.withOpacity(0.15)
              : (record.category == 'Promotional'
                  ? Colors.blue.withOpacity(0.15)
                  : (record.category == 'Fraud / Spam' ? Colors.red.withOpacity(0.15) : Colors.purple.withOpacity(0.15))),
          child: Icon(
            record.status == CallStatus.aiScreened
                ? Icons.auto_awesome
                : (record.status == CallStatus.declined ? Icons.call_end : Icons.phone_callback),
            color: Colors.indigo,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record.callerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                record.category,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              record.keyIntent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Text(
                  record.isSimulated ? 'Simulated AI' : 'Real Cellular',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CallDetailScreen(record: record),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTechnicalFooter() {
    return Card(
      color: Colors.grey.shade100,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'Senior Developer Note & Android Telephony Reality',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _openResearchGuide,
                  child: const Text('Read Research', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Android OS standard apps ko 2-way cellular voice access nahi deta. Is app me full client-side AI Call Simulator aur real phone call detection bridge dono ready hain. Production me cloud VoIP forwarding (Twilio/Exotel) se cellular calls connect hoti hain.',
              style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
