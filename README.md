# VidHub

A routine launcher for Windows. At the right time it doesn't just remind you. It **opens the things you need** (a site, VS Code, a folder, a document) and keeps a card on screen until you mark the task done.

Free to run: no accounts, no server, no Firebase. Everything is stored in one JSON file on your PC.

## What it does

| Feature | How it works |
| --- | --- |
| **Sticky alert card** | When a task is due, a small always-on-top card appears in the bottom-right corner. It stays until you press **Done**, **Snooze +10m** or **Skip**. It never steals keyboard focus, so it won't swallow what you're typing. |
| **One-click launch** | Each task can open URLs (`https://duolingo.com`), app links (`vscode://file/C:/code/app`), executable names available on `PATH` (`code`) or existing Windows paths (`C:\Tools\app.exe`, files and folders). **Open** starts all of them at once; a failed target is reported in the app. |
| **Global quick-add** | `Ctrl+Shift+T` from anywhere opens a tiny box. Type, press Enter, done. |
| **Routines** | "Weekday", "Exam Prep" and "Weekend" are built in. One click swaps your whole schedule. Save your own from the current schedule. |
| **Lives in the tray** | Closing the window hides it. Right-click the tray icon for Open, Quick add, Quit. |
| **Catch-up** | Wake the laptop 10 minutes late and the alert still fires. More than 30 minutes late is logged as *Missed*. |

### Quick-add syntax

```
11:00 AM | Duolingo                          a task at 11:00 (tomorrow if already past)
11:00 AM | Duolingo | duolingo.com            ...that opens a site
11:00 AM | Study | code | C:\Notes\exam.docx   ...opens several things
5pm gym            17:30 gym                  free-form, no pipe needed
+30m stretch       +1h read                   relative to now
daily 7am | Wake up                           repeats every day
```

The box shows a live preview of what will be created before you press Enter.

## Setup (Windows 10/11)

You need:

1. **Flutter 3.27 or newer**: <https://docs.flutter.dev/get-started/install/windows>
2. **Visual Studio 2022 Community** (free) with the **Desktop development with C++** workload
3. **Windows Developer Mode** on (Settings, For developers), which Flutter plugins need for symlinks

Then, from this folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
flutter run -d windows
```

`setup.ps1` generates the Windows runner if it is missing, applies VidHub window and product branding, installs packages, then runs `flutter analyze` and `flutter test`. It can be run again to refresh dependencies and repeat the checks without replacing your Dart sources. Run `flutter doctor -v` first if anything complains. You do **not** need the Android SDK for this version. A Windows runner is generated locally and is not included in this source tree, so setup must complete before `flutter run -d windows` or a Windows build will work.

Build a release:

```powershell
flutter build windows --release
# output: build\windows\x64\runner\Release\vidhub.exe
```

### Start with Windows

Press `Win+R`, run `shell:startup`, and put a shortcut to the release `vidhub.exe` in that folder. To start hidden in the tray, open the shortcut's Properties and append ` --tray` after the quoted executable path in **Target**, for example `"C:\path\to\vidhub.exe" --tray`. Alerts only work while VidHub is running.

## Project layout

```
lib/
  main.dart                      startup: load data, window, tray, hotkey, scheduler
  app.dart                       one MaterialApp, shows the face for the current window mode
  core/                          ids, date/time helpers
  models/                        Task, Routine, LaunchItem, AppData, built-in routines
  logic/                         pure Dart, fully tested:
    scheduler.dart               what is due right now
    quick_add_parser.dart        "5pm gym" -> task
    today_status.dart            how a task looks in today's list
  services/
    storage_service.dart         atomic JSON file, corrupt-file quarantine
    launcher_service.dart        opens URLs, programs, files
    window_service.dart          window_manager: sizes, always-on-top, focus
    global_hotkey_service.dart   Ctrl+Shift+T
    tray_service.dart            tray icon + menu
  providers/app_providers.dart   Riverpod state, alert queue, window-mode logic
  ui/
    sticky_overlay_widget.dart   the alert card
    quick_add_view.dart          the Ctrl+Shift+T box
    manager_view.dart            Today and All tasks pages
    routines_page.dart           routines
    task_editor_dialog.dart      add / edit a task
test/                            tests for models, scheduler, parser, storage, launch items
```

One native window plays four roles (hidden, manager, alert card, quick-add). `WindowModeController` decides which, and resizes the window to match.

## Where your data lives

`vidhub.json` in the app-support folder (typically `%APPDATA%\dev.taskpulse\taskpulse\vidhub.json`; existing data in `taskpulse.json` is copied forward on first launch). It's plain JSON, so you can back it up or edit it. If the file ever becomes unreadable it is renamed to `vidhub.json.corrupt-<time>`, never overwritten.

## Troubleshooting

- **"Ctrl+Shift+T unavailable"** badge: another program owns that shortcut. Close it and restart VidHub. Quick add is still in the tray menu.
- **No tray icon**: make sure `assets/icons/tray.ico` exists (it ships with the project).
- **Alert doesn't show over a fullscreen game**: exclusive-fullscreen apps hide all other windows. Borderless-window mode works.
- **A plugin fails to compile after a Flutter upgrade** (`window_manager`, `hotkey_manager`, `system_tray`): run `flutter pub upgrade`, and check each package's issue tracker.
- **Alerts only fire while VidHub is running.** That's why it lives in the tray; use the startup shortcut above.

## Not in this version

- Android companion and phone/PC sync (the data model is already plain JSON, so a sync layer can come later)
- Focus timer after launching a routine
- Per-task custom snooze length (fixed at 10 minutes)
