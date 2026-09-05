# YBS Passenger AR — Flutter MVP

ဒီ folder က `hidecard/yangon-ybs-guide` V3 repository ထဲသို့ ထည့်ထားသော **Flutter Android/iOS companion app** ဖြစ်ပါတယ်။ ရည်ရွယ်ချက်က ကားမောင်းသူအတွက် navigation မဟုတ်ဘဲ **YBS ခရီးသည်အတွက် route ရွေးခြင်း → Normal Map → Passenger AR → Next Stop / Get-off Alert** flow ကို တည်ဆောက်ရန် ဖြစ်ပါတယ်။

## Implemented flow

1. V3 ရဲ့ `public/routes/*.json` data 147 ဖိုင်ကို Flutter assets အဖြစ် load လုပ်ခြင်း။
2. YBS route၊ တက်မည့်မှတ်တိုင်၊ ဆင်းမည့်မှတ်တိုင် ရွေးခြင်း။
3. Google Maps ပေါ်တွင် route polyline၊ boarding stop၊ destination stop နှင့် လက်ရှိ GPS location ပြခြင်း။
4. GPS နဲ့ route ပေါ်ရှိ အနီးဆုံး stop ကို match လုပ်ခြင်း။
5. Next stop၊ distance၊ remaining stops ပြခြင်း။
6. 3 stops / 1 stop / destination ရောက်ချိန်တွင် Burmese TTS နှင့် vibration alert ပေးခြင်း။
7. Camera + compass ပါသော Passenger AR view တွင် next-stop label၊ destination status နှင့် direction indicator ပြခြင်း။

## Important AR note

လက်ရှိ Flutter MVP ရဲ့ AR view က **camera background + compass-aware overlay** ဖြစ်ပါတယ်။ Road surface ပေါ်ကို world-anchored 3D arrow တိတိကျကျ ချရန် production အဆင့်မှာ Android အတွက် ARCore၊ iOS အတွက် ARKit ကို platform channel/native view ဖြင့် ချိတ်သင့်ပါတယ်။ အဲဒီအဆင့်အထိ မရောက်ခင် GPS/compass accuracy ကို စမ်းသပ်နိုင်ရန် ဒီ MVP ကို အသုံးပြုနိုင်ပါတယ်။

## Run

Flutter SDK မပါရှိသော environment တွင် source scaffold ကို ပြင်ဆင်ထားခြင်းဖြစ်သောကြောင့် local machine တွင် Flutter SDK ထည့်ပြီး run လုပ်ပါ။

```bash
cd flutter_app
flutter pub get
flutter create .
flutter run
```

`flutter create .` ကို source files များမပျက်စေရန် မလုပ်မီ backup/commit ပြုလုပ်ထားပါ။ Existing `lib/` နှင့် `assets/` များကို ထားရှိပြီး platform folders များသာ generate လုပ်ပါ။

## API keys and permissions

Google Maps API key ကို Android/iOS platform configuration တွင် ထည့်ရန်လိုပါတယ်။

### Android `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />

<application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_GOOGLE_MAPS_KEY" />
</application>
```

### iOS `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>YBS route progress and next-stop alerts အတွက် location လိုအပ်ပါသည်။</string>
<key>NSCameraUsageDescription</key>
<string>Passenger AR view အတွက် camera လိုအပ်ပါသည်။</string>
<key>NSMotionUsageDescription</key>
<string>AR direction indicator အတွက် device motion လိုအပ်ပါသည်။</string>
```

## Suggested next production steps

- GPS position ကို stop sequence နဲ့ ပိုတိကျစွာ map-match လုပ်ရန်။
- Bus speed / traffic data ထည့်ပြီး ETA ပြင်ရန်။
- Background location နှင့် lock-screen notification ကို privacy/OS policy အတိုင်း ထည့်ရန်။
- Native ARCore/ARKit world tracking ဖြင့် road/stop anchor များ တည်ငြိမ်အောင်လုပ်ရန်။
- GPS မရသောအခါ Normal Map fallback နှင့် accuracy warning ထည့်ရန်။
