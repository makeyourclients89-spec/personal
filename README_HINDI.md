# AI Call Assistant — Senior Flutter & AI Telephony Architecture

यह रिपॉजिटरी एक **AI Call Screening & Telephony Assistant** का Flutter + Android Native समाधान है।

---

## 🔍 मुख्य समस्याओं का Deep Research और Root Cause Analysis

### 1. "Demo call pe kuch nahi ho raha tha"
* **पुराना कारण:** पिछले कोड के `main.dart` में Demo Call बटन पर सिर्फ `demoActive = !demoActive` था, जो केवल स्क्रीन पर 1 लाइन का टेक्स्ट बदल रहा था। कोई Incoming Call UI, Audio Speech, Dialogue Loop, या Speech Recognition मौजूद नहीं था।
* **नया समाधान:** अब एक **Interactive Full-Screen AI Call Simulator** तैयार किया गया है:
  - 5 तरह के रियलिस्टिक कॉलर परिदृश्य (Zomato/Swiggy Delivery, HDFC Bank Telemarketing, Tech Recruiter, Lottery Spam, और Live Phone Mic Mode)।
  - इनकमिंग कॉल रिंगिंग स्क्रीन (Ringing animation, Haptic vibration, Accept, Decline, AI Screen बटन)।
  - लाइव AI स्क्रीनिंग कंसोल: पल्सिंग साउंड विज़ुअलाइज़र, नेटिव Android Text-to-Speech (हिंदी/इंग्लिश में AI आवाज़ बोलती है), लाइव ट्रांसक्रिप्ट, और कॉल टेकओवर (Take Over Call) बटन।
  - कॉल खत्म होने पर ऑटोमैटिक AI Summary और Key Intent जनरेट होकर **Recent Calls** में सुरक्षित हो जाता है।

### 2. "Enable call screening pe already enable aa raha tha but permission nahi li"
* **पुराना कारण:** Android 10+ (API 29+) में `RoleManager.isRoleHeld(ROLE_CALL_SCREENING)` सिर्फ यह बताता है कि सिस्टम में यह रोल असाइन्ड है या नहीं। कई चीनी व अन्य OEM (Xiaomi HyperOS, Vivo, Oppo, Samsung OneUI) में यह डिफॉल्ट रूप से true या बिना प्रॉम्प्ट के रिटर्न हो जाता है। सबसे बड़ी कमी यह थी कि **Android Runtime Permissions** (`READ_PHONE_STATE`, `READ_CALL_LOG`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`) का कोड ही नहीं था!
* **नया समाधान:** 
  - अब एक 5-पॉइंट **Diagnostic & Permission Health Card** बनाया गया है (Phone State, Call Log, Mic, Notifications, और Screening Role)।
  - एक क्लिक में सभी जरूरी रनटाइम परमिशन मांगने के लिए **Grant Permissions** बटन है।
  - यदि डिवाइस रोल को सिस्टम सेटिंग्स से मैनेज करता है, तो सीधे **Default Apps Settings** खोलने का सुरक्षित ब्रिज दिया गया है।

### 3. Android OS Cellular Audio की हकीकत (Deep Telephony Research)
* **Google Android Security Sandbox:** Android के स्टैंडर्ड AOSP टेलीकॉम नियमों के अनुसार, किसी भी थर्ड-पार्टी ऐप को `CallScreeningService` के जरिए लाइव सेलुलर कॉल की ऑडियो (Mic inject करना या कॉलर की आवाज़ रिकॉर्ड करना) का सीधा एक्सेस **नहीं** दिया जाता। Google Pixel Call Screen एक प्राइवेट सिस्टम ऐप है जो प्रिविलेज्ड परमिशन (`CAPTURE_AUDIO_OUTPUT`) इस्तेमाल करती है।
* **Production AI Assistant (Truecaller, Bland AI, Retell) कैसे बनते हैं?**
  - **Cloud VoIP / SIP Call Forwarding:** जब फोन व्यस्त हो या यूजर चाहे, तब फोन कॉल को `*67*` या `*21*` के जरिए Twilio / Exotel के क्लाउड नंबर पर फॉरवर्ड कर देता है। क्लाउड पर OpenAI Realtime Voice / Deepgram STT + ElevenLabs TTS लाइव बातचीत करता है और ऐप पर डेटा स्ट्रीम करता है।
  - **In-App Interactive Simulator:** इस ऐप में वही पूरा AI स्क्रीनिंग एक्सपीरियंस (स्पीच, ट्रांसक्रिप्ट, समरी) क्लाइंट-साइड नेटिव इंजन के साथ टेस्ट करने के लिए लाइव दिया गया है।

---

## 🚀 नया आर्किटेक्चर (Project Structure)

```
personal/
├── android_changes/
│   ├── AndroidManifest_additions.xml # टेलीफोनी, ऑडियो और बैकग्राउंड सर्विस परमिशन
│   ├── CallReceiver.kt              # रियल फोन स्टेट (RINGING, OFFHOOK) ब्रॉडकास्ट लिसनर
│   ├── CallScreeningServiceImpl.kt  # Android CallScreeningService
│   └── MainActivity.kt              # रनटाइम परमिशन, Native TTS (Hindi/English), और SpeechRecognizer
├── lib/
│   ├── models/
│   │   ├── call_record.dart         # कॉल रिकॉर्ड, ट्रांसक्रिप्ट और AI समरी मॉडल
│   │   └── persona.dart             # डिलीवरी, बैंक, रिक्रूटर, स्पैम और माइक परिदृश्य
│   ├── screens/
│   │   ├── call_detail_screen.dart  # पूरी बातचीत का ट्रांसक्रिप्ट, AI समरी और ऑडियो स्पीच
│   │   ├── deep_research_dialog.dart# इन-ऐप आर्किटेक्चर और बग रिसर्च गाइड
│   │   └── demo_call_screen.dart    # फुल-स्क्रीन इनकमिंग और AI स्क्रीनिंग कंसोल
│   ├── services/
│   │   ├── call_store.dart          # कॉल हिस्ट्री और ट्रांसक्रिप्ट का स्टेट स्टोर
│   │   └── native_bridge.dart       # मेथड और इवेंट चैनल का सुरक्षित ब्रिज
│   └── main.dart                    # मुख्य डैशबोर्ड, हेल्थ कार्ड और रीसेंट कॉल्स
├── .github/workflows/
│   └── build_apk.yml                # ऑटोमैटिक GitHub Actions APK बिल्ड
└── setup_android.py                 # नेटिव फाइलों को ऑटो-मर्ज करने वाला स्क्रिप्ट
```

---

## 🛠️ नया APK कैसे टेस्ट करें?

1. कोड को GitHub पर पुश करें।
2. GitHub Actions टैब में **Build Android APK** वर्कफ़्लो अपने आप चलेगा।
3. बिल्ड पूरा होने पर **CallAssistant-debug-apk** डाउनलोड करें और फोन पर इंस्टॉल करें।
4. ऐप खोलें:
   - **Grant Permissions** पर टैप करके फोन स्टेट, माइक और नोटिफिकेशन परमिशन स्वीकार करें।
   - ऊपर दिए गए चिप्स (🛵 Delivery, 💳 Credit Card, 💼 Recruiter, ⚠️ Spam, 🎙️ Phone Mic) में से कोई भी एक चुनें।
   - **"Demo Call शुरू करें"** पर टैप करें।
   - आपके फोन पर रिंग होगी; **AI Screen Call** पर टैप करें।
   - AI असिस्टेंट की लाइव हिंदी/इंग्लिश आवाज़ सुनें, ट्रांसक्रिप्ट देखें और कॉल खत्म होने पर AI समरी देखें!
