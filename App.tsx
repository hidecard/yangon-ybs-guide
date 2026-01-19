
import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { db } from './db';
import { INITIAL_STOPS, INITIAL_ROUTES } from './data_constants';
import { Page, BusStop, BusRoute } from './types';
import { 
  Bus, 
  Map as MapIcon, 
  Search, 
  Star, 
  Settings, 
  Home, 
  ChevronRight,
  ArrowRightLeft,
  MapPin,
  X,
  RefreshCw,
  Info,
  Navigation,
  Crosshair,
  List,
  Locate,
  Hash,
  CreditCard,
  MessageSquare,
  Send,
  Sparkles,
  Bot,
  User
} from 'lucide-react';

// --- Types for Search Results ---
interface PathStep {
  route: BusRoute;
  fromStop: string;
  toStop: string;
}

interface SearchResult {
  steps: PathStep[];
  transferCount: number;
}

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  results?: SearchResult[];
}

// --- Utils ---
const getDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
  const R = 6371; 
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2)
    ; 
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
  const d = R * c; 
  return d;
};

const performBFS = async (start: string, end: string): Promise<SearchResult[]> => {
  const allRoutes = await db.busRoutes.toArray();
  const queue: { currentStop: string; path: PathStep[] }[] = [{ currentStop: start, path: [] }];
  const visitedStops = new Set<string>([start]);
  const finalResults: SearchResult[] = [];
  const MAX_TRANSFERS = 2; 

  while (queue.length > 0) {
    const { currentStop, path } = queue.shift()!;
    if (path.length > MAX_TRANSFERS + 1) break;

    const availableRoutes = allRoutes.filter(r => r.stops.includes(currentStop));
    for (const route of availableRoutes) {
      if (path.some(step => step.route.id === route.id)) continue;
      if (route.stops.includes(end)) {
        const finalPath = [...path, { route, fromStop: currentStop, toStop: end }];
        finalResults.push({ steps: finalPath, transferCount: finalPath.length - 1 });
        if (finalResults.length >= 5) break; 
      }

      if (path.length < MAX_TRANSFERS) {
        for (const nextStop of route.stops) {
          if (!visitedStops.has(nextStop)) {
            visitedStops.add(nextStop);
            queue.push({
              currentStop: nextStop,
              path: [...path, { route, fromStop: currentStop, toStop: nextStop }]
            });
          }
        }
      }
    }
    if (finalResults.length >= 5) break;
  }
  return finalResults.sort((a, b) => a.transferCount - b.transferCount);
};

// --- Local NLP Logic (No AI Needed) ---
const extractStopsFromText = (text: string, allStopNames: string[]) => {
  const normalizedText = text.trim();
  
  // Find all matches from our database in the user text
  // We sort by length descending to match longest stop names first (e.g. "မြေနီကုန်း" before "ကုန်း")
  const sortedNames = [...allStopNames].sort((a, b) => b.length - a.length);
  
  const foundStops: { name: string, index: number }[] = [];
  
  sortedNames.forEach(name => {
    if (normalizedText.includes(name)) {
      const index = normalizedText.indexOf(name);
      // Ensure we don't pick overlapping names if a longer one was already picked
      const isOverlapping = foundStops.some(s => 
        (index >= s.index && index < s.index + s.name.length) ||
        (index + name.length > s.index && index + name.length <= s.index + s.name.length)
      );
      if (!isOverlapping) {
        foundStops.push({ name, index });
      }
    }
  });

  // Sort by appearance in text
  foundStops.sort((a, b) => a.index - b.index);

  if (foundStops.length < 1) return null;

  let start: string | null = null;
  let end: string | null = null;

  // Rule 1: Check for "ကနေ" or "မှ" (From)
  const fromKeywords = ["ကနေ", "မှ"];
  const toKeywords = ["ကို", "သို့", "သွားချင်တာ"];

  if (foundStops.length >= 2) {
    const firstStop = foundStops[0];
    const secondStop = foundStops[1];
    
    // Check if there is a 'from' indicator near the first stop
    const textAfterFirst = normalizedText.substring(firstStop.index + firstStop.name.length, secondStop.index);
    const hasFromMarker = fromKeywords.some(k => textAfterFirst.includes(k));
    
    if (hasFromMarker) {
      start = firstStop.name;
      end = secondStop.name;
    } else {
      // Default to first found is start, second is end
      start = firstStop.name;
      end = secondStop.name;
    }
  } else if (foundStops.length === 1) {
    // Only one stop found, check if user said "X ကို"
    const textAfter = normalizedText.substring(foundStops[0].index + foundStops[0].name.length);
    const isDestination = toKeywords.some(k => textAfter.includes(k));
    if (isDestination) end = foundStops[0].name;
    else start = foundStops[0].name;
  }

  return { start, end };
};

// --- Sub-components ---

const MapSelectionModal: React.FC<{ 
  stops: BusStop[], 
  onSelect: (stop: BusStop) => void, 
  onClose: () => void,
  title: string
}> = ({ stops, onSelect, onClose, title }) => {
  const mapRef = useRef<any>(null);
  const markerLayerRef = useRef<any>(null);
  const radiusCircleRef = useRef<any>(null);
  const userMarkerRef = useRef<any>(null);
  const [isLocating, setIsLocating] = useState(false);
  const [nearbyStops, setNearbyStops] = useState<(BusStop & { distance: number })[]>([]);

  const updateMarkers = useCallback((centerLat: number, centerLng: number) => {
    const L = (window as any).L;
    if (!L || !mapRef.current || !markerLayerRef.current) return;

    markerLayerRef.current.clearLayers();

    const found = stops.map(s => ({
      ...s,
      distance: getDistance(centerLat, centerLng, s.lat, s.lng)
    }))
    .filter(s => s.distance <= 1.0)
    .sort((a, b) => a.distance - b.distance);

    setNearbyStops(found);

    found.forEach(s => {
      const marker = L.circleMarker([s.lat, s.lng], {
        radius: 8,
        fillColor: "#2563eb",
        color: "#fff",
        weight: 2,
        opacity: 1,
        fillOpacity: 0.9
      });

      marker.bindPopup(`
        <div class="p-1">
          <b class="text-sm">${s.name_mm}</b><br>
          <span class="text-[10px] text-gray-500">${s.township_mm}</span><br>
          <div class="text-[9px] text-blue-600 font-bold mb-1">${(s.distance * 1000).toFixed(0)}m away</div>
          <button id="select-stop-${s.id}" class="w-full bg-blue-600 text-white text-[10px] px-2 py-1.5 rounded font-bold hover:bg-blue-700 transition-colors">ရွေးချယ်မည်</button>
        </div>
      `, { closeButton: false });
      
      marker.on('popupopen', () => {
        const btn = document.getElementById(`select-stop-${s.id}`);
        if (btn) {
          btn.onclick = () => {
            onSelect(s);
            onClose();
          };
        }
      });

      marker.addTo(markerLayerRef.current);
    });

    if (radiusCircleRef.current) {
      radiusCircleRef.current.setLatLng([centerLat, centerLng]);
    } else {
      radiusCircleRef.current = L.circle([centerLat, centerLng], {
        radius: 1000, 
        color: '#2563eb',
        fillColor: '#2563eb',
        fillOpacity: 0.05,
        weight: 1,
        dashArray: '5, 10'
      }).addTo(mapRef.current);
    }
  }, [stops, onSelect, onClose]);

  useEffect(() => {
    const L = (window as any).L;
    if (!L) return;

    const map = L.map('selection-map', { zoomControl: false }).setView([16.8, 96.15], 14);
    mapRef.current = map;
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
    L.control.zoom({ position: 'topleft' }).addTo(map);

    markerLayerRef.current = L.featureGroup().addTo(map);

    const center = map.getCenter();
    updateMarkers(center.lat, center.lng);

    map.on('move', () => {
      const newCenter = map.getCenter();
      updateMarkers(newCenter.lat, newCenter.lng);
    });

    map.on('locationfound', (e: any) => {
      setIsLocating(false);
      if (userMarkerRef.current) {
        userMarkerRef.current.setLatLng(e.latlng);
      } else {
        userMarkerRef.current = L.circleMarker(e.latlng, {
          radius: 8,
          fillColor: "#10b981",
          color: "#fff",
          weight: 3,
          opacity: 1,
          fillOpacity: 1
        }).addTo(map).bindPopup("သင်၏လက်ရှိနေရာ");
      }
      map.setView(e.latlng, 15);
      updateMarkers(e.latlng.lat, e.latlng.lng);
    });

    map.on('locationerror', () => {
      setIsLocating(false);
      const currentCenter = map.getCenter();
      updateMarkers(currentCenter.lat, currentCenter.lng);
    });

    map.locate({ setView: true, maxZoom: 15 });

    return () => map.remove();
  }, [updateMarkers]);

  const handleLocate = () => {
    if (mapRef.current) {
      setIsLocating(true);
      mapRef.current.locate({ setView: true, maxZoom: 15 });
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 z-[100] flex items-end md:items-center justify-center p-0 md:p-4 animate-in fade-in duration-200">
      <div className="bg-white w-full max-w-2xl rounded-t-3xl md:rounded-3xl h-[90vh] flex flex-col overflow-hidden shadow-2xl relative">
        <div className="p-4 border-b flex items-center justify-between bg-white shrink-0">
          <div className="flex flex-col">
            <h3 className="font-black text-gray-800 text-lg">{title}</h3>
            <div className="flex items-center space-x-2">
              <div className="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse"></div>
              <p className="text-[10px] text-gray-500 font-bold uppercase tracking-wider">၁ ကီလိုမီတာအတွင်း ရှာဖွေနေပါသည်</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-full transition-colors text-gray-400">
            <X size={24} />
          </button>
        </div>
        
        <div className="relative flex-1 bg-gray-100">
          <div id="selection-map" className="w-full h-full"></div>
          <div className="absolute inset-0 pointer-events-none flex items-center justify-center z-[1000]">
            <div className="relative flex items-center justify-center">
               <div className="w-8 h-px bg-blue-500/50 absolute"></div>
               <div className="h-8 w-px bg-blue-500/50 absolute"></div>
               <div className="w-2 h-2 rounded-full border border-blue-600 bg-white/50"></div>
            </div>
          </div>
          <button 
            onClick={handleLocate}
            disabled={isLocating}
            className="absolute bottom-4 right-4 z-[1000] bg-white p-3 rounded-full shadow-xl text-blue-600 hover:bg-blue-50 active:scale-95 transition-all border border-gray-100"
          >
            {isLocating ? <RefreshCw className="animate-spin" size={24} /> : <Locate size={24} />}
          </button>
        </div>

        <div className="bg-gray-50 border-t shrink-0 h-1/3 flex flex-col">
          <div className="px-4 py-2 border-b bg-white flex items-center justify-between">
            <span className="text-[11px] font-black text-gray-400 uppercase tracking-widest">အနီးဆုံးမှတ်တိုင်များ ({nearbyStops.length})</span>
            {nearbyStops.length > 0 && <span className="text-[10px] text-blue-600 font-bold">List မှ ရွေးနိုင်ပါသည်</span>}
          </div>
          <div className="flex-1 overflow-y-auto p-2 space-y-1.5">
            {nearbyStops.length > 0 ? (
              nearbyStops.map(s => (
                <button 
                  key={s.id}
                  onClick={() => onSelect(s)}
                  className="w-full bg-white p-3 rounded-xl border border-gray-100 shadow-sm flex items-center justify-between hover:border-blue-200 hover:bg-blue-50 transition-all group"
                >
                  <div className="flex items-center space-x-3">
                    <div className="bg-blue-100 p-2 rounded-lg text-blue-600 group-hover:bg-blue-600 group-hover:text-white transition-colors">
                      <MapPin size={14} />
                    </div>
                    <div className="text-left">
                      <p className="text-sm font-black text-gray-800">{s.name_mm}</p>
                      <p className="text-[10px] text-gray-400 font-bold">{s.township_mm}</p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className="text-[10px] bg-blue-50 text-blue-700 px-2 py-0.5 rounded-full font-black">
                      {(s.distance * 1000).toFixed(0)}m
                    </span>
                    <ChevronRight size={14} className="text-gray-300" />
                  </div>
                </button>
              ))
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-gray-400 py-10">
                <Search size={24} className="mb-2 opacity-20" />
                <p className="text-[11px] font-bold">ဤနေရာအနီးတွင် မှတ်တိုင်မရှိပါ။</p>
                <p className="text-[10px]">မြေပုံကို ရွှေ့ကြည့်ပါ</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const StopSearchInput: React.FC<{
  label: string,
  value: string,
  onChange: (val: string) => void,
  allNames: string[],
  placeholder: string,
  icon?: React.ReactNode,
  indicatorColor: string
}> = ({ label, value, onChange, allNames, placeholder, icon, indicatorColor }) => {
  const [query, setQuery] = useState(value);
  const [isOpen, setIsOpen] = useState(false);
  const wrapperRef = useRef<HTMLDivElement>(null);

  const filtered = useMemo(() => {
    if (!query) return [];
    const term = query.toLowerCase().trim();
    return allNames.filter(n => n.toLowerCase().includes(term)).slice(0, 50);
  }, [query, allNames]);

  useEffect(() => {
    setQuery(value);
  }, [value]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div className="space-y-2 relative" ref={wrapperRef}>
      <div className="flex items-center justify-between">
        <label className="text-xs font-bold text-gray-400 uppercase tracking-wider flex items-center space-x-2">
          <div className={`w-2 h-2 rounded-full ${indicatorColor}`}></div>
          <span>{label}</span>
        </label>
        {icon}
      </div>
      <div className="relative">
        <input 
          type="text"
          className="w-full p-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all text-sm"
          placeholder={placeholder}
          value={query}
          onChange={(e) => {
            const val = e.target.value;
            setQuery(val);
            setIsOpen(true);
            onChange(val);
          }}
          onFocus={() => setIsOpen(true)}
        />
        {isOpen && filtered.length > 0 && (
          <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-xl shadow-xl z-[80] max-h-60 overflow-y-auto">
            {filtered.map((name, i) => (
              <div 
                key={i}
                className="p-3 hover:bg-blue-50 cursor-pointer text-sm border-b border-gray-50 last:border-0"
                onClick={() => {
                  onChange(name);
                  setQuery(name);
                  setIsOpen(false);
                }}
              >
                {name}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

const MobileBottomNav: React.FC<{ currentPage: Page, setPage: (p: Page) => void }> = ({ currentPage, setPage }) => {
  const items = [
    { id: Page.Home, icon: Home, label: 'ပင်မ' },
    { id: Page.Assistant, icon: MessageSquare, label: 'Assistant' },
    { id: Page.Routes, icon: Bus, label: 'လိုင်းများ' },
    { id: Page.Map, icon: MapIcon, label: 'မြေပုံ' },
    { id: Page.FindRoute, icon: Search, label: 'လမ်းကြောင်း' },
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 flex justify-around items-center h-16 px-2 z-50 md:hidden">
      {items.map(item => (
        <button
          key={item.id}
          onClick={() => setPage(item.id)}
          className={`flex flex-col items-center justify-center space-y-1 w-full ${currentPage === item.id ? 'text-blue-600' : 'text-gray-500'}`}
        >
          <item.icon size={20} />
          <span className="text-[10px] font-medium">{item.label}</span>
        </button>
      ))}
    </div>
  );
};

const Header: React.FC<{ currentPage: Page, setPage: (p: Page) => void }> = ({ currentPage, setPage }) => {
  const navItems = [
    { id: Page.Home, icon: Home, label: 'Home' },
    { id: Page.Assistant, icon: MessageSquare, label: 'Assistant' },
    { id: Page.Routes, icon: Bus, label: 'Routes' },
    { id: Page.Stops, icon: MapPin, label: 'Stops' },
    { id: Page.Map, icon: MapIcon, label: 'Map' },
    { id: Page.FindRoute, icon: Search, label: 'Find Route' },
  ];

  return (
    <header className="bg-blue-600 text-white sticky top-0 z-40 shadow-md">
      <div className="max-w-5xl mx-auto px-4 py-3 flex justify-between items-center">
        <div className="flex items-center space-x-2 cursor-pointer" onClick={() => setPage(Page.Home)}>
          <Bus size={28} />
          <h1 className="text-xl font-bold tracking-tight">YBS Guide</h1>
        </div>

        <nav className="hidden md:flex items-center space-x-6">
          {navItems.map(item => (
            <button 
              key={item.id}
              onClick={() => setPage(item.id)}
              className={`flex items-center space-x-1.5 text-sm font-bold transition-colors hover:text-blue-200 ${currentPage === item.id ? 'text-white' : 'text-blue-100'}`}
            >
              <item.icon size={16} />
              <span>{item.label}</span>
            </button>
          ))}
        </nav>

        <button onClick={() => setPage(Page.Settings)} className="p-1.5 hover:bg-blue-700 rounded-full transition-colors">
          <Settings size={22} />
        </button>
      </div>
    </header>
  );
};

const RouteBadge: React.FC<{ routeId: string, color: string, onClick?: () => void, size?: 'sm' | 'md' }> = ({ routeId, color, onClick, size = 'md' }) => (
  <div 
    onClick={onClick}
    style={{ backgroundColor: color }}
    className={`rounded-xl text-white font-black shadow-md cursor-pointer hover:opacity-90 active:scale-95 transition-all flex items-center justify-center shrink-0 ${size === 'sm' ? 'px-2 py-1 text-[10px] min-w-[40px] h-7' : 'px-4 py-2 text-base min-w-[60px] h-12'}`}
  >
    {routeId}
  </div>
);

const OperatorBadge: React.FC<{ name: string }> = ({ name }) => (
  <div className="flex items-center space-x-1 bg-yellow-400/10 border border-yellow-400/30 text-yellow-700 px-1.5 py-0.5 rounded text-[10px] font-bold shrink-0">
    <CreditCard size={10} />
    <span>{name}</span>
  </div>
);

const HomePage: React.FC<{ setPage: (p: Page) => void }> = ({ setPage }) => (
  <div className="max-w-5xl mx-auto p-4 md:p-8 space-y-6 md:space-y-10">
    <div className="bg-blue-100 p-6 md:p-10 rounded-2xl md:rounded-3xl border border-blue-200 shadow-sm flex flex-col md:flex-row items-center justify-between gap-6">
      <div>
        <h2 className="text-2xl md:text-4xl font-bold text-blue-900 mb-2">မင်္ဂလာပါ</h2>
        <p className="text-blue-800 md:text-lg mb-6">Yangon Bus Service လမ်းညွှန်မှ ကြိုဆိုပါသည်။ အကူအညီ လိုအပ်ပါက Assistant ကို စာရိုက်ပြီး မေးနိုင်ပါတယ်။</p>
        <button 
          onClick={() => setPage(Page.Assistant)}
          className="bg-blue-600 text-white px-6 py-3 rounded-xl font-bold flex items-center space-x-2 hover:bg-blue-700 transition-all shadow-lg"
        >
          <MessageSquare size={20} />
          <span>Assistant ကို မေးပါ</span>
        </button>
      </div>
      <div className="hidden md:block">
        <Bot size={120} className="text-blue-500 opacity-20" />
      </div>
    </div>

    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-6">
      <button 
        onClick={() => setPage(Page.Assistant)}
        className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm flex flex-col items-center justify-center space-y-3 hover:shadow-md hover:bg-blue-50 transition-all group"
      >
        <div className="bg-blue-100 p-4 rounded-full text-blue-600 group-hover:scale-110 transition-transform"><MessageSquare size={32}/></div>
        <span className="font-bold text-gray-800 md:text-lg">Assistant</span>
      </button>
      <button 
        onClick={() => setPage(Page.Routes)}
        className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm flex flex-col items-center justify-center space-y-3 hover:shadow-md hover:bg-blue-50 transition-all group"
      >
        <div className="bg-red-100 p-4 rounded-full text-red-600 group-hover:scale-110 transition-transform"><Bus size={32}/></div>
        <span className="font-bold text-gray-800 md:text-lg">ကားလိုင်းများ</span>
      </button>
      <button 
        onClick={() => setPage(Page.Map)}
        className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm flex flex-col items-center justify-center space-y-3 hover:shadow-md hover:bg-blue-50 transition-all group"
      >
        <div className="bg-green-100 p-4 rounded-full text-green-600 group-hover:scale-110 transition-transform"><MapIcon size={32}/></div>
        <span className="font-bold text-gray-800 md:text-lg">မြေပုံ</span>
      </button>
      <button 
        onClick={() => setPage(Page.FindRoute)}
        className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm flex flex-col items-center justify-center space-y-3 hover:shadow-md hover:bg-gray-50 transition-all group"
      >
        <div className="bg-purple-100 p-4 rounded-full text-purple-600 group-hover:scale-110 transition-transform"><ArrowRightLeft size={32}/></div>
        <span className="font-bold text-gray-800 md:text-lg">လမ်းကြောင်းရှာ</span>
      </button>
    </div>
  </div>
);

const RoutesPage: React.FC<{ 
  onRouteClick: (r: BusRoute) => void,
  onStopClick: (s: BusStop) => void 
}> = ({ onRouteClick, onStopClick }) => {
  const [routes, setRoutes] = useState<BusRoute[]>([]);
  const [stops, setStops] = useState<BusStop[]>([]);
  const [search, setSearch] = useState('');

  useEffect(() => {
    const fetchData = async () => {
      const [routesData, stopsData] = await Promise.all([
        db.busRoutes.toArray(),
        db.busStops.toArray()
      ]);
      setRoutes(routesData);
      setStops(stopsData);
    };
    fetchData();
  }, []);

  const stopInfoMap = useMemo(() => {
    const map = new Map<string, { mm: string, en: string }>();
    stops.forEach(s => map.set(s.name_mm, { mm: s.township_mm, en: s.township_en }));
    return map;
  }, [stops]);

  const filtered = useMemo(() => {
    const term = search.toLowerCase();
    return routes.filter(r => {
      const startStop = r.stops[0];
      const endStop = r.stops[r.stops.length - 1];
      const startInfo = stopInfoMap.get(startStop);
      const endInfo = stopInfoMap.get(endStop);

      return (
        r.id.toLowerCase().includes(term) ||
        (startInfo?.mm.toLowerCase().includes(term)) ||
        (endInfo?.mm.toLowerCase().includes(term)) ||
        startStop.toLowerCase().includes(term) ||
        endStop.toLowerCase().includes(term)
      );
    });
  }, [routes, search, stopInfoMap]);

  const handleStopClick = (e: React.MouseEvent, stopName: string) => {
    e.stopPropagation();
    const stop = stops.find(s => s.name_mm === stopName);
    if (stop) onStopClick(stop);
  };

  return (
    <div className="max-w-5xl mx-auto p-4 md:p-8 h-full flex flex-col space-y-6">
      <div className="relative shrink-0 max-w-xl mx-auto w-full">
        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
        <input 
          type="text" 
          placeholder="ကားလိုင်း သို့မဟုတ် မြို့နယ် ရှာဖွေပါ..." 
          className="w-full pl-12 pr-4 py-4 rounded-2xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white shadow-sm md:text-lg"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      <div className="flex-1 overflow-y-auto pb-24 md:pb-8">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
          {filtered.map(route => {
            const startStop = route.stops[0];
            const endStop = route.stops[route.stops.length - 1];
            const startTownship = stopInfoMap.get(startStop)?.mm || (startStop.includes('(') ? startStop.split('(')[1].replace(')', '') : startStop);
            const endTownship = stopInfoMap.get(endStop)?.mm || (endStop.includes('(') ? endStop.split('(')[1].replace(')', '') : endStop);

            return (
              <div 
                key={route.id} 
                onClick={() => onRouteClick(route)}
                className="bg-white p-5 rounded-2xl border border-gray-100 shadow-sm flex flex-col space-y-4 cursor-pointer hover:shadow-md hover:border-blue-100 transition-all border-l-4 group/card"
                style={{ borderLeftColor: route.color }}
              >
                <div className="flex items-start justify-between">
                  <div className="flex items-center space-x-4 overflow-hidden flex-1">
                    <RouteBadge routeId={route.id} color={route.color} />
                    <div className="flex flex-col overflow-hidden">
                       <div className="text-[18px] md:text-[20px] font-black text-gray-900 leading-tight flex items-center space-x-2">
                         <span className="hover:text-blue-600 transition-colors" onClick={(e) => handleStopClick(e, startStop)}>{startTownship}</span> 
                         <span className="text-gray-300 font-normal shrink-0">→</span> 
                         <span className="hover:text-blue-600 transition-colors" onClick={(e) => handleStopClick(e, endStop)}>{endTownship}</span>
                       </div>
                       <div className="flex flex-wrap items-center gap-2 mt-1.5">
                          <div className="text-[12px] md:text-[13px] font-bold text-gray-400 flex items-center space-x-1 truncate">
                            <MapPin size={12} className="shrink-0" />
                            <div className="truncate flex items-center space-x-1">
                              <span className="hover:text-blue-500 hover:underline transition-colors" onClick={(e) => handleStopClick(e, startStop)}>{startStop}</span> 
                              <span>မှ</span> 
                              <span className="hover:text-blue-500 hover:underline transition-colors" onClick={(e) => handleStopClick(e, endStop)}>{endStop}</span>
                            </div>
                          </div>
                          {route.operator && <OperatorBadge name={route.operator} />}
                       </div>
                    </div>
                  </div>
                  <div className="bg-gray-50 px-2 py-1.5 rounded-lg flex items-center space-x-1 shrink-0 border border-gray-100">
                    <Hash size={12} className="text-gray-400" />
                    <span className="text-[12px] font-black text-gray-600">{route.stops.length}</span>
                  </div>
                </div>
              </div>
            );
          })}
          {filtered.length === 0 && (
             <div className="text-center py-20 text-gray-400 col-span-full">ရှာဖွေမှု မတွေ့ရှိပါ။</div>
          )}
        </div>
      </div>
    </div>
  );
};

const MapPage: React.FC<{ stops: BusStop[], onStopClick: (s: BusStop) => void }> = ({ stops, onStopClick }) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<any>(null);
  const markersLayerRef = useRef<any>(null);
  const [isLocating, setIsLocating] = useState(false);
  const [search, setSearch] = useState('');
  const [showSearch, setShowSearch] = useState(false);

  const filteredStops = useMemo(() => {
    if (!search) return [];
    return stops.filter(s => 
      s.name_mm.includes(search) || 
      s.name_en.toLowerCase().includes(search.toLowerCase())
    ).slice(0, 10);
  }, [search, stops]);

  useEffect(() => {
    const L = (window as any).L;
    if (!L || !mapContainerRef.current || mapInstanceRef.current) return;

    const map = L.map(mapContainerRef.current, { zoomControl: false }).setView([16.8, 96.15], 13);
    mapInstanceRef.current = map;
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
    L.control.zoom({ position: 'bottomright' }).addTo(map);

    markersLayerRef.current = L.featureGroup().addTo(map);

    map.on('locationfound', (e: any) => {
      setIsLocating(false);
      L.circleMarker(e.latlng, { radius: 10, fillColor: '#10b981', color: '#fff', weight: 3, fillOpacity: 1 }).addTo(map).bindPopup("သင်၏နေရာ").openPopup();
      map.setView(e.latlng, 15);
    });

    setTimeout(() => map.invalidateSize(), 200);

    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    const L = (window as any).L;
    if (!L || !markersLayerRef.current || stops.length === 0) return;

    markersLayerRef.current.clearLayers();

    stops.forEach(s => {
      const marker = L.circleMarker([s.lat, s.lng], {
        radius: 7,
        fillColor: "#2563eb",
        color: "#fff",
        weight: 2,
        opacity: 1,
        fillOpacity: 0.8
      });

      marker.bindPopup(`
        <div class="p-2 min-w-[120px]">
          <div class="font-black text-gray-900 text-sm mb-0.5">${s.name_mm}</div>
          <div class="text-[10px] text-gray-500 font-bold uppercase mb-2">${s.township_mm}</div>
          <button id="detail-btn-${s.id}" class="w-full bg-blue-600 text-white text-[10px] py-1.5 rounded font-black hover:bg-blue-700 transition-all">အသေးစိတ်ကြည့်မည်</button>
        </div>
      `, { closeButton: false });

      marker.on('popupopen', () => {
        const btn = document.getElementById(`detail-btn-${s.id}`);
        if (btn) btn.onclick = () => onStopClick(s);
      });

      marker.addTo(markersLayerRef.current);
    });
  }, [stops, onStopClick]);

  const handleLocate = () => {
    if (mapInstanceRef.current) {
      setIsLocating(true);
      mapInstanceRef.current.locate({ setView: true, maxZoom: 15 });
    }
  };

  const jumpToStop = (s: BusStop) => {
    if (mapInstanceRef.current) {
      mapInstanceRef.current.setView([s.lat, s.lng], 16);
      setSearch('');
      setShowSearch(false);
    }
  };

  return (
    <div className="relative w-full h-full bg-gray-100 overflow-hidden flex flex-col">
      <div ref={mapContainerRef} className="flex-1 w-full bg-gray-200"></div>
      
      <div className="absolute top-4 left-4 right-4 md:left-auto md:w-80 md:right-4 z-[1000] space-y-2">
        <div className="relative">
          <input 
            type="text" 
            placeholder="မှတ်တိုင်အမည်ဖြင့် ရှာရန်..."
            className="w-full pl-10 pr-4 py-3 bg-white rounded-2xl shadow-2xl border border-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm font-medium"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onFocus={() => setShowSearch(true)}
          />
          <Search className="absolute left-3.5 top-3.5 text-gray-400" size={18} />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3.5 top-3.5 text-gray-400 hover:text-gray-600">
              <X size={18} />
            </button>
          )}
        </div>
        
        {showSearch && filteredStops.length > 0 && (
          <div className="bg-white rounded-2xl shadow-2xl border border-gray-100 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-200 max-h-[60vh] overflow-y-auto no-scrollbar">
            {filteredStops.map(s => (
              <button 
                key={s.id}
                onClick={() => jumpToStop(s)}
                className="w-full p-3 flex items-center space-x-3 hover:bg-blue-50 border-b border-gray-50 last:border-0 text-left transition-colors"
              >
                <div className="bg-blue-100 p-1.5 rounded-lg text-blue-600"><MapPin size={14} /></div>
                <div>
                  <div className="text-sm font-bold text-gray-800">{s.name_mm}</div>
                  <div className="text-[10px] text-gray-400 font-bold">{s.township_mm}</div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="absolute bottom-24 right-4 z-[1000] flex flex-col space-y-3">
        <button 
          onClick={handleLocate}
          disabled={isLocating}
          className="bg-white p-3.5 rounded-full shadow-2xl text-blue-600 border border-gray-100 hover:bg-blue-50 active:scale-90 transition-all"
        >
          {isLocating ? <RefreshCw className="animate-spin" size={22} /> : <Locate size={22} />}
        </button>
      </div>
    </div>
  );
};

const AssistantPage: React.FC<{ onRouteClick: (r: BusRoute) => void }> = ({ onRouteClick }) => {
  const [messages, setMessages] = useState<ChatMessage[]>([
    { role: 'assistant', content: 'မင်္ဂလာပါ။ YBS Assistant မှ ကြိုဆိုပါတယ်။ ဘယ်ကို သွားချင်ပါသလဲ? စာရိုက်ပြီး မေးနိုင်ပါတယ်။ ဥပမာ- "မြေနီကုန်းကနေ လှည်းတန်းကို ဘယ်လိုသွားရမလဲ"' }
  ]);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);
  const [allStopNames, setAllStopNames] = useState<string[]>([]);

  useEffect(() => {
    db.busStops.toArray().then(stops => {
      const names = new Set<string>();
      stops.forEach(s => names.add(s.name_mm));
      // Also add from INITIAL_ROUTES just in case some are missing in INITIAL_STOPS
      INITIAL_ROUTES.forEach(r => r.stops.forEach(s => names.add(s)));
      setAllStopNames(Array.from(names));
    });
  }, []);

  const scrollToBottom = () => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  const handleSend = async () => {
    const userQuery = input.trim();
    if (!userQuery || isTyping) return;
    
    setInput('');
    setMessages(prev => [...prev, { role: 'user', content: userQuery }]);
    setIsTyping(true);

    // Small delay to simulate "thinking" for better UX
    setTimeout(async () => {
      const extracted = extractStopsFromText(userQuery, allStopNames);
      
      let reply = "";
      let results: SearchResult[] = [];

      if (!extracted || (!extracted.start && !extracted.end)) {
        reply = "တောင်းပန်ပါတယ်၊ သင်ပြောတဲ့ မှတ်တိုင်အမည်ကို ရှာမတွေ့ပါဘူး။ မှတ်တိုင်အမည်လေး ပြန်စစ်ပေးပါဦး။";
      } else if (extracted.start && !extracted.end) {
        reply = `${extracted.start} ကနေ ဘယ်ကို သွားချင်တာလဲခင်ဗျာ?`;
      } else if (!extracted.start && extracted.end) {
        reply = `${extracted.end} ကို ဘယ်မှတ်တိုင်ကနေ လာမှာလဲခင်ဗျာ?`;
      } else if (extracted.start && extracted.end) {
        results = await performBFS(extracted.start, extracted.end);
        if (results.length > 0) {
          reply = `${extracted.start} မှ ${extracted.end} သို့ စီးရမည့် လမ်းကြောင်းများကို ရှာတွေ့ပါပြီ။`;
        } else {
          reply = `${extracted.start} မှ ${extracted.end} သို့ တိုက်ရိုက် သို့မဟုတ် တစ်ဆင့်ပြောင်း လမ်းကြောင်း ရှာမတွေ့ပါဘူး။`;
        }
      }

      setMessages(prev => [...prev, { role: 'assistant', content: reply, results: results.length > 0 ? results : undefined }]);
      setIsTyping(false);
    }, 600);
  };

  return (
    <div className="max-w-3xl mx-auto h-full flex flex-col bg-white md:shadow-2xl md:my-4 md:rounded-3xl overflow-hidden">
      <div className="bg-blue-600 p-4 flex items-center space-x-3 shrink-0">
        <div className="bg-white/20 p-2 rounded-xl">
           <Bot className="text-white" size={24} />
        </div>
        <div>
          <h2 className="text-white font-bold">YBS Smart Assistant</h2>
          <div className="flex items-center space-x-1">
            <div className="w-1.5 h-1.5 rounded-full bg-green-400"></div>
            <span className="text-[10px] text-blue-100 font-bold uppercase tracking-wider">Local Search Active</span>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-6 bg-slate-50/50">
        {messages.map((m, i) => (
          <div key={i} className={`flex flex-col ${m.role === 'user' ? 'items-end' : 'items-start'}`}>
            <div className="flex items-end space-x-2 max-w-[90%]">
              {m.role === 'assistant' && (
                <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center shrink-0 mb-1">
                  <Bot size={18} className="text-blue-600" />
                </div>
              )}
              <div className={`p-4 rounded-2xl text-sm leading-relaxed shadow-sm ${
                m.role === 'user' ? 'bg-blue-600 text-white rounded-tr-none' : 'bg-white text-gray-800 rounded-tl-none border border-gray-100'
              }`}>
                {m.content}
              </div>
              {m.role === 'user' && (
                <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center shrink-0 mb-1">
                  <User size={18} className="text-gray-500" />
                </div>
              )}
            </div>
            {m.results && (
              <div className="w-full mt-4 space-y-3 animate-in fade-in slide-in-from-bottom-2 duration-500">
                {m.results.map((res, idx) => (
                  <div key={idx} className="bg-white border border-blue-100 p-4 rounded-2xl space-y-4 shadow-sm ml-10">
                    <div className="flex items-center justify-between">
                       <div className="flex gap-2">
                         {res.steps.map((step, sidx) => (
                           <RouteBadge key={sidx} routeId={step.route.id} color={step.route.color} size="sm" onClick={() => onRouteClick(step.route)} />
                         ))}
                       </div>
                       <span className="text-[10px] font-black bg-blue-50 text-blue-600 px-2 py-0.5 rounded-full uppercase">
                         {res.transferCount === 0 ? 'တိုက်ရိုက်' : `${res.transferCount} ဆင့်ပြောင်း`}
                       </span>
                    </div>
                    <div className="space-y-3">
                      {res.steps.map((step, sidx) => (
                        <div key={sidx} className="flex items-start space-x-3 text-[13px]">
                          <div className="flex flex-col items-center mt-1">
                             <div className="w-2 h-2 rounded-full" style={{ backgroundColor: step.route.color }}></div>
                             {sidx < res.steps.length - 1 && <div className="w-0.5 h-8 bg-gray-100"></div>}
                          </div>
                          <div className="flex-1">
                            <p className="font-black text-gray-800">YBS {step.route.id}</p>
                            <p className="text-gray-500">{step.fromStop} <span className="text-gray-300 mx-1">→</span> {step.toStop}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
        {isTyping && (
          <div className="flex items-start space-x-2">
             <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center shrink-0">
               <Bot size={18} className="text-blue-600" />
             </div>
             <div className="bg-white p-4 rounded-2xl rounded-tl-none border border-gray-200 flex items-center space-x-1.5 shadow-sm">
                <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce"></div>
                <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
                <div className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce [animation-delay:-0.3s]"></div>
             </div>
          </div>
        )}
        <div ref={chatEndRef}></div>
      </div>

      <div className="p-4 border-t bg-gray-50 shrink-0">
        <div className="relative flex items-center space-x-2">
          <input 
            type="text" 
            placeholder="ဥပမာ- ဆူးလေကနေ လှည်းတန်းကို ဘယ်လိုသွားရမလဲ"
            className="flex-1 p-4 bg-white rounded-2xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-sm text-sm"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleSend()}
          />
          <button 
            onClick={handleSend}
            disabled={!input.trim() || isTyping}
            className="p-4 bg-blue-600 text-white rounded-2xl shadow-lg hover:bg-blue-700 active:scale-95 transition-all disabled:opacity-50"
          >
            <Send size={20} />
          </button>
        </div>
      </div>
    </div>
  );
};

const StopDetailPage: React.FC<{ stop: BusStop, onClose: () => void }> = ({ stop, onClose }) => {
  const [passingRoutes, setPassingRoutes] = useState<BusRoute[]>([]);

  useEffect(() => {
    db.busRoutes.toArray().then(routes => {
      const filtered = routes.filter(r => r.stops.includes(stop.name_mm));
      setPassingRoutes(filtered);
    });
  }, [stop]);

  useEffect(() => {
    const mapContainer = document.getElementById('stop-map');
    if (mapContainer && (window as any).L) {
      const L = (window as any).L;
      const map = L.map('stop-map').setView([stop.lat, stop.lng], 16);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
      L.marker([stop.lat, stop.lng]).addTo(map).bindPopup(stop.name_mm).openPopup();
      return () => map.remove();
    }
  }, [stop]);

  return (
    <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-8 overflow-hidden bg-black/40 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white w-full h-full md:max-w-2xl md:h-auto md:max-h-[90vh] flex flex-col md:rounded-3xl md:shadow-2xl overflow-hidden animate-in slide-in-from-bottom-10 duration-300">
        <div className="p-4 flex items-center justify-between border-b border-gray-100 shrink-0">
          <h3 className="text-lg font-bold truncate">{stop.name_mm} ({stop.name_en})</h3>
          <button onClick={onClose} className="p-2 bg-gray-100 hover:bg-gray-200 rounded-full transition-colors"><X size={20}/></button>
        </div>
        <div id="stop-map" className="w-full h-64 md:h-80 bg-gray-200 shrink-0"></div>
        <div className="p-6 flex-1 overflow-y-auto space-y-8 pb-24 md:pb-8">
          <div className="space-y-1">
            <p className="text-xs text-gray-400 uppercase tracking-widest font-black">တည်နေရာ</p>
            <p className="text-gray-800 text-lg md:text-xl font-medium leading-relaxed">{stop.road_mm}၊ {stop.township_mm}</p>
          </div>
          <div className="space-y-4">
            <p className="text-xs text-gray-400 uppercase tracking-widest font-black">ဖြတ်သန်းသွားသော လိုင်းများ ({passingRoutes.length})</p>
            <div className="flex flex-wrap gap-4">
              {passingRoutes.map(r => (
                <div key={r.id} className="flex flex-col items-center space-y-1.5 bg-gray-50 p-3 rounded-2xl border border-gray-100 min-w-[80px] hover:bg-blue-50 transition-colors cursor-pointer group">
                  <RouteBadge routeId={r.id} color={r.color} size="sm" />
                  {r.operator && <OperatorBadge name={r.operator} />}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const RouteDetailPage: React.FC<{ route: BusRoute, onClose: () => void, onStopClick: (s: BusStop) => void }> = ({ route, onClose, onStopClick }) => {
  const [stopsData, setStopsData] = useState<BusStop[]>([]);

  useEffect(() => {
    db.busStops.toArray().then(allStops => {
      const found = route.stops.map(sName => allStops.find(st => st.name_mm === sName)).filter(Boolean) as BusStop[];
      setStopsData(found);
    });
  }, [route]);

  useEffect(() => {
    if (stopsData.length > 0 && (window as any).L) {
      const L = (window as any).L;
      const map = L.map('route-map').setView([stopsData[0].lat, stopsData[0].lng], 13);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
      
      const latlngs = stopsData.map(s => [s.lat, s.lng]);
      const polyline = L.polyline(latlngs, { color: route.color, weight: 6, opacity: 0.8 }).addTo(map);
      map.fitBounds(polyline.getBounds().pad(0.1));

      stopsData.forEach(s => {
        L.circleMarker([s.lat, s.lng], { radius: 6, color: route.color, fillColor: '#fff', fillOpacity: 1, weight: 3 }).addTo(map).bindPopup(s.name_mm);
      });

      return () => map.remove();
    }
  }, [stopsData, route]);

  return (
    <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-8 overflow-hidden bg-black/40 backdrop-blur-sm animate-in fade-in duration-200">
      <div className="bg-white w-full h-full md:max-w-4xl md:h-[90vh] flex flex-col md:rounded-3xl md:shadow-2xl overflow-hidden animate-in slide-in-from-bottom-10 duration-300">
        <div className="p-4 flex items-center border-b border-gray-100 space-x-4 shrink-0">
          <button onClick={onClose} className="p-2 bg-gray-100 rounded-full hover:bg-gray-200 transition-colors"><ChevronRight className="rotate-180" size={20}/></button>
          <div className="flex items-center space-x-3">
             <RouteBadge routeId={route.id} color={route.color} size="sm" />
             {route.operator && <OperatorBadge name={route.operator} />}
             <h3 className="font-bold text-gray-800">လမ်းကြောင်းအသေးစိတ်</h3>
          </div>
        </div>
        <div id="route-map" className="w-full h-64 md:h-96 bg-gray-200 shrink-0"></div>
        <div className="p-6 flex-1 overflow-y-auto space-y-6 pb-24 md:pb-10">
           <div className="flex items-center justify-between border-b border-gray-50 pb-4">
             <div>
               <h4 className="text-xs text-gray-400 font-black uppercase tracking-widest">မှတ်တိုင်များ</h4>
               <p className="text-3xl font-black text-gray-900">{route.stops.length} ခု</p>
             </div>
             <div className="flex flex-col items-end text-sm font-bold text-gray-400">
               <span className="text-gray-900 font-black text-right">{route.stops[0]}</span>
               <div className="h-6 w-px bg-gray-200 my-1.5 mr-4"></div>
               <span className="text-gray-900 font-black text-right">{route.stops[route.stops.length-1]}</span>
             </div>
           </div>
           <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-12 gap-y-1">
             {route.stops.map((sName, idx) => (
               <div 
                  key={idx} 
                  className="flex items-start space-x-4 group cursor-pointer"
                  onClick={() => {
                     db.busStops.where('name_mm').equals(sName).first().then(s => s && onStopClick(s));
                  }}
               >
                 <div className="flex flex-col items-center mt-1.5 shrink-0">
                    <div className={`w-3.5 h-3.5 rounded-full border-2 border-white shadow-sm ${idx === 0 || idx === route.stops.length-1 ? 'scale-150 ring-2 ring-offset-2' : ''}`} style={{ backgroundColor: route.color }}></div>
                    <div className="w-0.5 h-10 bg-gray-100 group-last:bg-transparent"></div>
                 </div>
                 <div className="pb-4 border-b border-gray-50 w-full group-hover:bg-blue-50 transition-all rounded-xl px-3 -ml-2">
                   <span className="text-[16px] font-bold text-gray-700 group-hover:text-blue-700">{sName}</span>
                 </div>
               </div>
             ))}
           </div>
        </div>
      </div>
    </div>
  );
};

const StopsPage: React.FC<{ stops: BusStop[], onStopClick: (s: BusStop) => void }> = ({ stops, onStopClick }) => {
  const [search, setSearch] = useState('');
  const filtered = stops.filter(s => s.name_mm.includes(search) || s.township_mm.includes(search));

  return (
    <div className="max-w-5xl mx-auto p-4 md:p-8 h-full flex flex-col space-y-6">
      <div className="relative shrink-0 max-w-xl mx-auto w-full">
        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
        <input 
          type="text" 
          placeholder="မှတ်တိုင်ရှာရန်..." 
          className="w-full pl-12 pr-4 py-4 rounded-2xl border border-gray-200 md:text-lg focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-sm"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      <div className="flex-1 overflow-y-auto pb-24 md:pb-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
          {filtered.map(s => (
            <div 
              key={s.id} 
              onClick={() => onStopClick(s)} 
              className="p-5 bg-white rounded-2xl border border-gray-100 shadow-sm cursor-pointer hover:shadow-md hover:border-blue-100 hover:bg-gray-50 transition-all flex items-center justify-between group"
            >
              <div className="flex items-center space-x-4">
                <div className="bg-blue-50 p-2.5 rounded-full text-blue-500 group-hover:bg-blue-500 group-hover:text-white transition-colors">
                  <MapPin size={20} />
                </div>
                <div>
                  <p className="font-bold text-gray-800 text-lg">{s.name_mm}</p>
                  <p className="text-sm text-gray-400 font-medium">{s.township_mm}</p>
                </div>
              </div>
              <ChevronRight className="text-gray-300 group-hover:text-blue-500 transition-colors" size={20} />
            </div>
          ))}
          {filtered.length === 0 && (
             <div className="text-center py-20 text-gray-400 col-span-full">မှတ်တိုင် မတွေ့ပါ။</div>
          )}
        </div>
      </div>
    </div>
  );
};

const FindRoutePage: React.FC<{ onRouteClick: (r: BusRoute) => void }> = ({ onRouteClick }) => {
  const [stops, setStops] = useState<BusStop[]>([]);
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [locating, setLocating] = useState(false);
  const [mapPickerTarget, setMapPickerTarget] = useState<'start' | 'end' | null>(null);

  useEffect(() => {
    db.busStops.toArray().then(setStops);
  }, []);

  const allStopNames = useMemo(() => {
    const names = new Set<string>();
    stops.forEach(s => names.add(s.name_mm));
    INITIAL_ROUTES.forEach(r => r.stops.forEach(s => names.add(s)));
    return Array.from(names).sort((a, b) => a.localeCompare(b, 'my'));
  }, [stops]);

  const handleUseCurrentLocation = () => {
    if (!navigator.geolocation) {
      alert("Geolocation is not supported by your browser.");
      return;
    }

    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        if (stops.length === 0) {
          setLocating(false);
          return;
        }
        
        let nearestStop = stops[0];
        let minDistance = getDistance(latitude, longitude, stops[0].lat, stops[0].lng);

        stops.forEach(s => {
          const dist = getDistance(latitude, longitude, s.lat, s.lng);
          if (dist < minDistance) {
            minDistance = dist;
            nearestStop = s;
          }
        });

        setStart(nearestStop.name_mm);
        setLocating(false);
      },
      (error) => {
        console.error(error);
        setLocating(false);
        alert("တည်နေရာ ရှာမတွေ့ပါ။");
      },
      { enableHighAccuracy: true }
    );
  };

  const handleSearch = useCallback(async () => {
    const sTerm = start.trim();
    const eTerm = end.trim();
    if (!sTerm || !eTerm) return;
    
    setSearching(true);
    const found = await performBFS(sTerm, eTerm);
    setResults(found);
    setSearching(false);
  }, [start, end]);

  const handleSwap = () => {
    const temp = start;
    setStart(end);
    setEnd(temp);
  };

  return (
    <div className="max-w-5xl mx-auto p-4 md:p-8 h-full overflow-y-auto pb-24 md:pb-12 space-y-8">
      <div className="bg-white p-6 md:p-10 rounded-3xl border border-gray-200 shadow-xl space-y-6 max-w-3xl mx-auto">
        <div className="grid grid-cols-1 gap-6">
          <StopSearchInput 
            label="စတင်မည့်မှတ်တိုင်"
            value={start}
            onChange={setStart}
            allNames={allStopNames}
            placeholder="ရှာရန်..."
            indicatorColor="bg-green-500"
            icon={
              <div className="flex items-center space-x-2">
                <button 
                  onClick={handleUseCurrentLocation}
                  disabled={locating}
                  className="p-2 text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition-colors flex items-center space-x-1.5"
                >
                  {locating ? <RefreshCw className="animate-spin" size={16} /> : <Crosshair size={16} />}
                  <span className="text-xs font-bold uppercase tracking-wider">Near Me</span>
                </button>
                <button 
                  onClick={() => setMapPickerTarget('start')}
                  className="p-2 text-gray-600 bg-gray-50 hover:bg-gray-100 rounded-lg transition-colors"
                >
                  <MapIcon size={16} />
                </button>
              </div>
            }
          />

          <div className="flex justify-center -my-3 md:-my-4 relative z-10">
            <button 
              onClick={handleSwap}
              className="bg-white p-2.5 md:p-3 rounded-full border border-gray-200 shadow-lg text-blue-600 hover:bg-blue-50 active:scale-90 transition-all"
            >
              <ArrowRightLeft size={24} className="rotate-90 md:rotate-0" />
            </button>
          </div>

          <StopSearchInput 
            label="ဆင်းမည့်မှတ်တိုင်"
            value={end}
            onChange={setEnd}
            allNames={allStopNames}
            placeholder="ရှာရန်..."
            indicatorColor="bg-red-500"
            icon={
              <button 
                onClick={() => setMapPickerTarget('end')}
                className="p-2 text-gray-600 bg-gray-50 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <MapIcon size={16} />
              </button>
            }
          />
        </div>

        <button 
          onClick={handleSearch}
          disabled={!start || !end || searching}
          className="w-full bg-blue-600 text-white font-black text-lg py-5 rounded-2xl shadow-xl hover:bg-blue-700 active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center space-x-3"
        >
          {searching ? <RefreshCw className="animate-spin" size={24} /> : <Search size={24} />}
          <span>{searching ? 'ရှာဖွေနေပါသည်...' : 'လမ်းကြောင်းရှာပါ'}</span>
        </button>
      </div>

      {mapPickerTarget && (
        <MapSelectionModal 
          stops={stops}
          title={mapPickerTarget === 'start' ? 'စတင်မည့်မှတ်တိုင် ရွေးချယ်ပါ' : 'ဆင်းမည့်မှတ်တိုင် ရွေးချယ်ပါ'}
          onSelect={(stop) => mapPickerTarget === 'start' ? setStart(stop.name_mm) : setEnd(stop.name_mm)}
          onClose={() => setMapPickerTarget(null)}
        />
      )}

      <div className="space-y-6 max-w-4xl mx-auto">
        {results.length > 0 && results.map((res, i) => (
          <div key={i} className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-6 hover:shadow-md transition-all">
            <div className="flex items-center justify-between">
               <div className="flex items-center space-x-3 overflow-x-auto pb-1 no-scrollbar">
                  {res.steps.map((step, idx) => (
                    <React.Fragment key={idx}>
                      <RouteBadge routeId={step.route.id} color={step.route.color} size="sm" onClick={() => onRouteClick(step.route)} />
                      {idx < res.steps.length - 1 && <ChevronRight size={14} className="text-gray-300 shrink-0" />}
                    </React.Fragment>
                  ))}
               </div>
               <div className={`shrink-0 px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest ${
                 res.transferCount === 0 ? 'bg-green-100 text-green-700' : 
                 res.transferCount === 1 ? 'bg-orange-100 text-orange-700' : 'bg-red-100 text-red-700'
               }`}>
                 {res.transferCount === 0 ? 'တိုက်ရိုက်' : `${res.transferCount} ဆင့်ပြောင်း`}
               </div>
            </div>

            <div className="space-y-4">
               {res.steps.map((step, idx) => (
                 <div key={idx} className="flex items-start space-x-4">
                    <div className="flex flex-col items-center mt-1 shrink-0">
                       <div className="w-2.5 h-2.5 rounded-full border-2 border-white shadow-sm" style={{ backgroundColor: step.route.color }}></div>
                       {idx < res.steps.length && <div className="w-0.5 h-12 bg-gray-100"></div>}
                    </div>
                    <div className="flex-1 pb-2">
                       <div className="text-sm font-bold text-gray-800 flex items-center space-x-2">
                          <span className="bg-gray-100 px-2 py-0.5 rounded text-[11px]">စီးရန်</span>
                          <span>YBS {step.route.id}</span>
                          {step.route.operator && <OperatorBadge name={step.route.operator} />}
                       </div>
                       <div className="mt-1 text-[13px] text-gray-500 font-medium">
                          <span className="text-blue-600 font-bold">{step.fromStop}</span> မှတ်တိုင်မှ <span className="text-blue-600 font-bold">{step.toStop}</span> မှတ်တိုင်အထိ စီးပါ။
                       </div>
                    </div>
                 </div>
               ))}
            </div>
          </div>
        ))}

        {results.length === 0 && start && end && !searching && (
          <div className="text-center py-24 space-y-6">
            <div className="bg-gray-100 p-8 rounded-full w-24 h-24 flex items-center justify-center mx-auto text-gray-300">
               <Search size={48} />
            </div>
            <div className="space-y-2">
              <p className="text-gray-400 font-black text-2xl">လမ်းကြောင်း မတွေ့ပါ။</p>
              <p className="text-gray-300 font-medium">မှတ်တိုင်အမည် မှန်၊ မမှန် ပြန်စစ်ပေးပါ။ (အဆင့် ၄ ဆင့်ထက်ပိုသော လမ်းကြောင်းများ မပြနိုင်ပါ)</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

const SettingsPage: React.FC = () => {
  const [status, setStatus] = useState<'idle' | 'updating' | 'done'>('idle');

  const updateData = async () => {
    setStatus('updating');
    await db.busStops.clear();
    await db.busRoutes.clear();
    await db.busStops.bulkAdd(INITIAL_STOPS);
    await db.busRoutes.bulkAdd(INITIAL_ROUTES);
    setStatus('done');
    setTimeout(() => setStatus('idle'), 2000);
  };

  return (
    <div className="max-w-3xl mx-auto p-4 md:p-8 space-y-6">
      <h2 className="text-2xl font-black mb-6 text-gray-800">သတ်မှတ်ချက်များ (Settings)</h2>
      <div className="bg-white rounded-3xl border border-gray-200 overflow-hidden shadow-sm">
        <div className="p-6 border-b border-gray-100 flex justify-between items-center hover:bg-gray-50 transition-colors">
          <div className="flex items-center space-x-4">
            <div className="bg-blue-100 p-3 rounded-2xl text-blue-600"><RefreshCw size={24} /></div>
            <div>
              <p className="font-black text-gray-800 text-lg">Offline Data Update</p>
              <p className="text-sm text-gray-400 font-medium">ဒေတာအသစ်များကို ဒေါင်းလုဒ်လုပ်ပါ</p>
            </div>
          </div>
          <button 
            onClick={updateData}
            className={`px-6 py-3 rounded-xl font-black transition-all shadow-sm ${status === 'updating' ? 'bg-gray-100 text-gray-400' : 'bg-blue-600 text-white hover:bg-blue-700 active:scale-95'}`}
          >
            {status === 'idle' && 'Update Now'}
            {status === 'updating' && 'Updating...'}
            {status === 'done' && 'Completed!'}
          </button>
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  const [page, setPage] = useState<Page>(Page.Home);
  const [selectedRoute, setSelectedRoute] = useState<BusRoute | null>(null);
  const [selectedStop, setSelectedStop] = useState<BusStop | null>(null);
  const [stops, setStops] = useState<BusStop[]>([]);
  const [isInitializing, setIsInitializing] = useState(true);
  const [prevPage, setPrevPage] = useState<Page>(Page.Home);

  useEffect(() => {
    const checkData = async () => {
      const stopCount = await db.busStops.count();
      if (stopCount === 0) {
        await db.busStops.bulkAdd(INITIAL_STOPS);
        await db.busRoutes.bulkAdd(INITIAL_ROUTES);
      }
      const loadedStops = await db.busStops.toArray();
      setStops(loadedStops);
      setIsInitializing(false);
    };
    checkData();
  }, []);

  const navigateToRoute = useCallback((r: BusRoute) => {
    setSelectedRoute(r);
    setPage(Page.RouteDetail);
  }, []);

  const navigateToStop = useCallback((s: BusStop) => {
    setPrevPage(page);
    setSelectedStop(s);
    setPage(Page.StopDetail);
  }, [page]);

  const renderPage = () => {
    if (isInitializing) {
      return (
        <div className="flex flex-col items-center justify-center h-full space-y-4 py-20">
          <RefreshCw className="animate-spin text-blue-600" size={48} />
          <p className="text-gray-500 font-black text-xl">ဒေတာများ ပြင်ဆင်နေပါသည်...</p>
        </div>
      );
    }

    switch (page) {
      case Page.Home: return <HomePage setPage={setPage} />;
      case Page.Routes: return <RoutesPage onRouteClick={navigateToRoute} onStopClick={navigateToStop} />;
      case Page.Map: return <MapPage stops={stops} onStopClick={navigateToStop} />;
      case Page.Assistant: return <AssistantPage onRouteClick={navigateToRoute} />;
      case Page.FindRoute: return <FindRoutePage onRouteClick={navigateToRoute} />;
      case Page.Settings: return <SettingsPage />;
      case Page.Stops: return <StopsPage stops={stops} onStopClick={navigateToStop} />;
      case Page.Favorites: return (
        <div className="p-20 text-center flex flex-col items-center space-y-6 text-gray-400">
          <div className="bg-gray-100 p-8 rounded-full">
            <Star size={64} className="text-gray-300" />
          </div>
          <div className="space-y-1">
            <p className="font-black text-2xl text-gray-600">Saved Items</p>
            <p className="font-medium">သိမ်းဆည်းထားသော အချက်အလက် မရှိသေးပါ။</p>
          </div>
        </div>
      );
      default: return <HomePage setPage={setPage} />;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col overflow-x-hidden h-screen">
      <Header currentPage={page} setPage={setPage} />
      
      <main className="flex-1 relative w-full overflow-hidden">
        <div className="absolute inset-0 overflow-y-auto">
           {renderPage()}
        </div>
      </main>

      {page === Page.RouteDetail && selectedRoute && (
        <RouteDetailPage 
          route={selectedRoute} 
          onClose={() => setPage(Page.Routes)} 
          onStopClick={navigateToStop}
        />
      )}

      {page === Page.StopDetail && selectedStop && (
        <StopDetailPage 
          stop={selectedStop} 
          onClose={() => {
            setPage(prevPage);
            setSelectedStop(null);
          }} 
        />
      )}

      <MobileBottomNav currentPage={page} setPage={setPage} />
    </div>
  );
};

export default App;
