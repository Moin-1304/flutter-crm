# Google Maps setup (Android & iOS)

The app uses Google Maps (DCR map view, attendance/punch screen, map picker). If you see:

- **Blank or grey/beige map** (no roads, no tiles) but visit count or pins are shown
- **"App not responding"** or logs like `Authorization failure` / `API Key: YOUR_GOOGLE_MAPS_API_KEY`
- `Skipped 34 frames!` / `ClientParametersBlockedOnMainThread`

the cause is usually a **missing or invalid Google Maps API key**. Without a valid key, the map view opens but tiles do not load.

## 1. Get an API key

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Enable **Maps SDK for Android** and **Maps SDK for iOS**:  
   **APIs & Services → Library** → search **"Maps SDK for Android"** / **"Maps SDK for iOS"** → **Enable**.
4. Create an API key: **APIs & Services → Credentials → Create credentials → API key**.
5. (Recommended) Restrict the key:
   - **Android**: Application restrictions → Android apps → Add package name `com.iotecksolutions.todoapp` and your SHA-1 (see below).
   - **iOS**: Application restrictions → iOS apps → Add your bundle ID (e.g. from Xcode or `ios/Runner/Info.plist`).
6. Ensure **billing** is enabled for the project (required for Maps even on free tier).

## 2. Configure the app

### Android

1. Copy `android/local.properties.example` to `android/local.properties` if you don’t have it.
2. Ensure the file has `sdk.dir=...` (Flutter usually adds this). Set your **real** key:

   ```properties
   sdk.dir=/path/to/your/Android/sdk
   GOOGLE_MAPS_API_KEY=AIza...your_actual_key_here
   ```

3. Save the file. `local.properties` is gitignored, so the key is not committed.
4. **Full rebuild**: run `flutter clean` then `flutter run` (or rebuild from your IDE). Hot reload is not enough.

The app reads `GOOGLE_MAPS_API_KEY` from `android/local.properties` at build time and injects it into the manifest. If the key is missing, the map will stay blank.

### iOS

1. Copy `ios/Flutter/GoogleMapsKey.xcconfig.example` to `ios/Flutter/GoogleMapsKey.xcconfig`.
2. Edit `ios/Flutter/GoogleMapsKey.xcconfig` and set your key:

   ```
   GOOGLE_MAPS_API_KEY=AIza...your_actual_key_here
   ```

3. Save the file. `GoogleMapsKey.xcconfig` is gitignored, so the key is not committed.
4. Rebuild the app (e.g. `flutter run` or build from Xcode).

The app reads the key from this xcconfig at build time (via Info.plist). If the file is missing or the key is empty, the map will stay blank.

**Tip:** Use the same API key as Android — copy the value of `GOOGLE_MAPS_API_KEY` from `android/local.properties` into `ios/Flutter/GoogleMapsKey.xcconfig` (and enable **Maps SDK for iOS** in Google Cloud for that key).

### iOS map still blank?

1. **Check Xcode console** when you run the app. If you see  
   `MAPS: Google Maps API key not set for iOS...`  
   then create `ios/Flutter/GoogleMapsKey.xcconfig` from the example and add your key, then rebuild.

2. **Enable Maps SDK for iOS** in [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Library → search **Maps SDK for iOS** → Enable.

3. **Full rebuild:** `flutter clean` then `flutter run` (or Product → Clean Build Folder in Xcode, then run).

## 3. Verify

- Run the app and open a screen that uses the map (e.g. **Map View For Doctors Visits** or Sales Rep map from Manager Review).
- You should see **map tiles** (roads, terrain) and **markers** for visits.

**If you set the key (Android: `local.properties` / iOS: `GoogleMapsKey.xcconfig`) and rebuilt but the map is still blank**, the key is reaching the app but Google is rejecting it.

**See the exact error from Google:** On your **computer** (not inside the emulator), open **Terminal** (or Cursor’s terminal). With the app open on the map screen, run:
```bash
adb logcat -d | grep -iE "authorization failure|api key not valid|not authorized to use|API_KEY|api.key invalid"
```

**Mac:** If you see `command not found: adb`, use:

```bash
$HOME/Library/Android/sdk/platform-tools/adb logcat -d | grep -iE "authorization failure|api key not valid|not authorized to use|API_KEY|api.key invalid"
```

Look for lines like "Authorization failure", "This API project is not authorized to use this API", or "API key not valid". You can also tap the **?** (help) icon on the map screen to copy the Mac command and view the checklist.

Then in [Google Cloud Console](https://console.cloud.google.com/) for the project that owns the key:

1. **APIs & Services → Library** → search **Maps SDK for Android** → ensure it is **Enabled**.
2. **Billing** → ensure a billing account is linked (Maps requires it even for free tier).
3. **APIs & Services → Credentials** → click your API key:
   - If **Application restrictions** is set to "Android apps", add:
     - Package name: `com.iotecksolutions.todoapp`
     - SHA-1 certificate fingerprint: get it with  
       `keytool -list -v -keystore ~/.android/debug.keystore`  
       (password: `android`), then copy the SHA-1 line.
   - To test quickly, you can temporarily set restrictions to **None**; if the map loads, then add the Android restriction with the correct package and SHA-1.

## Log reference

- **Package name**: `com.iotecksolutions.todoapp`
- **Debug SHA-1** (for key restriction):  
  `keytool -list -v -keystore ~/.android/debug.keystore` (default password: `android`)
