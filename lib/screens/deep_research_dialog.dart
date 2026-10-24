import 'package:flutter/material.dart';

class DeepResearchDialog extends StatelessWidget {
  const DeepResearchDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology, color: Colors.indigo, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Call Assistant Architecture',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Deep Technical Research & Android Constraints',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionHeader('1. "Already Enabled" Bug Ka Sach (Root Cause)'),
                    _buildParagraph(
                      'Pichhle code me Android ka RoleManager.isRoleHeld(ROLE_CALL_SCREENING) check kiya gaya tha, '
                      'par Android runtime permissions (READ_PHONE_STATE, READ_CALL_LOG, RECORD_AUDIO) request hi nahi ki gayi thi! '
                      'Kai OEM devices (Xiaomi, Vivo, Oppo, Samsung) me default role status bina explicit dialog ke return ho jata hai, '
                      'isliye user ko lagta hai permission nahi maangi aur bug ho gaya. Ab humne dedicated runtime permission manager add kar diya hai.'
                    ),
                    const SizedBox(height: 14),

                    _buildSectionHeader('2. Demo Call Pe Kuch Na Hone Ka Karan'),
                    _buildParagraph(
                      'Purane main.dart me Demo Call button sirf ek String variable toggle kar raha tha ("demoActive = !demoActive"). '
                      'Vahan koi incoming call screen, audio synthesis, speech recognition, ya dialogue loop exist hi nahi karti thi! '
                      'Ab humne complete full-screen AI Call Simulator implement kiya hai jisme realistic incoming screen, native Text-to-Speech (Hindi/English), '
                      'pulsing waveform animation, transcript, aur AI summaries save hoti hain.'
                    ),
                    const SizedBox(height: 14),

                    _buildSectionHeader('3. Android OS Cellular Audio Limitations (Deep Research)'),
                    _buildParagraph(
                      'Google Android security guidelines ke mutabik, third-party apps ko standard CallScreeningService me raw 2-way phone audio stream ka direct access nahi milta: '
                      '\n• CallScreeningService sirf call allow, silence ya reject kar sakti hai.\n'
                      '• Phone audio stream me microphone inject karna ya caller ka audio record karna AOSP Telecom framework me restricted hai (Google Pixel Call Screen private system app hoti hai).'
                    ),
                    const SizedBox(height: 14),

                    _buildSectionHeader('4. Production AI Call Assistant Kaise Banate Hain?'),
                    _buildParagraph(
                      'Real-world AI Call Assistants (jaise Truecaller Assistant, Bland AI, Bland.ai, Retell) 2 tareeko se kaam karte hain:\n\n'
                      'A) Cloud VoIP / SIP Call Forwarding Architecture:\n'
                      'Jab phone par call aati hai ya busy hota hai, phone standard call forwarding (*67* ya *21*) ke jariye Twilio/Exotel cloud SIP server par call forward kar deta hai. '
                      'Cloud server par OpenAI Realtime Voice / Deepgram STT + ElevenLabs TTS 2-way call pick karta hai aur realtime transcript app par stream karta hai.\n\n'
                      'B) In-App Interactive AI Screening (Current Implementation):\n'
                      'Is Flutter app me full native client engine implement kiya gaya hai jisme live incoming simulation, speech-to-text, Hindi/English TTS, and automated intent classification chalta hai.'
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: const Text('Samajh Gaya (Close)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, height: 1.45, color: Colors.black87),
      ),
    );
  }
}
