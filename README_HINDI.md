# Call Detection Flutter — शुरुआती प्रोटोटाइप

यह एक शुरुआती Flutter Android source project है। इसमें demo UI और Android Call Screening role माँगने का native bridge शामिल है।

## जरूरी बात
- यह ZIP सीधे फोन में install नहीं होती; यह source code है।
- इसे APK बनाने के लिए कंप्यूटर पर Flutter SDK और Android SDK/Android Studio चाहिए।
- Android का Call Screening role मिलने पर भी यह हर फोन/ऑपरेटर पर हर incoming call का पूरा विवरण या audio उपलब्ध होने की गारंटी नहीं देता।
- यह ऐप कॉल का audio AI तक नहीं भेजती, AI से जवाब नहीं दिलाती और असली call takeover नहीं करती।
- वास्तविक फोन पर build/test अभी करना बाकी है।

## चलाने के कदम
1. ZIP extract करें।
2. Flutter SDK और Android Studio इंस्टॉल करें।
3. टर्मिनल में इस फ़ोल्डर के अंदर चलाएँ:
   `flutter create . --platforms=android`
4. नीचे दिए गए native Kotlin और AndroidManifest बदलावों को generated Android project में बनाए रखें/merge करें। यदि `flutter create .` files को बदल दे, तो README में दिए source files से दोबारा merge करें।
5. `flutter pub get`
6. Android फोन USB से जोड़ें और `flutter run` चलाएँ।

## APK बनाना
`flutter build apk --debug`
APK सामान्यतः `build/app/outputs/flutter-apk/app-debug.apk` पर बनेगी।

## इस prototype में
- Demo call status screen
- Android system से Call Screening role माँगने का प्रयास
- वास्तविक कॉल की स्थिति native Android service के जरिए log करने का शुरुआती ढाँचा

यह prototype पूर्ण या production-ready dialer नहीं है।
