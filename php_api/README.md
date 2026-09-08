# YBS AI PHP + MySQL API

ဒီ folder က Flutter V3 App ရဲ့ **Notification** နဲ့ **Feedback** အတွက် PHP 8.1+ / MySQL 8 REST API ဖြစ်ပါတယ်။ လက်ရှိ Flutter `ApiService` နဲ့ endpoint path နဲ့ JSON response ကို တိုက်ရိုက်ကိုက်ညီအောင်ရေးထားပါတယ်။

## Endpoints

| Method | Endpoint | Auth | ရည်ရွယ်ချက် |
|---|---|---|---|
| `GET` | `/api/notifications?limit=50` | မလို | Published notification များကို App ကဖတ်ရန် |
| `POST` | `/api/notifications` | `X-Admin-Token` | Admin က notification အသစ်ပို့ရန် |
| `POST` | `/api/feedback` | မလို | App user feedback ပို့ရန် |

### Notification GET response

```json
{
  "notifications": [
    {
      "id": 1,
      "title": "YBS AI Update",
      "message": "Route data updated.",
      "type": "update",
      "createdAt": 1725000000000
    }
  ]
}
```

### Admin notification publish body

```json
{
  "title": "YBS 117 Update",
  "message": "ယနေ့ လမ်းကြောင်းအခြေအနေ ပြောင်းလဲထားပါသည်။",
  "type": "alert"
}
```

### Feedback body

```json
{
  "type": "bug",
  "message": "Map Picker မှတ်တိုင်ရွေးမရပါ။",
  "routeId": "117",
  "userId": "optional-device-or-user-id"
}
```

Feedback type များမှာ `bug`, `wrong_info`, `suggestion`, `other` ဖြစ်ပါတယ်။ IP hash အလိုက် တစ်နာရီအတွင်း feedback ၁၀ ခုအထိပဲ လက်ခံထားပါတယ်။

## Installation

### 1. Database တည်ဆောက်ရန်

```bash
mysql -u root -p < schema.sql
```

#### Shared hosting / phpMyAdmin သုံးသူများ

Screenshot လို `#1044 Access denied ... to database` error ပေါ်တာက hosting user မှာ database အသစ်ဖန်တီးခွင့်မရှိလို့ပါ။ `schema.sql` ထဲက `CREATE DATABASE ybs_ai` နဲ့ `USE ybs_ai` ကို shared hosting မှာ မ run ပါနှင့်။ Hosting control panel က ဖန်တီးပေးထားတဲ့ ရှိပြီးသား database ကို select လုပ်ပြီး `schema_hosting.sql` ကို run ပါ။

phpMyAdmin အဆင့်များ:

1. ဘယ်ဘက်က hosting ဖန်တီးပေးထားတဲ့ database ကို click/select လုပ်ပါ။ ဥပမာ `zulszwhh_ybsai`။
2. **Import** သို့မဟုတ် **SQL** ကိုဖွင့်ပါ။
3. `schema_hosting.sql` ကို upload/paste လုပ်ပါ။
4. Run/Go နှိပ်ပါ။ `notifications` နဲ့ `feedback` tables နှစ်ခု ပေါ်လာရပါမယ်။
5. cPanel **MySQL Databases** မှာ API သုံးမယ့် MySQL user ကို အဲဒီ database နဲ့ add/assign လုပ်ပြီး **All Privileges** ပေးပါ။

`.env` ထဲက `DB_NAME` ကို database အမည်အပြည့်၊ `DB_USER` ကို hosting user အမည်အပြည့်နဲ့ ထည့်ပါ။ ဥပမာ:

```env
DB_NAME=zulszwhh_ybsai
DB_USER=zulszwhh_api
DB_PASS=hosting-mysql-user-password
```

Database နာမည်ကို ကိုယ်တိုင် `ybs_ai` လို့ မပြောင်းပါနှင့်။ Hosting panel မှာ ပေးထားတဲ့ prefix ပါတဲ့အမည်ကို အတိအကျသုံးပါ။

Production မှာ `schema.sql` အောက်ဆုံးက dedicated database user commands ကို password အသစ်နဲ့ ပြင်ပြီး run ပါ။ Root database account ကို API ထဲမသုံးပါနှင့်။

### 2. Environment ပြင်ရန်

```bash
cp .env.example .env
```

`.env` ထဲမှာ MySQL username/password နဲ့ admin token ထည့်ပါ။ `.env` ကို public web root အောက် မထားဘဲ `php_api/.env` အဖြစ်ထားပါ။ Git ထဲ မတင်ပါနှင့်။

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=ybs_ai
DB_USER=ybs_api
DB_PASS=your-long-db-password
ADMIN_API_TOKEN=your-long-random-admin-token
```

Server က environment variables ပေးနိုင်ရင် `.env` မသုံးဘဲ server environment ထဲသတ်မှတ်နိုင်ပါတယ်။ PHP PDO extension နဲ့ `pdo_mysql` ဖွင့်ထားရပါမယ်။

### 3. Apache hosting

Document root ကို `php_api/public` သို့ point လုပ်ပါ။ `public/.htaccess` က `/api/...` အားလုံးကို `index.php` သို့ route လုပ်ပေးပါမယ်။ HTTPS သုံးပါ။

Shared hosting မှာ document root မပြောင်းနိုင်ရင် `public` folder contents ကို API subdomain ရဲ့ public folder ထဲတင်ပြီး `.env` ကို public folder အပြင်မှာထားပါ။

### 4. Local test server

```bash
cd php_api
php -S 127.0.0.1:8080 -t public public/index.php
```

Local test အတွက် Flutter `AppConfig.apiBase` ကို `http://10.0.2.2:8080` (Android emulator) သို့မဟုတ် computer LAN IP သို့ပြောင်းပါ။ Production မှာ `https://api.your-domain.com` သုံးပါ။

## Test commands

Notification ဖတ်ရန်:

```bash
curl -i 'https://api.example.com/api/notifications?limit=20'
```

Admin notification ပို့ရန်:

```bash
curl -i -X POST 'https://api.example.com/api/notifications' \
  -H 'Content-Type: application/json' \
  -H 'X-Admin-Token: YOUR_ADMIN_API_TOKEN' \
  -d '{"title":"YBS Update","message":"Route data updated.","type":"update"}'
```

Feedback ပို့ရန်:

```bash
curl -i -X POST 'https://api.example.com/api/feedback' \
  -H 'Content-Type: application/json' \
  -d '{"type":"suggestion","message":"Map UI ကို ပိုကောင်းအောင်လုပ်ပေးပါ။","routeId":"117"}'
```

## Flutter ချိတ်ရန်

လက်ရှိ Flutter code မှာ အောက်ပါ paths သုံးထားပြီးသားဖြစ်လို့ API base URL ပဲ ပြောင်းရန်လိုပါတယ်။

```dart
GET  /api/notifications?limit=50
POST /api/feedback
```

`lib/config.dart` ထဲက `AppConfig.apiBase` ကို PHP API URL သို့ပြောင်းပါ။ Feedback အောင်မြင်ရင် Flutter ရဲ့ `postFeedback()` က `true` ပြန်ရပါမယ်။

## Admin dashboard အကြောင်း

ဒီ API က admin notification publish endpoint ပေးထားပါတယ်။ အစပိုင်းမှာ cURL/Postman နဲ့သုံးနိုင်ပြီး နောက်ပိုင်း PHP admin dashboard ထည့်နိုင်ပါတယ်။ Admin endpoint ကို `X-Admin-Token` မပါဘဲ မခေါ်နိုင်ပါ။ Token ကို Flutter App ထဲ မထည့်ပါနှင့်။

## Production checklist

- HTTPS မဖြစ်မနေသုံးပါ။
- `ADMIN_API_TOKEN` ကို random အရှည်ကြီးသုံးပါ။
- `.env`, `schema.sql`, database credentials တွေကို public folder ထဲ မထားပါနှင့်။
- CORS `*` ကို production domain တစ်ခုတည်းအဖြစ် ကန့်သတ်ပါ။
- PHP error ကို client ဆီမပြဘဲ server log ထဲပဲထားပါ။
- Feedback rate limit နဲ့ MySQL prepared statements ကို မဖယ်ပါနှင့်။
- Notification POST token ကို Flutter app ထဲ hard-code မလုပ်ပါနှင့်။
