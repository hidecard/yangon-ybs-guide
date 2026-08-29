# YBS AI Play Store deliverables

ဒီ folder သည် Yangon YBS Guide V3 ၏ Play Store store-listing preparation package ဖြစ်ပါသည်။ Listing copy ကို `PLAY_STORE_PACKAGE.md` မှ copy/paste လုပ်နိုင်ပြီး၊ fields ကို `templates/STORE_LISTING_FIELDS.csv` မှ ကြည့်နိုင်ပါသည်။ Data Safety declaration သည် `templates/DATA_SAFETY_FORM_DRAFT.csv` တွင် draft အဖြစ်ပါရှိသည်။ Final production build ၏ actual SDK/backend data flow နှင့် developer ကိုယ်တိုင် ပြန်လည်အတည်ပြုရန်လိုပါသည်။

## Upload order

Play Console တွင် အရင်ဆုံး package name `net.arkaryan.ybs_guide` ဖြင့် app ကို create လုပ်ပါ။ ထို့နောက် privacy policy ကို live HTTPS URL တင်ပြီး App content ထဲတွင် Privacy Policy၊ Ads၊ Target audience၊ Content rating နှင့် Data Safety sections ကို ဖြည့်ပါ။ Main store listing တွင် Burmese copy ကို default language အဖြစ်ထည့်ပြီး English translation ကို optional အဖြစ်ထည့်ပါ။ `assets/app_icon_512x512.png`၊ `assets/feature_graphic_1024x500.png` နှင့် `assets/01_...` မှ `assets/05_...` အထိ screenshots ကို upload လုပ်ပါ။ Release အတွက် debug-signed AAB မဟုတ်ဘဲ upload-key/Play App Signing ဖြင့် ထုတ်ထားသော production AAB ကိုသာ အသုံးပြုပါ။

## Included files

`PLAY_STORE_PACKAGE.md` တွင် app identity၊ Burmese/English title၊ short description၊ long description၊ release notes၊ reviewer instructions၊ Data Safety draft၊ permission notes နှင့် checklist အားလုံးပါရှိပါသည်။ `templates/` တွင် CSV/text templates၊ `privacy_policy/PRIVACY_POLICY.md` တွင် public privacy page သို့ publish လုပ်ရန် copy၊ `assets/` တွင် feature graphic၊ icon နှင့် screenshot mockups၊ `tools/` တွင် assets ပြန်ထုတ်ရန်နှင့် validation run ရန် scripts ပါရှိပါသည်။

## Important release note

The current attached APK/AAB artifacts are useful for functional testing but are marked `signing_configured=false` and `play_store_release=false`. Configure the upload keystore secrets in GitHub Actions, generate a signed AAB, and upload that signed AAB to Play Console. Keep the package name unchanged because it is permanent after app creation.

## Validation

Run `python3 play_store/tools/validate_listing.py` from the repository root to verify listing field counts, image dimensions, and image file sizes. The current asset set passes the 512×512 icon, 1024×500 feature graphic, 1080×1920 portrait mockups, and 8 MB-per-image checks.
