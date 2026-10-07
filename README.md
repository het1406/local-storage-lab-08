# Fall Festival Roster — In-Class Activity 08

GitHub account: het1406

Repository: https://github.com/het1406/local-storage-lab-08 (private).

A Flutter Android/iOS app that stores fictional festival guests in a local SQLite database. The screen supports Add, Edit, Cancel edit, confirmed Delete, Refresh, and a database-derived record count. Duplicate names are allowed; all updates and deletions target generated integer IDs.

## Setup

Environment used: Flutter 3.47.6 stable, Dart 3.13.5, macOS 26.5 on Apple Silicon. Intended test target: Pixel_4a Android emulator. The generated Dart SDK constraint was retained. The guide's dependency constraints (`sqflite ^2.4.1`, `path_provider ^2.1.5`, `path ^1.9.0`) are used; exact resolved versions are retained in `pubspec.lock`.

```sh
flutter pub get
flutter devices
flutter run -d <android-or-ios-device-id>
```

Android/iOS are the supported targets. No web or desktop storage substitution is included. The obsolete generated counter-app test was removed.

## Implementation

`lib/database_helper.dart` implements the API and schema described in the pasted activity guide. The downloadable starter helper itself was not provided, so this is a reconstruction, not a verbatim copy. One helper instance is initialized before the roster opens and reused for all CRUD operations.

The documents-directory file `MyDatabase.db` contains version 1 of `my_table`: `_id INTEGER PRIMARY KEY`, `name TEXT NOT NULL`, `age INTEGER NOT NULL`. SQLite generates insertion IDs. Reads explicitly sort by `_id ASC`; bound `whereArgs` target update/delete IDs. Nothing automatically inserts or seeds data at startup.

`lib/main.dart` loads rows and count from `initState()`. The form trims names and rejects empty names and ages that are not integers from 0 through 130. A single busy flag disables editing and database actions while a request is pending. Successful writes are followed by a fresh query. Write errors preserve input; refresh errors after a completed write are reported separately. A zero affected-row result is not labeled successful. Controllers are disposed, and asynchronous UI changes check `mounted`.

## Device verification

The app was built and installed on the Pixel_4a Android emulator (`emulator-5554`). `flutter analyze` reported **No issues found**, and `flutter build apk --debug` succeeded; actual outputs are saved in `evidence/analysis_output.txt` and `evidence/build_output.txt`. Device interactions were driven through Android Debug Bridge against the app's actual form, buttons, dialogs, and accessibility tree. No database rows were inserted through test code or SQL.

A = **ID 1**, River, age 21. B = **ID 2**, River, initially age 34, updated to 35.

| Test | Action/input | Expected | Observed rows/count | Result |
|---|---|---|---|---|
| T1 | Refresh empty installation | Count 0; empty-state message | Count 0; “No festival guests yet” | PASS |
| T2 | Add River/21 and River/34 | Distinct generated IDs; count 2 | ID 1 River/21; ID 2 River/34; count 2 | PASS |
| T3 | Edit B to 99 then Cancel; edit to 35 then Save | Cancel preserves 34; Save affects 1; A unchanged | Cancel left ID 2 at 34. Save affected 1; ID 1 stayed 21; ID 2 became 35; count 2 | PASS |
| T4 | Force-stop and reopen same installation | Same IDs, values, count | ID 1 River/21 and ID 2 River/35; count 2 | PASS |
| T5 | Cancel deletion of A; confirm deletion; Refresh | Cancel preserves 2; delete affects 1; only B remains | Cancel count 2; delete affected 1; Refresh showed only ID 2 River/35, count 1 | PASS |
| T6a | Space-only name, age 21 | Reject; B/count unchanged | Name error shown; ID 2 River/35 unchanged; count 1 | PASS |
| T6b | Maple, age abc | Reject; B/count unchanged | Integer-range error shown; ID 2 River/35 unchanged; count 1 | PASS |
| T6c | Maple, age 1.5 | Reject; B/count unchanged | Integer-range error shown; ID 2 River/35 unchanged; count 1 | PASS |
| T6d | Maple, age -1 | Reject; B/count unchanged | Integer-range error shown; ID 2 River/35 unchanged; count 1 | PASS |
| T6e | Maple, age 131 | Reject; B/count unchanged | Integer-range error shown; ID 2 River/35 unchanged; count 1 | PASS |
| T6f | Acorn, age 0 | Accept; count 2 | ID 3 Acorn/0 accepted; ID 2 unchanged; count 2 | PASS |
| T6g | Oak, age 130 | Accept; distinct ID; count 3 | ID 4 Oak/130 accepted; IDs 2 and 3 retained; final count 3 | PASS |

Screenshots: [before restart](evidence/T4_before.png), [after restart](evidence/T4_after.png), [rejected input](evidence/T6_invalid.png). Detailed observations are in `evidence/walkthrough_log.jsonl`.

T4 used `adb shell am force-stop com.het1406.local_storage_lab`, verified the process was absent, and launched the same installed app's launcher activity using `adb shell monkey -p com.het1406.local_storage_lab -c android.intent.category.LAUNCHER 1`. This performs an actual Android force-stop through ADB instead of tapping the App info button. There was no attached debugger, clearing of storage, uninstall, hot reload, or hot restart. Process IDs changed from 3602 to 4683; see `evidence/restart_method.txt`.

The initial build encountered insufficient disk space; the retry succeeded. The first accessibility read immediately after T4 relaunch occurred while the splash screen was still showing, so that cached snapshot was discarded. The test was verified again after loading, and the final screenshot shows the restored roster.

## Reflection 1 — Persistence prediction and implementation trace

Before T4, the recorded prediction was that ID 1 River/21, ID 2 River/35, and count 2 would survive because SQLite had committed those rows to `MyDatabase.db` (`evidence/T4_prediction.txt`). Startup awaits `DatabaseHelper.init()`, opens the existing file, then `_refresh()` calls `_read()` to query rows and count into widget state; no startup code inserts guests. After the force-stop/relaunch described above, both screenshots show the same IDs, values, and count. Missing or changed rows after that same-installation restart, or a restoration path that depended on reseeding, would contradict the persistence claim.

## Reflection 2 — Two Rivers, one wrong edit

Names are not unique: IDs 1 and 2 both displayed River, so name-based targeting could change both. The screen stores the selected integer `_id` and the helper binds it to `WHERE _id = ?`; saving ID 2 returned one affected row and changed only its age from 34 to 35 while ID 1 stayed 21. The earlier Cancel edit left ID 2 at 34 and count 2 because it cleared form state without invoking a write. See T3 entries in the walkthrough log and `lib/database_helper.dart`.

## Reflection 3 — Usability walkthrough

The device walkthrough showed both Rivers with visible IDs and ages, making the correct Edit target distinguishable, and the delete dialog identified the guest by ID and name. Cancel edit and Cancel deletion both left stored values unchanged, providing a way to recover from selecting an unintended action. One small improvement would be to focus the name field automatically when Edit is selected, making the active form easier to locate on a small screen. This is a proposed improvement, not an implemented feature.

## Reflection 4 — Storage boundary (graduate extension)

Form validation gives immediate feedback, but the schema's NOT NULL constraints alone allow empty names and ages outside 0–130 if another caller bypasses the form. Database CHECK constraints would strengthen integrity for multiple writers; this lab retains the specified schema and enforces its input policy at the single UI entry point. Editing only `onCreate` to add a future column would leave existing version-1 files unchanged, so a version increment and migration would be required. Local SQLite also does not automatically encrypt or synchronize records.

## Scope of supplied guide

The pasted guide included the build and test instructions but omitted the full submission/rubric sections and the expanded text of reflection prompts 2–4. The reflections above address the visible prompt titles and described design requirements; additional instructor requirements may exist in the original page.
