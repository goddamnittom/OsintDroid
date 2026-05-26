# OsintDroid
OsintDroid is a script that helps you snoop on an Android phone — but only if you own the phone and have plugged it into your computer.
It uses ADB (Android Debug Bridge). Think of ADB as a secret backdoor that Android phones have for developers. If you turn on "USB Debugging" in your phone's settings and plug it in with a cable, your computer can talk directly to the phone's brain.

***What It Can Do (With One Click)***
Once connected, OsintDroid shows you a menu. Pick a number, and it pulls data off the phone.

***The Features***
- Pre-flight checks — It makes sure ADB is installed, a phone is plugged in, and you've authorized the connection before showing the menu
- Export to files — Contacts, call logs, SMS, and WiFi passwords get saved to timestamped  .txt  files in an  output/  folder so you don't lose them
- Multi-device support — Plug in 2+ phones and pick which one to target
- Session summary — When you quit, it shows you a neat list of every file it saved and how big each one is
- Animated UI — The banner fades in line-by-line, progress bars bounce while waiting, and text types itself out like a hacker movie
  
***Who Is This For?***
- Forensic investigators pulling data from a suspect's phone
- Phone repair techs diagnosing device issues
- Data recovery — grabbing contacts/SMS before a factory reset
- Curious tinkerers who want to see what's on their own phone

***What You Need***
1. A computer (Windows/Mac/Linux)
2. ADB installed (free from Google)
Windows: https://dl.google.com/android/repository/platform-tools-latest-windows.zip
macOS: Download SDK Platform-Tools for Mac https://dl.google.com/android/repository/platform-tools-latest-darwin.zip
Linux: Download SDK Platform-Tools for Linux https://dl.google.com/android/repository/platform-tools-latest-linux.zip
4. An Android phone with USB Debugging turned on (S ettings → Developer Options)
5. A USB cable

***What It Can't Do***
- Doesn't need root, but some features (WiFi passwords) work better with it
- Read-only — it never writes to the phone
- Won't work if USB Debugging is off
- Won't hack into someone else's phone remotely — you need physical access
────────────────────────────────────────────────────────────────────────────────
