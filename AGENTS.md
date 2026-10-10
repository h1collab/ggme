# Project instructions

Run all automated game tests only in Godot headless mode (`godot --headless`). Python test orchestrators must launch only headless Godot processes. Do not run graphical capture tests, Android emulators, device installation, or APK runtime tests unless the user explicitly changes this preference.

APK export is a build deliverable, not a test target. Continue producing the APK after headless gameplay and real ENet/UDP checks pass. Do not claim Android rendering or device performance was tested by a headless run.
