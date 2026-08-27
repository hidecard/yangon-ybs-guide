# Play Store release references

These references were consulted for the V3 Android release configuration.

1. Google Play policy announcement (July 15, 2026): https://support.google.com/googleplay/android-developer/answer/17134731?hl=en
   - Google Play requires apps to meet the latest target API requirements by August 31, 2026.
   - The announcement also highlights developer verification, user-data disclosures, content ratings, and location disclosure guidance.

2. Android app signing: https://developer.android.com/studio/publish/app-signing
   - Android APKs must be digitally signed before installation or distribution.
   - Play App Signing separates the upload key from the app-signing key; upload keys must remain private.
   - Debug certificates are not accepted by most app stores, including Google Play.

3. Flutter Android deployment: https://docs.flutter.dev/deployment/android
   - Flutter release builds for Play Store should use a signed Android App Bundle where possible.
   - `key.properties` and keystore files must not be committed to source control.
   - Android release configuration should verify application ID, SDK versions, version code/name, manifest permissions, signing, and release artifacts.
