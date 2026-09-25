# ProDefact Android APK QA checklist

For testers checking a ProDefact APK on a real Android phone. Each test
says what to do and what you should see. Mark each one Pass or Fail, and
for a Fail, add a screenshot and one sentence on what happened instead.

## Before you start

1. Install the APK. If an older ProDefact is installed, install over it.
2. Open **Profile** and scroll to the bottom. Note the three lines:
   `ProDefact QA`, `Version: …`, `Build: …`. Put the **Build** value on
   every bug report and screenshot. If it says `Build: not stamped`, ask
   for a correctly built APK before testing.
3. Sign in, and make sure the phone has internet unless a test says
   otherwise.

## Tests

### 1. Optional areas (QA #13, #21)
Start a New Inspection. Inspect only the areas the unit really has, for
example Living, Kitchen and Master Bedroom. Add a finding in one, and
use **No Defects · Mark Area Complete** in another. Ignore the rest.

- **Complete Physical Inspection** is enabled as soon as one area is
  inspected.
- The confirmation says how many suggested areas were not visited and
  that they are left out of the report.
- You never had to add a fake finding or switch an area off.

### 2. Photo, markup, quick note, save (QA #14, #16, #26)
In an area, tap **Take Defect Photo**, then take a photo. Tap
**Mark Up**, draw with at least three colours, try **Undo** and
**Clear**, draw again, then **Save**. Type a **Quick defect note** such
as `tile holo`, then **Save Finding**.

- The whole photo shows, never cut off.
- After Save Finding you are back in the area straight away, with no
  spinner blocking you, and can take the next photo at once.
- The finding shows your markup. Opening the photo and tapping
  **Show Original** shows the unmarked photo.

### 3. Three photos of one defect (QA #20)
On a finding, tap **Add angle** twice: one from the camera, one from the
gallery.

- One finding shows three thumbnails.
- Tapping a thumbnail opens **Photo 1 of 3** and you can swipe through.
- **Remove Photo** removes only that photo. When one photo is left,
  Remove Photo is disabled.

### 4. Portrait and landscape (QA #18, #19)
Add one finding with a portrait photo and one with a landscape photo.

- In the preview, the photo viewer, and AI Review, each photo keeps
  its own shape: nothing is cropped or stretched.

### 5. AI keeps running when you move on (QA #11)
Turn on **Auto Analyse**. Save a finding with a note, go straight back
and open a different area, and keep inspecting.

- Nothing waits for AI. When you return to the first area later, the
  finding shows its AI result (or **Needs manual review**).

### 6. Complete while AI is still running (QA #22)
Save a finding, then immediately tap **Complete Physical Inspection**.

- The inspection completes. The confirmation says AI keeps analysing in
  the background.
- The report cannot be generated until AI and review are done.

### 7. Offline and recovery (QA #26)
Turn on airplane mode. Save a finding with a note.

- The finding saves. Its status says **Waiting for connection**.

Turn airplane mode off.

- Within a moment it changes to **AI analysing…**, then shows a
  result, with no need to reopen anything.
- With internet on, you never see **Waiting for connection**.

Extra check: while a finding shows **AI analysing…**, close the app
completely and reopen the inspection. It must finish or show
**AI analysis failed** with a **Retry** button. It must never spin
forever.

### 8. House Pass active (QA #23)
Buy a House Pass for an inspection from **Wallet → House Pass**, then
analyse a finding in that inspection.

- The inspection screen never asks you to choose House Pass or Credits.
- The analysis says it is included with this inspection.

### 9. No House Pass (QA #23, #24)
In an inspection with no House Pass, analyse a finding.

- The dialog says **Smart AI** and **Up to N Credits**, with no Fast,
  Smart or Expert choice and no billing choice.
- Credits are charged once. Check the Wallet activity.

### 10. Status filters (QA #25)
On the inspection screen, tap each filter: **All**, **Not started**,
**In progress**, **Completed**.

- The selected chip is highlighted, the list changes, and each chip's
  number matches what is listed.
- An empty filter says so rather than showing a blank list.
- On the Inspections list, the filter chips also narrow everything,
  including **Needs attention**.

### 11. Newly discovered area (QA #12)
On the inspection screen, tap **Add Newly Discovered Area** and add
`Laundry Loft`.

- It appears in the area list straight away and you can add a finding
  to it.
- Starting a new inspection afterwards does not list Laundry Loft as a
  suggested area.

### 12. Report with uncropped photos (QA #19)
Finish review, add the client contact number, and generate the report.

- Every photo appears whole, in its own orientation, and marked-up
  photos show the markup.
- Areas you never visited do not appear in the report.

## Bottom sheets (QA #15)
While doing the tests above, especially on a small phone or with large
text turned on in Android settings, check that the **Save Finding** and
**Discard** buttons are never hidden behind the navigation bar or the
keyboard.

## Building a test APK (for developers)

```
flutter build apk --debug \
  --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
```

Also bump the build number in `pubspec.yaml` (`version: x.y.z+N`) for
every APK you hand out.
