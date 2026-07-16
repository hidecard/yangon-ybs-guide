# Yangon YBS Guide 🚌

A comprehensive bus route guide application for Yangon, Myanmar, featuring interactive maps, an AI-powered route assistant, real-time user updates, and offline functionality.

## 🌟 Features

### 🗺️ Interactive Maps
- **Leaflet-powered maps** with OpenStreetMap tiles
- **GPS location services** to find nearby bus stops
- **Stop markers** with detailed popups across Yangon
- **Search and jump** to specific stops on the map
- **Radius-based discovery** showing stops within 1km
- **Live bus tracking** showing user-reported bus positions on route maps
- **Auto-refresh** every 30 seconds for live positions

### 🤖 AI-Powered Assistant
- **Natural language queries** in **Myanmar (Burmese)** and English
- **Local NLP processing** to extract stop names from conversational text
- **Intelligent route finding** using BFS graph traversal
- **Transfer planning** with up to 4 transfers supported
- **Contextual responses** with step-by-step route instructions

### 🔍 Advanced Search & Navigation
- **Route search** between any two bus stops with BFS algorithm
- **Stop directory** with 1000+ stops organized by township
- **Route filtering** by start/end locations, route ID, or operator
- **Direct & transfer routes** with visual step indicators
- **Favorites system** to save preferred routes
- **Offline trip history** for recent searches

### 📱 Community Features
- **YBS New** — community bus updates feed with user-submitted reports
- **Report bus updates** — share live bus status, delays, and conditions
- **Bus arrival predictions** — ETA estimates based on recent user reports
- **User feedback system** — report bugs, wrong info, or suggestions
- **Admin notifications** — broadcast updates to all users

### 👨‍💼 Admin Dashboard
- Password-protected admin panel
- Manage user feedback with pagination
- Send notifications to all users
- View feedback statistics by type
- Monitor recent reports and issues

### 📱 Responsive Design
- **Mobile-first design** with bottom navigation
- **Desktop interface** with sticky header navigation
- **Modern UI** using Tailwind CSS with yellow accent theme
- **Touch-friendly** map pickers and selection modals

### 💾 Offline Capabilities
- **IndexedDB storage** using Dexie.js
- **Local route data** embedded in the application
- **JSON route files** (100+ routes) loaded dynamically
- **Fast loading** without internet dependency after initial load
- **Trip history** persisted locally

## 🚀 Tech Stack

| Category | Technology |
|----------|------------|
| **Frontend Framework** | React 19 + TypeScript |
| **Build Tool** | Vite 6 |
| **Styling** | Tailwind CSS |
| **Routing** | React Router DOM 7 |
| **Icons** | Lucide React |
| **Database** | Dexie.js (IndexedDB wrapper) + Turso (SQLite) |
| **Maps** | Leaflet (loaded dynamically) + OpenStreetMap |
| **AI/NLP** | Custom local NLP extractor + BFS graph search |
| **Backend** | Vercel Serverless Functions |
| **Data Format** | Local JSON files + TypeScript constants |

## 📖 Usage Guide

### Finding Routes

#### Method 1: AI Assistant
1. Navigate to the **Assistant** page
2. Ask questions naturally in Myanmar or English:
   - `"မြေနီကုန်းကနေ လှည်းတန်းကို ဘယ်လိုသွားရမလဲ?"`
   - `"How to go from Dagon Center to Sule?"`
   - `"Show me routes from Hledan to Thingangyun"`
3. The assistant extracts stop names and returns route options with transfers

#### Method 2: Route Search
1. Go to **Find Route** page
2. Enter start and end bus stops (with autocomplete)
3. Use **"Near Me"** button to auto-fill nearest stop via GPS
4. Use the **map picker** to select stops visually
5. View route options with transfer information

#### Method 3: Map Navigation
1. Open the **Map** page
2. Browse bus stops visually across Yangon
3. Use GPS to find your current location
4. Search for specific stops and jump to them

### Community Features

#### YBS New — Bus Updates Feed
1. Navigate to **YBS New** page
2. View latest bus updates from other users
3. Click **"အချက်အလက် မျှဝေမည်"** to share your own update
4. Select route, update type, and optional note
5. Updates auto-delete after 24 hours

#### Reporting Bus Status
1. Open any route detail page
2. Tap the **megaphone icon** in the header
3. Select update type: Started, Arrived, Delayed, etc.
4. Optionally add a stop name or note
5. Submit — your update appears on the map and feed

#### Viewing Predictions
1. Open a route detail page
2. Scroll to **"ယာဉ် ရောက်မည့် ခန့်မှန်းချက်"** section
3. See estimated arrival times for upcoming stops
4. Predictions update every 30 seconds

### Admin Features

#### Sending Notifications
1. Go to **Settings** → tap **Admin** link
2. Enter password: `hidecard969aky`
3. Scroll to **"သတိပေးချက် ပို့ရန်"** card
4. Enter title, message, and select type
5. Tap **"သတိပေးချက် ပို့မည်"**
6. All users see the notification on their home page

#### Managing Feedback
1. Go to **Settings** → tap **Admin** link
2. Enter admin password
3. View feedback statistics by category
4. Browse feedback with pagination (20 per page)
5. Refresh to load latest feedback

## 🏗️ Project Structure

```
yangon-ybs-guide/
├── routes/                      # Bus route JSON files (100+ routes)
│   ├── route1.json
│   ├── route2.json
│   ├── route3A.json
│   └── ...
├── api/                         # Vercel serverless functions
│   ├── bus-updates.ts           # Bus updates CRUD + predictions
│   ├── feedback.ts              # User feedback API
│   ├── notifications.ts         # Admin notifications API
│   ├── admin-auth.ts            # Admin password verification
│   └── admin-feedback.ts        # Admin feedback management
├── App.tsx                      # Main application with all components
├── index.tsx                    # React entry point
├── db.ts                        # Dexie IndexedDB configuration
├── data_constants.ts            # Bus stops data & route loading utilities
├── types.ts                     # TypeScript interfaces
├── busUpdates.ts                # Bus updates client helpers
├── feedback.ts                  # Feedback client helpers
├── notifications.ts             # Notifications client helpers
├── tripHistory.ts               # Offline trip history helpers
├── telegramAlert.ts             # Telegram alert integration
├── vite.config.ts               # Vite configuration
├── package.json
├── vercel.json
└── README.md
```

## ⚙️ Configuration

### Environment Variables
Create a `.env` file in the project root:

```env
# Turso Database
TURSO_DATABASE_URL=libsql://your-database-url
TURSO_AUTH_TOKEN=your-auth-token

# Gemini AI (optional, for assistant)
GEMINI_API_KEY=your-gemini-api-key

# Telegram Bot (optional, for alerts)
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_API_TOKEN=your-api-token
```

### Vercel Configuration
The app is configured for Vercel deployment with:
- Serverless functions in `/api` directory
- SPA routing support
- Environment variables for Turso and Gemini

## 🗄️ Database Schema

### Turso Tables

#### `bus_updates`
- `id` — auto-increment primary key
- `route_id` — bus route identifier
- `stop` — optional stop name
- `type` — update type (started, arrived, delayed, etc.)
- `note` — optional user note
- `lat` / `lng` — optional GPS coordinates
- `user_id` — anonymous user identifier
- `created_at` — timestamp in milliseconds

#### `feedback`
- `id` — auto-increment primary key
- `type` — feedback type (bug, wrong_info, suggestion, other)
- `message` — feedback content
- `route_id` — optional related route
- `user_id` — anonymous user identifier
- `created_at` — timestamp in milliseconds

#### `notifications`
- `id` — auto-increment primary key
- `title` — notification title
- `message` — notification content
- `type` — notification type (info, update, alert)
- `created_at` — timestamp in milliseconds

## 🚀 Getting Started

### Prerequisites
- Node.js 18+
- npm
- Turso database (for serverless APIs)
- Vercel account (for deployment)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/hidecard/yangon-ybs-guide.git
   cd yangon-ybs-guide
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your Turso and Gemini credentials
   ```

4. **Start development server**
   ```bash
   npm run dev
   ```
   The app runs on port 3000 by default.

5. **Build for production**
   ```bash
   npm run build
   npm run preview
   ```

## 📦 Build & Deployment

### Local Build
```bash
npm run build
npm run preview
```

### Vercel Deployment
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy to production
vercel login
npx vercel --prod --yes
```

### Environment Setup on Vercel
1. Go to your Vercel project settings
2. Add environment variables:
   - `TURSO_DATABASE_URL`
   - `TURSO_AUTH_TOKEN`
   - `GEMINI_API_KEY` (optional)
3. Redeploy the project

## 📝 Data Coverage

- **100+ Bus Routes** covering Yangon and surrounding areas
- **1000+ Bus Stops** with precise GPS coordinates
- **Bilingual Data** — Myanmar (Burmese) and English names
- **Township Coverage** across all major Yangon districts
- **Route Shapes** stored as GeoJSON LineStrings

## 🛠️ Architecture

### Route Finding Algorithm
The app uses **Breadth-First Search (BFS)** to find optimal routes between stops:
- Supports **direct routes** (0 transfers)
- Supports **multi-transfer routes** (up to 4 transfers)
- Results sorted by: transfer count → total distance
- Distance calculated using the Haversine formula on GPS coordinates

### Local NLP
The assistant uses a **custom keyword extractor** for Myanmar language:
- Scans user input for known stop names
- Detects directional keywords (`ကနေ`, `မှ`, `ကို`, `သို့`)
- Falls back to clarifying questions if stops are ambiguous

### Offline Storage
- Bus stops are stored in IndexedDB via Dexie
- Route JSON files are served statically and cached by the browser
- The app initializes IndexedDB from `INITIAL_STOPS` on first load
- Trip history stored in localStorage

### Serverless APIs
- **bus-updates.ts** — CRUD for bus updates, predictions, 24h auto-cleanup
- **feedback.ts** — collect user feedback, 24h auto-cleanup
- **notifications.ts** — admin notifications, auto-keeps latest 20
- **admin-auth.ts** — password-based admin authentication
- **admin-feedback.ts** — paginated feedback management

## 📊 Version History

### v3.2
- 🗑️ Removed dedicated Stops page to streamline navigation
- 🆕 Added **YBS New** page for community bus updates
- 👥 User feedback/reporting system with Turso database
- ⏱️ Bus arrival predictions based on recent user reports
- 🔄 24-hour auto-delete for bus updates and feedback
- 🗺️ Live bus tracking on route maps with blue position markers
- 🔄 Auto-refresh every 30 seconds for live bus positions
- 👨‍💼 Admin dashboard with password protection
- 📊 Feedback management UI with pagination
- 📢 Admin notification broadcasting to users
- 🕐 Offline trip history for recent searches
- 🧹 Auto-cleanup of old notifications (keeps latest 20)

### v3.1
- 🤖 AI-powered route assistant with Myanmar/NLP support
- 🔍 Route search with BFS algorithm and multi-transfer support
- 📱 Mobile-first responsive design with bottom navigation
- 💾 Offline capabilities with IndexedDB storage

### v3.0
- 🚌 Interactive bus route maps with Leaflet + OpenStreetMap
- 📍 1000+ bus stops with GPS coordinates
- ⭐ Favorites system for routes
- 🗺️ GPS location services to find nearby stops

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🐛 Troubleshooting

### Maps not loading
- Check browser console for Leaflet/network errors
- Ensure internet connection for initial tile load
- Clear browser cache and reload

### Routes not appearing
- Verify route JSON files in `/routes` directory
- Check IndexedDB storage in browser DevTools
- Run data update from Settings page

### Notifications not showing
- Check `/api/notifications` returns 200
- Verify notifications table exists in Turso
- Clear `ybs_notifications_last_seen` in localStorage

## 📄 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- **OpenStreetMap** for map data
- **Yangon Bus Service (YBS)** for transportation data
- **Leaflet** for mapping library
- **Turso** for database hosting
- **Vercel** for hosting platform

---

**ရန်ကုန်မြို့ရဲ့ ဘတ်စ်ကားလမ်းညွှန်အပြည့်အစုံ** 🚌✨
