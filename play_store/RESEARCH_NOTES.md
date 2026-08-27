# Google Play research notes

Prepared for Yangon YBS Guide V3 (`net.arkaryan.ybs_guide`, version `3.3.4+9`).

## Official requirements used

- Google Play app title: 30 characters or fewer.
- Short description: 80 characters or fewer.
- Full description: up to 4,000 characters.
- Store listing copy and graphics must accurately describe the app and must not imply an official relationship with another organization, make ranking/price claims, or use misleading references.
- Preview assets include the app icon, short description, feature graphic, screenshots, and optional preview video. Important content should remain near the centre because assets can appear across different screen sizes.
- Google Play requires a completed Data safety form and a privacy policy link for published apps, including apps that do not collect user data. The declaration must match the app and all third-party SDK behavior.
- Review preparation includes privacy policy, ads declaration, target audience/content rating, sensitive-permission declarations where applicable, and reviewer access instructions when login/restricted access exists.
- Google Play uses Android App Bundles for current distribution. Package names are unique and permanent, so the existing application ID must not change.
- As of the official target API page accessed on 2026-08-27, new apps and app updates must target Android 16 / API 36 or higher starting 2026-08-31. This project currently sets `compileSdk = 36` and `targetSdk = 36`.
- Developers with personal accounts created after 2023-11-13 may need to satisfy Play Console testing requirements before production availability.

## App-specific facts to keep consistent

- Product name: YBS AI / Yangon YBS Guide.
- Package: `net.arkaryan.ybs_guide`.
- Current release: `3.3.4+9`.
- Light theme only; the former theme switch is intentionally removed.
- YBS New is temporarily hidden for this Play Store release.
- Core features: Yangon bus route directory, route search, transfer planning, offline route bundle, favourites/recent searches, optional location-assisted stop selection, optional arrival alerts, route map, and Burmese YBS Assistant.
- Live ETA/prediction data is best-effort and may be unavailable; listing copy must not promise guaranteed live accuracy.
- Background location and notifications are optional and used for an explicitly enabled arrival alert; the app does not claim always-on tracking.
- Current artifacts from the last build were debug-signed because CI signing secrets were not configured. Play Store upload requires a properly signed AAB with Play App Signing/upload-key setup.

## Sources

1. https://support.google.com/googleplay/android-developer/answer/13393723?hl=en-GB — Best practices for your store listing.
2. https://support.google.com/googleplay/android-developer/answer/9866151?hl=en — Add preview assets to showcase your app.
3. https://support.google.com/googleplay/android-developer/answer/11926878?hl=en — Target API level requirements for Google Play apps.
4. https://support.google.com/googleplay/android-developer/answer/10787469?hl=en — Provide information for Google Play's Data safety section.
5. https://support.google.com/googleplay/android-developer/answer/9859455?hl=en — Prepare your app for review.
6. https://support.google.com/googleplay/android-developer/answer/9859152?hl=en — Create and set up your app.
7. https://support.google.com/googleplay/android-developer/answer/9859348?hl=en — Prepare and roll out a release.

> Policy-sensitive declarations must be confirmed by the developer in Play Console against the final production build and the actual backend/SDK data flows.
