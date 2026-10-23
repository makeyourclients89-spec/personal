import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const CallDetectionApp());

class CallDetectionApp extends StatelessWidget {
  const CallDetectionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Call Assistant',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const channel = MethodChannel('call_detection/role');
  String status = 'अभी कोई कॉल टेस्ट नहीं हुई।';
  bool demoActive = false;

  Future<void> enableScreening() async {
    try {
      final result = await channel.invokeMethod<String>('requestCallScreeningRole');
      setState(() => status = result ?? 'Android सेटिंग खुली/अनुरोध भेजा गया।');
    } on PlatformException catch (e) {
      setState(() => status = 'Call Screening उपलब्ध नहीं: ${e.message ?? e.code}');
    } on MissingPluginException {
      setState(() => status = 'Native Android bridge नहीं मिला। README के कदम पूरे करें।');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Call Assistant'), centerTitle: true),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const Icon(Icons.support_agent, size: 54),
        const SizedBox(height: 10),
        const Text('Call Detection Test', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(status, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: enableScreening, icon: const Icon(Icons.settings_phone), label: const Text('Enable call screening')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => setState(() { demoActive = !demoActive; status = demoActive ? 'Demo सक्रिय है — यह वास्तविक कॉल नहीं है।' : 'Demo बंद है।'; }), child: Text(demoActive ? 'Demo समाप्त करें' : 'Demo Call शुरू करें')),
      ]))),
      const SizedBox(height: 16),
      const Text('Recent calls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Card(child: ListTile(leading: Icon(Icons.call_missed), title: Text('अभी कोई वास्तविक call log नहीं'), subtitle: Text('यह शुरुआती prototype है।'))),
      const SizedBox(height: 16),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('सीमा: यह ऐप अभी कॉल का audio AI तक नहीं भेजती और Takeover नहीं करती। Call screening का व्यवहार Android version, role और device पर निर्भर करता है।'))),
    ]),
  );
}
