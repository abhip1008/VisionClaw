# VisionClaw Dad Build — Manual Steps Checklist

All the **code** for Features A–K is already written and committed. The steps
below are the ones that require a GUI, an account, a physical device, or a secret
— they can't be scripted and must be done by hand. Do them in order.

The app target is at:
`samples/CameraAccess/CameraAccess.xcodeproj` → scheme **CameraAccess**.

---

## 1. Open the project & add Swift packages

```bash
open samples/CameraAccess/CameraAccess.xcodeproj
```

In Xcode → **File ▸ Add Package Dependencies…** and add:

```
https://github.com/google/GoogleSignIn-iOS
```

Select both products when prompted: **GoogleSignIn** and **GoogleSignInSwift**,
and add them to the **CameraAccess** target.

> The codebase is written so it compiles **without** this package (the Google
> features are behind `#if canImport(GoogleSignIn)`). Once the package is added,
> the calendar/email/meeting-prep features light up automatically. Until then
> those tools just report "Google Sign-In is not installed yet."

The new service files already build automatically — `CameraAccess/Services/` is
registered as a synchronized group in the project, so you do **not** need to add
the `.swift` files manually.

## 2. Gemini API key

1. Get a key at <https://aistudio.google.com/apikey>.
2. Create the secrets file:
   ```bash
   cd samples/CameraAccess
   cp CameraAccess/Secrets.swift.example CameraAccess/Secrets.swift
   ```
3. Put the key in `CameraAccess/Secrets.swift` (or enter it in the app under
   **Settings ▸ Gemini API**).

## 3. Google Cloud OAuth (Gmail + Calendar)

1. <https://console.cloud.google.com> → **New Project** → `VisionClaw Dad`.
2. **APIs & Services ▸ Library** → enable **Gmail API** and **Google Calendar API**.
3. **APIs & Services ▸ Credentials** → **Create Credentials ▸ OAuth client ID**.
   - Application type: **iOS**
   - Bundle ID: must match the app's bundle id
     (`com.meta.wearable.dat.cameraaccess` unless you changed it in Signing).
4. Download the plist Google gives you (e.g. `GoogleService-Info.plist` /
   `client_<...>.plist`). From it you need the **iOS client ID** and its
   **reversed client ID**.
5. In Xcode, add a **URL Scheme** equal to the *reversed client ID*:
   **Target ▸ Info ▸ URL Types ▸ +** → URL Schemes = `com.googleusercontent.apps.XXXX…`.
   (The app already calls `GoogleAuth.handle(url)` from `.onOpenURL`, so once the
   scheme is registered the sign-in callback works.)
6. Configure the Google client ID. Either drag the downloaded plist into the
   `CameraAccess` group, **or** set the client id in code where GoogleSignIn is
   configured. Simplest: drop the plist in and Google Sign-In picks it up.
7. Add yourself (Dad's Google account) as a **Test user** under the OAuth consent
   screen while the app is in "Testing".

## 4. OpenClaw (messaging / web / lists)

OpenClaw runs on the Mac and is what actually sends iMessages, etc. The ETA,
parking, geofence, check-in, and end-of-day messages all route through it.

```bash
brew install openclaw      # if not already installed
openclaw setup
nano ~/.openclaw/openclaw.json
```

Use a config like:

```json
{
  "gateway": {
    "port": 18789,
    "bind": "lan",
    "auth": { "mode": "token", "token": "make-up-a-password" },
    "http": { "endpoints": { "chatCompletions": { "enabled": true } } }
  }
}
```

```bash
openclaw gateway restart
curl http://localhost:18789/health     # expect {"status":"ok"}
```

Then in the app under **Settings ▸ OpenClaw** set **Host** (`http://YOUR-MAC.local`),
**Port** (`18789`), and the **Gateway token** you chose.

## 5. iOS Shortcuts for Focus mode (Feature I / K)

On Dad's iPhone, in the **Shortcuts** app create two shortcuts:

- **FocusOn** → action "Set Focus" → turn **Do Not Disturb On**.
- **FocusOff** → action "Set Focus" → turn **Do Not Disturb Off**.

Names must be exactly `FocusOn` and `FocusOff`.

## 6. Personalize the assistant (optional)

The system prompt refers to "the user." To use Dad's name, open
**Settings ▸ System Prompt** in the app and replace "the user" with his name, or
edit `defaultSystemInstruction` in `Gemini/GeminiConfig.swift`.

## 7. Build & run on the iPhone

1. Plug in the iPhone, select it as the run destination in Xcode.
2. Set your Apple Developer **Team** under **Signing & Capabilities**.
3. **Cmd+R**. Trust the developer certificate on the phone if prompted.
4. Grant **Microphone, Camera, Location, Reminders** when asked.
5. In the app: **Settings ▸ Google Account ▸ Connect Google account** and sign in.

## 8. Verify each feature

Use the test steps in `visionclaw-dad-build.md` (one per feature, sections A.8–K.3).
Quick smoke test:

- Start a session → after ~2s you should hear the **morning briefing**.
- Say "What's on my plate today?" → daily readback.
- Say "Remind me to call the dentist tomorrow at 10am" → calendar event.
- Say "Remember where I parked" → address + maps link, texted to self.

---

### What was automated vs. manual

**Automated (already in the repo):** all Swift services, tool declarations,
on-device tool routing, session wiring, system prompt, Info.plist permission keys,
and the Xcode project change that auto-builds the new `Services/` folder.

**Manual (this checklist):** Swift package add, Gemini key, Google OAuth client +
URL scheme, OpenClaw gateway, the two iOS Shortcuts, signing, and running on a
physical iPhone — none of which can be done from the command line.
