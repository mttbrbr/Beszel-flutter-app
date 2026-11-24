#!/usr/bin/env bash
# Generates the native Android/iOS folders and applies the required patches
# (cleartext HTTP for Tailscale/LAN, notification permissions, desugaring).
set -euo pipefail
cd "$(dirname "$0")"

[ -d android ] || flutter create --project-name beszel_app --org dev.beszel --platforms=android,ios .

python3 - <<'PY'
import re, pathlib, glob

# --- AndroidManifest: HTTP + permissions
m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
t = m.read_text()
perms = ['android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS']
for p in perms:
    if p not in t:
        t = t.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)
if "allowBackup" not in t:
    t = t.replace("<application", '<application\n        android:allowBackup="false"', 1)
if "usesCleartextTraffic" not in t:
    t = t.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
m.write_text(t)

# --- Gradle: core library desugaring (flutter_local_notifications)
for f in glob.glob("android/app/build.gradle*"):
    p = pathlib.Path(f); t = p.read_text()
    if "desugar_jdk_libs" in t: continue
    kts = f.endswith(".kts")
    flag = "isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"
    t = re.sub(r"(compileOptions\s*\{)", r"\1\n        " + flag, t, count=1)
    dep = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kts else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
    if re.search(r"^dependencies\s*\{", t, re.M):
        t = re.sub(r"^(dependencies\s*\{)", r"\1\n    " + dep, t, count=1, flags=re.M)
    else:
        t += "\ndependencies {\n    " + dep + "\n}\n"
    p.write_text(t)

# --- iOS: allow plain HTTP
ip = pathlib.Path("ios/Runner/Info.plist")
if ip.exists():
    t = ip.read_text()
    if "NSAllowsArbitraryLoads" not in t:
        t = t.replace("</dict>\n</plist>", "\t<key>NSAppTransportSecurity</key>\n\t<dict><key>NSAllowsArbitraryLoads</key><true/></dict>\n</dict>\n</plist>")
        ip.write_text(t)
PY

flutter pub get
echo "Fatto. Avvia con: flutter run"
