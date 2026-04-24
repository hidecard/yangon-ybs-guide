# Yangon YBS Guide 🚌

A comprehensive bus route guide application for Yangon, Myanmar, featuring interactive maps, an AI-powered route assistant, and offline functionality.

## 🌟 Features

### 🗺️ Interactive Maps
- **Leaflet-powered maps** with OpenStreetMap tiles
- **GPS location services** to find nearby bus stops
- **Stop markers** with detailed popups across Yangon
- **Search and jump** to specific stops on the map
- **Radius-based discovery** showing stops within 1km

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

## 🚀 Tech Stack

| Category | Technology |
|----------|------------|
| **Frontend Framework** | React 19 + TypeScript |
| **Build Tool** | Vite 6 |
| **Styling** | Tailwind CSS |
| **Routing** | React Router DOM 7 |
| **Icons** | Lucide React |
| **Database** | Dexie.js (IndexedDB wrapper) |
| **Maps** | Leaflet (loaded dynamically) + OpenStreetMap |
| **AI/NLP** | Custom local NLP extractor + BFS graph search |
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

### Exploring Bus Routes

#### Route Directory
1. Visit **Routes** page
2. Browse/search all 100+ available bus routes
3. Click any route to see:
   - Complete stop list with visual timeline
   - Route color and operator info
   - Interactive stop links

#### Stop Information
1. Go to **Stops** page
2. Browse or search 1000+ stops by name or township
3. Click stops to see:
   - Location on embedded map
   - All passing routes
   - Township and road information

### Saving Favorites
- Click the **star icon** on any route card to save it
- Favorites are persisted in localStorage

## 🏗️ Project Structure

```
yangon-ybs-guide/
├── routes/                 # Bus route JSON files (100+ routes)
│   ├── route1.json
│   ├── route2.json
│   ├── route3A.json
│   └── ...
├── App.tsx                 # Main application with all components
├── index.tsx               # React entry point
├── db.ts                   # Dexie IndexedDB configuration
├── data_constants.ts       # Bus stops data & route loading utilities
├── types.ts                # TypeScript interfaces
├── vite.config.ts          # Vite configuration
├── package.json
└── README.md
```

## ⚙️ Getting Started

### Prerequisites
- Node.js 18+
- npm

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd yangon-ybs-guide
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start development server**
   ```bash
   npm run dev
   ```
   The app runs on port 3000 by default.

4. **Build for production**
   ```bash
   npm run build
   npm run preview
   ```

## 📝 Data Coverage

- **100+ Bus Routes** covering Yangon and surrounding areas
- **1000+ Bus Stops** with precise GPS coordinates
- **Bilingual Data** — Myanmar (Burmese) and English names
- **Township Coverage** across all major Yangon districts
- **Route Shapes** stored as GeoJSON LineStrings

## 🛠️ Architecture Notes

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

## 📄 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- **OpenStreetMap** for map data
- **Yangon Bus Service (YBS)** for transportation data
- **Leaflet** for mapping library

---

**ရန်ကုန်မြို့ရဲ့ ဘတ်စ်ကားလမ်းညွှန်အပြည့်အစုံ** 🚌✨

