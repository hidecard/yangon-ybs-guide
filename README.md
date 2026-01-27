# Yangon YBS Guide 🚌

A comprehensive bus route guide application for Yangon, Myanmar, featuring interactive maps, AI-powered route assistance, and offline functionality.

## 🌟 Features

### 🗺️ Interactive Maps
- **Leaflet-powered maps** with OpenStreetMap tiles
- **GPS location services** to find nearby bus stops
- **Route visualization** with color-coded bus routes
- **Stop search and navigation** on the map

### 🤖 AI-Powered Assistant
- **Natural language queries** in Myanmar and English
- **Intelligent route finding** using Google Gemini AI
- **Contextual responses** with transfer information
- **Conversational interface** for transportation queries

### 🔍 Advanced Search & Navigation
- **Route search** between any two bus stops
- **Stop directory** with 1000+ stops organized by township
- **Route filtering** by start/end locations
- **Transfer planning** with multiple route options

### 📱 Responsive Design
- **Mobile-first design** with bottom navigation
- **Desktop interface** with header navigation
- **Progressive Web App** capabilities
- **Offline functionality** with cached data

### 💾 Offline Capabilities
- **IndexedDB storage** using Dexie
- **Local route data** for offline access
- **Fast loading** without internet dependency
- **Data synchronization** when online

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- npm or yarn

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

3. **Set up environment variables**
   Create a `.env.local` file:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

4. **Start development server**
   ```bash
   npm run dev
   ```

5. **Build for production**
   ```bash
   npm run build
   npm run preview
   ```

## 📖 Usage Guide

### Finding Routes

#### Method 1: AI Assistant
1. Navigate to the **Assistant** page
2. Ask questions like:
   - "မြေနီကုန်းကနေ လှည်းတန်းကို ဘယ်လိုသွားရမလဲ?"
   - "How to go from Dagon Center to Sule?"
   - "Show me routes from Hledan to Thingangyun"

#### Method 2: Route Search
1. Go to **Find Route** page
2. Select start and end bus stops
3. View route options with transfer information

#### Method 3: Map Navigation
1. Open the **Map** page
2. Browse bus stops and routes visually
3. Use GPS to find nearby stops
4. Search for specific locations

### Exploring Bus Routes

#### Route Directory
1. Visit **Routes** page
2. Browse all available bus routes
3. Click on any route to see:
   - Complete stop list
   - Route color and operator
   - Connected routes for transfers

#### Stop Information
1. Go to **Stops** page
2. Browse stops by township
3. Click on stops to see:
   - Location coordinates
   - Connected routes
   - Nearby landmarks

### Map Features

#### Interactive Navigation
- **Zoom and pan** to explore Yangon
- **Click stops** to view details
- **Route highlighting** when selected
- **GPS location** button for current position

#### Stop Search
- **Search bar** for finding specific stops
- **Auto-complete** suggestions
- **Jump to location** on map

## 🏗️ Technical Architecture

### Frontend Stack
- **React 19** with TypeScript
- **Tailwind CSS** for styling
- **Vite** for build tooling
- **Lucide React** for icons

### Data Management
- **Dexie** for IndexedDB operations
- **Local JSON files** for route data
- **Offline-first** architecture

### Mapping & Location
- **Leaflet** for interactive maps
- **OpenStreetMap** tiles
- **Geolocation API** for GPS

### AI Integration
- **Google Gemini API** for natural language processing
- **Context-aware responses**
- **Myanmar language support**

## 📁 Project Structure

```
yangon-ybs-guide/
├── public/
│   └── routes/          # Bus route JSON files
├── src/
│   ├── App.tsx          # Main application component
│   ├── db.ts            # IndexedDB configuration
│   ├── data_constants.ts # Route loading utilities
│   ├── types.ts         # TypeScript interfaces
│   └── index.tsx        # Application entry point
├── package.json
├── vite.config.ts
└── README.md
```

## 🔧 Configuration

### Environment Variables
```env
GEMINI_API_KEY=your_api_key_here
```

### Build Configuration
The app is configured to run on port 3000 in development and can be built for static hosting.

## 🌐 Supported Languages

- **Myanmar (မြန်မာ)** - Primary language
- **English** - Secondary language
- AI assistant supports both languages

## 📊 Data Coverage

- **100+ Bus Routes** covering Yangon and surrounding areas
- **1000+ Bus Stops** with detailed location information
- **Township Coverage** across all major Yangon districts
- **Real-time Updates** through JSON data files

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🙏 Acknowledgments

- **OpenStreetMap** for map data
- **Google Gemini** for AI capabilities
- **Yangon Bus Service (YBS)** for transportation data
- **Leaflet** for mapping library

---

**ရန်ကုန်မြို့ရဲ့ ဘတ်စ်ကားလမ်းညွှန်အပြည့်အစုံ** 🚌✨
