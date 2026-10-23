import os
import shutil
import re

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KOTLIN_DIR = os.path.join(
    BASE_DIR, "android", "app", "src", "main", "kotlin", "com", "example", "call_detection_flutter"
)
MANIFEST_PATH = os.path.join(
    BASE_DIR, "android", "app", "src", "main", "AndroidManifest.xml"
)
APP_BUILD_GRADLE = os.path.join(BASE_DIR, "android", "app", "build.gradle")
APP_BUILD_GRADLE_KTS = os.path.join(BASE_DIR, "android", "app", "build.gradle.kts")

print("--> Setting up Android native files for Call Detection...")

# 1. Kotlin Directory
os.makedirs(KOTLIN_DIR, exist_ok=True)

main_src = os.path.join(BASE_DIR, "android_changes", "MainActivity.kt")
call_src = os.path.join(BASE_DIR, "android_changes", "CallScreeningServiceImpl.kt")

if os.path.exists(main_src):
    shutil.copy2(main_src, os.path.join(KOTLIN_DIR, "MainActivity.kt"))
    print("✓ Replaced MainActivity.kt")

if os.path.exists(call_src):
    shutil.copy2(call_src, os.path.join(KOTLIN_DIR, "CallScreeningServiceImpl.kt"))
    print("✓ Added CallScreeningServiceImpl.kt")

# 2. AndroidManifest.xml
if os.path.exists(MANIFEST_PATH):
    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # Permissions
    perm_tag = '    <uses-permission android:name="android.permission.READ_PHONE_STATE" />\n'
    if "READ_PHONE_STATE" not in content:
        if "<application" in content:
            content = content.replace("<application", perm_tag + "    <application", 1)
            print("✓ Added READ_PHONE_STATE permission")

    # Service
    service_tag = '''        <service
            android:name=".CallScreeningServiceImpl"
            android:label="Call Detection"
            android:permission="android.permission.BIND_SCREENING_SERVICE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.telecom.CallScreeningService" />
            </intent-filter>
        </service>
'''
    if "CallScreeningServiceImpl" not in content:
        if "</application>" in content:
            content = content.replace("</application>", service_tag + "    </application>", 1)
            print("✓ Added CallScreeningServiceImpl service entry")

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print("✓ AndroidManifest.xml updated successfully")
else:
    print(f"! Warning: {MANIFEST_PATH} not found.")

# 3. Ensure minSdk >= 24 (CallScreeningService requires API 24+)
gradle_file = APP_BUILD_GRADLE if os.path.exists(APP_BUILD_GRADLE) else (APP_BUILD_GRADLE_KTS if os.path.exists(APP_BUILD_GRADLE_KTS) else None)
if gradle_file:
    with open(gradle_file, "r", encoding="utf-8") as f:
        g_content = f.read()

    # Replace minSdk / minSdkVersion with 24 if lower or flutter.minSdkVersion
    new_g = re.sub(r'minSdkVersion\s+(flutter\.minSdkVersion|\d+)', 'minSdkVersion 24', g_content)
    new_g = re.sub(r'minSdk\s*=\s*(flutter\.minSdkVersion|\d+)', 'minSdk = 24', new_g)
    if new_g != g_content:
        with open(gradle_file, "w", encoding="utf-8") as f:
            f.write(new_g)
        print("✓ minSdk updated to 24 in build gradle")

print("--> Setup complete.")
