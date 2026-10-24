import 'package:flutter/material.dart';

class ScriptTurn {
  final String speaker; // 'caller' | 'ai'
  final String text;
  final Duration delay;

  const ScriptTurn({
    required this.speaker,
    required this.text,
    this.delay = const Duration(seconds: 2),
  });
}

class DemoPersona {
  final String id;
  final String name;
  final String number;
  final String tag;
  final IconData icon;
  final Color color;
  final String intent;
  final String category;
  final String urgency;
  final List<ScriptTurn> script;
  final bool isLiveMic;

  const DemoPersona({
    required this.id,
    required this.name,
    required this.number,
    required this.tag,
    required this.icon,
    required this.color,
    required this.intent,
    required this.category,
    required this.urgency,
    required this.script,
    this.isLiveMic = false,
  });

  static const List<DemoPersona> presets = [
    DemoPersona(
      id: 'delivery',
      name: 'Ramesh (Swiggy Delivery)',
      number: '+91 98765 43210',
      tag: 'Food Delivery',
      icon: Icons.delivery_dining,
      color: Colors.deepOrange,
      intent: 'Parcel security guard ya doorstep par rakhne ka instruction diya gaya.',
      category: 'Delivery',
      urgency: 'Low',
      script: [
        ScriptTurn(
          speaker: 'ai',
          text: 'Namaste! Main user ka AI Call Assistant hoon. Kahiye kis baare me call kiya hai?',
          delay: Duration(seconds: 1),
        ),
        ScriptTurn(
          speaker: 'caller',
          text: 'Bhaiya Swiggy se hoon. Flat number 302 par delivery hai, gate par security jaane nahi de raha.',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'ai',
          text: 'Theek hai Ramesh ji, aap parcel guard ke paas submit kar dijiye aur apna order OTP 4920 bata dijiye. Thank you!',
          delay: Duration(seconds: 4),
        ),
        ScriptTurn(
          speaker: 'caller',
          text: 'Theek hai sir, maine guard ko packet de diya hai.',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'ai',
          text: 'Dhanyawad Ramesh ji! Have a safe delivery.',
          delay: Duration(seconds: 2),
        ),
      ],
    ),
    DemoPersona(
      id: 'telemarketer',
      name: 'Pooja (HDFC Bank Cards)',
      number: '+91 70001 22334',
      tag: 'Credit Card Offer',
      icon: Icons.credit_card,
      color: Colors.blueAccent,
      intent: 'Promotional credit card offer identify karke DND me mark kiya gaya.',
      category: 'Promotional',
      urgency: 'None',
      script: [
        ScriptTurn(
          speaker: 'ai',
          text: 'Namaste! Main AI Assistant hoon. Aap kis vishay par baat karna chahte hain?',
          delay: Duration(seconds: 1),
        ),
        ScriptTurn(
          speaker: 'caller',
          text: 'Hello sir, HDFC Bank ki taraf se pre-approved Lifetime Free Credit Card offer ke liye call hai.',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'ai',
          text: 'Hum is offer me bilkul interested nahi hain. Kripya hamare number ko DND list me daal dijiye.',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'caller',
          text: 'Okay sir, main system me Not Interested mark kar deti hoon.',
          delay: Duration(seconds: 2),
        ),
        ScriptTurn(
          speaker: 'ai',
          text: 'Dhanyawad. Call disconnect ki ja rahi hai.',
          delay: Duration(seconds: 2),
        ),
      ],
    ),
    DemoPersona(
      id: 'recruiter',
      name: 'Ananya (HR Recruiter)',
      number: '+91 88889 99990',
      tag: 'Job Opportunity',
      icon: Icons.work,
      color: Colors.purple,
      intent: 'Flutter Senior Developer role ke interview scheduling ki baat hui, details email mangwayi.',
      category: 'Recruitment',
      urgency: 'High',
      script: [
        ScriptTurn(
          speaker: 'ai',
          text: 'Hello! You have reached the AI Call Assistant. The user is currently in a meeting. How may I assist you?',
          delay: Duration(seconds: 1),
        ),
        ScriptTurn(
          speaker: 'caller',
          text: 'Hi, this is Ananya from Google recruitment regarding the Senior Flutter Engineer application.',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'ai',
          text: 'Thank you Ananya. The candidate is very interested. Could you please email the interview schedule and role brief?',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'caller',
          text: 'Certainly! I have sent the details to candidate email. We look forward to connecting tomorrow at 4 PM.',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'ai',
          text: 'I have logged this high priority update for the candidate. Thank you!',
          delay: Duration(seconds: 2),
        ),
      ],
    ),
    DemoPersona(
      id: 'spam',
      name: 'Suspected Fraud Call',
      number: '+91 60000 11223',
      tag: 'Lottery Scam',
      icon: Icons.warning_amber_rounded,
      color: Colors.red,
      intent: 'Suspicious lottery fraud call block & auto-terminate kiya gaya.',
      category: 'Fraud / Spam',
      urgency: 'Critical',
      script: [
        ScriptTurn(
          speaker: 'ai',
          text: 'Namaste! Yeh call AI Call Assistant dwara screen ki ja rahi hai.',
          delay: Duration(seconds: 1),
        ),
        ScriptTurn(
          speaker: 'caller',
          text: 'Sir aapne 25 lakh ka lottery jeeta hai! Turant bank account aur Aadhaar number share karein.',
          delay: Duration(seconds: 3),
        ),
        ScriptTurn(
          speaker: 'ai',
          text: 'Alert: Yeh call fraud & phishing attempt ke roop me detect hui hai. Security protocol ke tehat call terminate ki ja rahi hai.',
          delay: Duration(seconds: 3),
        ),
      ],
    ),
    DemoPersona(
      id: 'live_mic',
      name: 'Interactive Mic Test (Real Voice)',
      number: 'You (Live Caller)',
      tag: 'Speak via Phone Mic',
      icon: Icons.mic,
      color: Colors.teal,
      intent: 'Live microphone interaction mode for real-time speech testing.',
      category: 'Live Test',
      urgency: 'Medium',
      isLiveMic: true,
      script: [
        ScriptTurn(
          speaker: 'ai',
          text: 'Namaste! Main aapka AI Call Assistant hoon. Kripya mic me boliye, main sun raha hoon.',
          delay: Duration(seconds: 1),
        ),
      ],
    ),
  ];
}
