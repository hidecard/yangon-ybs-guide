# Yangon YBS Guide — Google Play Store package

## 1. App identity

| Field | Ready-to-use value |
|---|---|
| App name | **YBS AI - Yangon Bus Guide** |
| In-app label | **YBS AI** |
| Package name | `net.arkaryan.ybs_guide` |
| Current release | `3.3.4` (`versionCode 9`) |
| App type | App, not a game |
| Suggested category | Travel & Local |
| Suggested tags | Maps & Navigation, Public Transport, Travel |
| Ads declaration | **No ads** — confirm this remains true in the production build |
| Login requirement | No login required |
| Privacy policy URL | `https://YOUR-DOMAIN.example/privacy` — replace with a live HTTPS URL before submission |
| Support email | `info@arkaryan.net` — confirm that this inbox is monitored |
| Developer relationship note | Independent Yangon YBS guide; not an official YRTC/Yangon Bus Service app |

The package name is already established as `net.arkaryan.ybs_guide`; do not change it after creating the Play Console app. The production upload must use a properly signed AAB and Play App Signing/upload-key configuration.

## 2. Burmese store listing

### App title

**YBS AI - Yangon Bus Guide**

### Short description

**ရန်ကုန် YBS လမ်းကြောင်းရှာရန် မြန်မာ Assistant နှင့် Offline Guide**

### Full description

ရန်ကုန်မြို့တွင်း YBS စီးနင်းသွားလာရာမှာ လမ်းကြောင်းရှာရန်၊ မှတ်တိုင်များကြည့်ရန်နှင့် ပြောင်းစီးရမည့်အချက်များကို နားလည်လွယ်အောင် ကြည့်ရှုရန် YBS AI ကို အသုံးပြုနိုင်ပါသည်။

YBS AI သည် အောက်ပါအကူအညီများကို ပေးပါသည်။

• စတင်မှတ်တိုင်နှင့် ဆင်းမည့်မှတ်တိုင်ကို ရွေးချယ်ပြီး YBS လမ်းကြောင်းရှာခြင်း
• တိုက်ရိုက်လိုင်းများနှင့် ပြောင်းစီးရမည့် လမ်းကြောင်းများကို ကြည့်ခြင်း
• ကားလိုင်း၊ မှတ်တိုင် သို့မဟုတ် မြို့နယ်အမည်ဖြင့် ရှာဖွေခြင်း
• လမ်းကြောင်းအသေးစိတ်၊ စီးတက်/ဆင်းရမည့်မှတ်တိုင်နှင့် လမ်းလျှောက်အကွာအဝေးကို ကြည့်ခြင်း
• မြန်မာလို မေးမြန်းနိုင်သော YBS Assistant
• အင်တာနက်မရှိချိန်တွင်လည်း သိမ်းဆည်းထားသော route data ဖြင့် အခြေခံလမ်းကြောင်းရှာခြင်း
• အသုံးများသောလမ်းကြောင်းများကို အကြိုက်စာရင်းနှင့် ခရီးစဉ်မှတ်တမ်းတွင် သိမ်းခြင်း
• လိုအပ်သည့် trip အတွက်သာ ရောက်ခါနီး သတိပေးချက်ကို ဖွင့်ခြင်း
• လမ်းပေါ်အခြေအနေအလိုက် ရရှိနိုင်လျှင် live ETA၊ bus position နှင့် arrival information ကို ကြည့်ခြင်း

**Privacy နှင့် permission**

Near Me၊ map location၊ live tracking သို့မဟုတ် arrival alert ကို သင်ရွေးချယ်သည့်အခါမှသာ location permission ကို အသုံးပြုပါသည်။ Arrival alert ဖွင့်ထားချိန်တွင် background location နှင့် notification permission လိုအပ်နိုင်ပါသည်။ Route search အတွက် route data ကို device ထဲတွင် သိမ်းဆည်းထားသဖြင့် offline အခြေအနေတွင်လည်း အခြေခံရှာဖွေမှုကို ဆက်သုံးနိုင်ပါသည်။ YBS AI သည် microphone recording ကို local assistant အတွက် မသုံးပါ။ အသေးစိတ်ကို Privacy Policy တွင် ဖတ်ရှုပါ။

Live ETA နှင့် bus position များသည် network နှင့် ရရှိနိုင်သော service data အပေါ် မူတည်ပါသည်။ အချိန်မှန်မှုကို အာမမခံပါ။ ခရီးထွက်ရာတွင် လမ်းအခြေအနေ၊ ယာဉ်ကြောနှင့် operator ပြောင်းလဲမှုများကိုလည်း ထည့်သွင်းစဉ်းစားပါ။

YBS AI သည် Yangon YBS အချက်အလက်များကို အသုံးပြုသည့် independent guide ဖြစ်ပြီး YRTC၊ Yangon Bus Service သို့မဟုတ် အခြားသယ်ယူပို့ဆောင်ရေးအဖွဲ့အစည်းတစ်ခု၏ official app မဟုတ်ပါ။

### Burmese release notes — version 3.3.4

Assistant chat စာရိုက်ရန်နေရာကို ပြန်လည်မြင်ရပြီး မြန်မာလို စာရိုက်ကာ Send ခလုတ်ဖြင့် မေးမြန်းနိုင်ပါပြီ။ Route Plan Detail ကို ရိုးရှင်းစေပြီး မလိုအပ်သော re-plan card နှင့် ထပ်နေသော control များကို ဖယ်ရှားထားပါတယ်။ Light mode ပုံစံကို ဆက်လက်ထိန်းထားပါတယ်။

## 3. English store listing

### App title

**YBS AI - Yangon Bus Guide**

### Short description

**Find Yangon YBS routes, transfers, stops and alerts with a Burmese assistant.**

### Full description

YBS AI helps you find Yangon YBS bus routes, stops, transfers, and trip details in a simple interface designed for everyday travel.

With YBS AI, you can:

• Search for a route between a starting stop and a destination stop.
• Compare direct routes and routes that require transfers.
• Search by bus line, stop name, or township.
• View boarding and alighting stops, route details, and walking guidance.
• Ask the Burmese YBS Assistant for route help.
• Continue basic route search with the bundled route data when you are offline.
• Save favourite routes and keep a local history of recent searches.
• Enable an arrival alert only for a trip when you need it.
• View live ETA, bus position, and arrival information when the service data is available.

**Privacy and permissions**

Location permission is used only when you choose Near Me, map location, live tracking, or an arrival alert. Background location and notification permission may be required while an arrival alert is explicitly enabled. Route data is stored on the device so basic route search can continue offline. YBS AI does not use microphone recording for the local assistant. See the Privacy Policy for details.

Live ETA and bus-position information depends on network connectivity and available service data; accuracy and availability are not guaranteed. Please also consider traffic, road conditions, and operator changes when travelling.

YBS AI is an independent Yangon YBS guide and is not an official app of YRTC, Yangon Bus Service, or another transport authority.

### English release notes — version 3.3.4

Restored the visible Assistant chat composer with Burmese text input and a Send action. Simplified Route Plan Detail by removing redundant re-planning and duplicate controls. Kept the original light-mode experience.

## 4. Store listing asset plan

| Order | File | Feature message | Recommended use |
|---:|---|---|---|
| 1 | `01_find_route_1080x1920.png` | လမ်းကြောင်းကို အလွယ်တကူရှာပါ | First screenshot: core value |
| 2 | `02_route_directory_1080x1920.png` | ကားလိုင်းများကို လျင်မြန်စွာကြည့်ပါ | Route directory |
| 3 | `03_burmese_assistant_1080x1920.png` | မြန်မာလို မေးပြီး လမ်းကြောင်းရှာပါ | Assistant feature |
| 4 | `04_trip_plan_1080x1920.png` | ပြောင်းစီးမှုကို ရှင်းလင်းစွာသိပါ | Transfer planning |
| 5 | `05_offline_alerts_1080x1920.png` | Offline data နှင့် သတိပေးချက် | Offline/alert value |

The screenshots are intentionally portrait, text-safe mockups that match the current light UI and use the app's navy/amber brand palette. The screenshots should be uploaded only after checking them against the final production build so every visual claim remains accurate.

## 5. Play Console app-content draft

| Play Console section | Draft answer | Confirmation needed |
|---|---|---|
| App access | No login or restricted access. | Confirm no feature is hidden behind an account in the production build. |
| Ads | No. | Confirm no ad SDK or ad placement is included. |
| Target audience | General public transport utility; not specifically directed to children. | Select the age groups that match the developer's intended audience. |
| Content rating | No violence, sexual content, gambling, drugs, or user-generated social content. | Complete the official questionnaire rather than copying this summary blindly. |
| News/Magazine | No. | Confirm the app is categorized as Travel & Local rather than News. |
| COVID-19 functionality | No. | Confirm there is no such feature. |
| Data safety | See the worksheet below. | Confirm every SDK/backend behavior against the final signed AAB. |
| Privacy policy | Required live HTTPS URL. | Publish `PRIVACY_POLICY.md` at a stable public URL and enter it in both Play Console and the app. |
| Sensitive permissions | Location and background location are used for optional arrival alerts/live tracking. | Provide a clear in-app disclosure and reviewer instructions; Play Console may request additional permission declarations. |

## 6. Data Safety worksheet draft

This is a **draft for the Play Console form**, not a legal determination. Google requires the developer to submit complete and accurate answers for the final app and all SDKs.

| Data category | Draft collection status | Purpose | Shared off-device? | Notes |
|---|---|---|---|---|
| Precise location | Collected only when the user enables Near Me, map location, live tracking, or arrival alert. | App functionality. | Not sent as GPS coordinates to the YBS API according to the current policy draft. | Verify third-party location/OS processing and the final implementation. |
| Approximate location | Same user-triggered location flows may expose approximate location through the OS. | App functionality. | Not sent as GPS coordinates to the YBS API according to the current policy draft. | Confirm SDK behavior. |
| App activity: search history/favourites/saved trips | Stored locally on device. | App functionality. | No, unless a future backup/sync feature is added. | Deletable by in-app controls or clearing app storage. |
| Device/app technical data | May be processed by the OS, map tiles, notification libraries, and network infrastructure. | App functionality, analytics/operations only if actually enabled. | Confirm against provider policies. | Do not mark analytics unless an analytics SDK is present. |
| Notifications | Permission and local notification state may be stored. | App functionality. | No for local notification content; provider behavior must be checked. | Used for explicit arrival alerts. |
| User-generated text | Assistant questions and feedback text may be sent to the configured service when the user submits it. | App functionality. | Potentially yes, depending on endpoint logging/processing. | Confirm API retention and whether feedback endpoints store content. |

Suggested security answers, **only if confirmed by the final deployment**: data is encrypted in transit for HTTPS endpoints; users can delete local data by app controls or clearing storage; no account credentials are collected; no sale of personal data; no advertising ID use unless a future SDK adds it.

## 7. Reviewer access instructions

Paste the following into the reviewer-access or additional-instructions field if the final build remains account-free:

> No login or special account is required. Open the app and select **လမ်းကြောင်း / Routes** from the bottom navigation. Search for a route or open a route card to view route details. To test optional arrival alerts, open a route plan, tap the arrival-alert control, allow location and notification permissions when prompted, and then disable the alert again. The app's core route directory and basic route search are available without location permission. Live ETA and bus-position panels may show a retry/offline message when service data is unavailable. The YBS New feature is intentionally hidden in this release.

## 8. Privacy policy publication template

Recommended public URL: `https://YOUR-DOMAIN.example/privacy`.

Publish the repository file `flutter_app/PRIVACY_POLICY.md` at that URL without changing it to claim data practices that the production build does not implement. Keep the same URL active after submission and update both the public page and in-app privacy section whenever the data flow changes.

## 9. Release checklist

| Status | Task |
|---|---|
| [ ] | Create the Play Console app with the permanent package name `net.arkaryan.ybs_guide`. |
| [ ] | Configure Play App Signing and upload-key secrets in the release workflow. |
| [ ] | Build a production-signed AAB; do not upload the current debug-signed artifact. |
| [ ] | Confirm `targetSdk = 36` and the Play Console target-API notice for the submission date. |
| [ ] | Publish the privacy policy at an active HTTPS URL and add the same URL in-app and in Play Console. |
| [ ] | Complete Data Safety, Ads, Target audience, Content rating, and sensitive-permission declarations. |
| [ ] | Upload app icon, feature graphic, and five screenshots from `play_store/assets/`. |
| [ ] | Enter Burmese listing copy as the default language; add English as a translation if desired. |
| [ ] | Upload release notes for version `3.3.4` / version code `9`. |
| [ ] | Run internal testing first, verify installation/update behavior, then follow any personal-account testing requirement shown in Play Console. |
| [ ] | Inspect the pre-review checks and resolve all errors before production rollout. |
| [ ] | Start with a staged rollout when the first production release is ready. |

## References

[1]: https://support.google.com/googleplay/android-developer/answer/13393723?hl=en-GB "Best practices for your store listing"
[2]: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en "Add preview assets to showcase your app"
[3]: https://support.google.com/googleplay/android-developer/answer/11926878?hl=en "Target API level requirements for Google Play apps"
[4]: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en "Provide information for Google Play's Data safety section"
[5]: https://support.google.com/googleplay/android-developer/answer/9859455?hl=en "Prepare your app for review"
[6]: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en "Create and set up your app"
[7]: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en "Prepare and roll out a release"
