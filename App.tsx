import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { Routes, Route, useNavigate, useLocation, useParams } from 'react-router-dom';
import { loadRoutesFromFiles, loadStopsFromRouteFiles } from './data_constants';
import { Page, BusStop, BusRoute } from './types';
import { db } from './db';
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
  User,
  ArrowRight
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
  totalDistance: number;
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

const performBFS = async (start: string, end: string, allRoutes: BusRoute[], allStops: BusStop[]): Promise<SearchResult[]> => {
  const stopMap = new Map<string, BusStop>();
  allStops.forEach((s) => stopMap.set(s.name_mm, s));

  const queue: { currentStop: string; path: PathStep[] }[] = [{ currentStop: start, path: [] }];
  const visitedStops = new Set<string>([start]);
  const finalResults: SearchResult[] = [];
  const MAX_TRANSFERS = 4;

  const calculatePathDistance = (path: PathStep[]): number => {
    let totalDistance = 0;
    path.forEach(step => {
      const fromStop = stopMap.get(step.fromStop);
      const toStop = stopMap.get(step.toStop);
      if (fromStop && toStop) {
        totalDistance += getDistance(fromStop.lat, fromStop.lng, toStop.lat, toStop.lng);
      }
    });
    return totalDistance;
  };

  while (queue.length > 0) {
    const { currentStop, path } = queue.shift()!;
    if (path.length > MAX_TRANSFERS + 1) break;

    const availableRoutes = allRoutes.filter(r => r.stops.includes(currentStop));
    for (const route of availableRoutes) {
      if (path.some(step => step.route.id === route.id)) continue;
      if (route.stops.includes(end)) {
        const finalPath = [...path, { route, fromStop: currentStop, toStop: end }];
        const totalDistance = calculatePathDistance(finalPath);
        finalResults.push({ steps: finalPath, transferCount: finalPath.length - 1, totalDistance });
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
  return finalResults.sort((a, b) => a.transferCount - b.transferCount || a.totalDistance - b.totalDistance);
};

// --- Local NLP Logic (No AI Needed) ---
const extractStopsFromText = (text: string, allStopNames: string[]) => {
  const normalizedText = text.trim();
  
  const sortedNames = [...allStopNames].sort((a, b) => b.length - a.length);
  
  const foundStops: { name: string, index: number }[] = [];
  
  sortedNames.forEach(name => {
    if (normalizedText.includes(name)) {
      const index = normalizedText.indexOf(name);
      const isOverlapping = foundStops.some(s => 
        (index >= s.index && index < s.index + s.name.length) ||
        (index + name.length > s.index && index + name.length <= s.index + s.name.length)
      );
      if (!isOverlapping) {
        foundStops.push({ name, index });
      }
    }
  });

  foundStops.sort((a, b) => a.index - b.index);

  if (foundStops.length < 1) return null;

  let start: string | null = null;
  let end: string | null = null;

  const fromKeywords = ["ကနေ", "မှ"];
  const toKeywords = ["ကို", "သို့", "သွားချင်တာ"];

  if (foundStops.length >= 2) {
    const firstStop = foundStops[0];
    const secondStop = foundStops[1];
    
    const textAfterFirst = normalizedText.substring(firstStop.index + firstStop.name.length, secondStop.index);
    const hasFromMarker = fromKeywords.some(k => textAfterFirst.includes(k));
    
    if (hasFromMarker) {
      start = firstStop.name;
      end = secondStop.name;
    } else {
      start = firstStop.name;
      end = secondStop.name;
    }
  } else if (foundStops.length === 1) {
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
          <div class="text-[9px] text-amber-600 font-semibold mb-1">${(s.distance * 1000).toFixed(0)}m away</div>
          <button id="select-stop-${s.id}" class="w-full bg-slate-900 text-white text-[10px] px-2 py-1.5 rounded-lg font-medium hover:bg-slate-800 transition-colors">ရွေးချယ်မည်</button>
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
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-[100] flex items-end md:items-center justify-center p-0 md:p-4 animate-fade-in">
      <div className="bg-white w-full max-w-2xl rounded-t-2xl md:rounded-2xl h-[90vh] flex flex-col overflow-hidden shadow-lg relative">
        <div className="px-5 py-4 border-b border-slate-100 flex items-center justify-between shrink-0">
          <div>
            <h3 className="font-semibold text-slate-900 text-base">{title}</h3>
            <p className="text-xs text-slate-400 mt-0.5">၁ ကီလိုမီတာအတွင်း ရှာဖွေနေပါသည်</p>
          </div>
          <button onClick={onClose} className="ui-btn-icon">
            <X size={18} />
          </button>
        </div>
        
        <div className="relative flex-1 bg-slate-100">
          <div id="selection-map" className="w-full h-full"></div>
          <div className="absolute inset-0 pointer-events-none flex items-center justify-center z-[1000]">
            <div className="w-5 h-5 border-2 border-brand rounded-full bg-brand/20"></div>
          </div>
          <button 
            onClick={handleLocate}
            disabled={isLocating}
            className="absolute bottom-4 right-4 z-[1000] ui-btn-icon"
          >
            {isLocating ? <RefreshCw className="animate-spin" size={20} /> : <Locate size={20} />}
          </button>
        </div>

        <div className="border-t border-slate-100 shrink-0 h-1/3 flex flex-col bg-slate-50">
          <div className="px-5 py-3 flex items-center justify-between">
            <span className="ui-label">အနီးဆုံးမှတ်တိုင်များ ({nearbyStops.length})</span>
          </div>
          <div className="flex-1 overflow-y-auto px-3 pb-3 space-y-1.5">
            {nearbyStops.length > 0 ? (
              nearbyStops.map(s => (
              <button
                key={s.id}
                onClick={() => onSelect(s)}
                className="w-full p-3 flex items-center justify-between bg-white hover:bg-slate-50 border border-slate-100 rounded-xl transition-colors"
              >
                  <div className="flex items-center gap-3">
                    <div className="bg-brand-light p-2 rounded-lg text-brand">
                      <MapPin size={14} />
                    </div>
                    <div className="text-left">
                      <p className="text-sm font-medium text-slate-800">{s.name_mm}</p>
                      <p className="text-xs text-slate-400">{s.township_mm}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="ui-badge ui-badge-accent">
                      {(s.distance * 1000).toFixed(0)}m
                    </span>
                    <ChevronRight size={14} className="text-slate-300" />
                  </div>
                </button>
              ))
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-slate-400 py-10">
                <Search size={24} className="mb-2 opacity-30" />
                <p className="text-sm font-medium">ဤနေရာအနီးတွင် မှတ်တိုင်မရှိပါ</p>
                <p className="text-xs mt-1">မြေပုံကို ရွှေ့ကြည့်ပါ</p>
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
        <label className="ui-label flex items-center gap-2">
          <div className={`w-2 h-2 rounded-full ${indicatorColor}`}></div>
          <span>{label}</span>
        </label>
        {icon}
      </div>
      <div className="relative">
        <input 
          type="text"
          className="ui-input"
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
          <div className="absolute top-full left-0 right-0 mt-1.5 bg-white border border-slate-200 rounded-xl shadow-lg z-[80] max-h-60 overflow-y-auto">
            {filtered.map((name, i) => (
              <div 
                key={i}
                className="px-4 py-3 hover:bg-slate-50 cursor-pointer text-sm text-slate-700 border-b border-slate-50 last:border-0"
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

const MobileBottomNav: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const items = [
    { id: '/', icon: Home, label: 'ပင်မ' },
    { id: '/assistant', icon: MessageSquare, label: 'Assistant' },
    { id: '/routes', icon: Bus, label: 'လိုင်းများ' },
    { id: '/map', icon: MapIcon, label: 'မြေပုံ' },
    { id: '/find-route', icon: Search, label: 'လမ်းကြောင်း' },
  ];

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-white/90 backdrop-blur-lg border-t border-slate-200/80 flex justify-around items-center h-[4.25rem] px-2 z-[1001] md:hidden safe-area-bottom">
      {items.map(item => {
        const isActive = location.pathname === item.id;
        return (
          <button
            key={item.id}
            onClick={() => navigate(item.id)}
            className={`flex flex-col items-center justify-center gap-0.5 w-full py-1 min-w-0 transition-colors ${isActive ? 'text-brand' : 'text-slate-400'}`}
          >
            <div className={`p-1.5 rounded-xl transition-colors ${isActive ? 'bg-brand-light' : ''}`}>
              <item.icon size={20} strokeWidth={isActive ? 2.5 : 2} />
            </div>
            <span className="text-[10px] font-medium leading-tight truncate">{item.label}</span>
          </button>
        );
      })}
    </nav>
  );
};

const Header: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const navItems = [
    { id: '/', icon: Home, label: 'Home' },
    { id: '/assistant', icon: MessageSquare, label: 'Assistant' },
    { id: '/routes', icon: Bus, label: 'Routes' },
    { id: '/stops', icon: MapPin, label: 'Stops' },
    { id: '/map', icon: MapIcon, label: 'Map' },
    { id: '/find-route', icon: Search, label: 'Find Route' },
  ];

  return (
    <header className="bg-white border-b border-slate-200/80 sticky top-0 z-40">
      <div className="max-w-5xl mx-auto px-4 h-14 flex justify-between items-center">
        <button className="flex items-center gap-2.5" onClick={() => navigate('/')}>
          <div className="bg-slate-900 p-2 rounded-xl">
            <Bus size={18} className="text-white" />
          </div>
          <div className="flex items-center gap-2">
            <h1 className="text-base font-bold text-slate-900 tracking-tight">YBS Guide</h1>
            <span className="text-[10px] font-semibold text-slate-400 bg-slate-100 px-1.5 py-0.5 rounded">3.0</span>
          </div>
        </button>

        <nav className="hidden md:flex items-center gap-1">
          {navItems.map(item => {
            const isActive = location.pathname === item.id;
            return (
              <button
                key={item.id}
                onClick={() => navigate(item.id)}
                className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive ? 'bg-slate-100 text-slate-900' : 'text-slate-500 hover:text-slate-900 hover:bg-slate-50'
                }`}
              >
                <item.icon size={16} />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <button onClick={() => navigate('/settings')} className="ui-btn-ghost p-2 rounded-xl">
          <Settings size={20} />
        </button>
      </div>
    </header>
  );
};

const RouteBadge: React.FC<{ routeId: string, color: string, onClick?: () => void, size?: 'sm' | 'md' }> = ({ routeId, color, onClick, size = 'md' }) => (
  <div 
    onClick={onClick}
    style={{ backgroundColor: color }}
    className={`rounded-lg text-white font-semibold shadow-sm cursor-pointer hover:opacity-90 active:scale-95 transition-all flex items-center justify-center shrink-0 ${size === 'sm' ? 'px-2.5 py-1 text-xs min-w-[36px] h-7' : 'px-4 py-2 text-sm min-w-[52px] h-10'}`}
  >
    {routeId}
  </div>
);

const OperatorBadge: React.FC<{ name: string }> = ({ name }) => (
  <span className="ui-badge">
    <CreditCard size={10} />
    {name}
  </span>
);

const TRAVEL_TIPS = [
  {
    icon: Info,
    title: 'ရာသီဥတု ပြင်ဆင်မှု',
    titleEn: 'Weather Prep',
    desc: 'နေပူရင် ဦးထုပ်/နေကာမျက်မှန်၊ မိုးရွာရင် ထီးဆောင်သွားပါ။',
    descEn: 'Bring a hat or sunglasses in sun; carry an umbrella when rainy.',
  },
  {
    icon: User,
    title: 'လုံခြုံရေး သတိပေးချက်',
    titleEn: 'Safety',
    desc: 'လူကျပ်တဲ့အချိန်မှာ ခိတ်နှိုက်နဲ့ သူခိုးတွေကို အထူးသတိထားပါ။',
    descEn: 'Watch for pickpockets during crowded times on the bus.',
  },
  {
    icon: Navigation,
    title: 'မှတ်တိုင်မကျော်စေရန်',
    titleEn: 'Don\'t Miss Your Stop',
    desc: 'အိပ်ပျော်မသွားအောင် ဖုန်းအချက်ပေးသံ ပေးထားပါ။',
    descEn: 'Set a phone alarm or ask a fellow passenger to wake you.',
  },
  {
    icon: CreditCard,
    title: 'YBS ကတ် အကြံပြုချက်',
    titleEn: 'YBS Card Tips',
    desc: 'ကတ်ထဲ ငွေကြိုတင်ဖြည့်ပြီး လက်ကျန်ငွေကို ပုံမှန်စစ်ဆေးပါ။',
    descEn: 'Top up your card in advance and check balance regularly.',
  },
];

const HomePage: React.FC = () => {
  const navigate = useNavigate();

  const quickActions = [
    { path: '/find-route', icon: Search, label: 'လမ်းကြောင်း ရှာရန်', color: 'bg-slate-900' },
    { path: '/routes', icon: Bus, label: 'ကားလိုင်းများ', color: 'bg-brand' },
    { path: '/map', icon: MapIcon, label: 'မြေပုံ', color: 'bg-emerald-600' },
    { path: '/assistant', icon: MessageSquare, label: 'Assistant', color: 'bg-violet-600' },
  ];

  return (
    <div className="max-w-5xl mx-auto px-4 py-6 md:py-10 space-y-8 pb-24 md:pb-10">
      {/* Hero */}
      <section className="text-center space-y-3 pt-2">
        <h2 className="text-2xl md:text-3xl font-bold text-slate-900 tracking-tight">
          ရန်ကုန် YBS လမ်းညွှန်
        </h2>
        <p className="text-slate-500 text-sm md:text-base max-w-md mx-auto">
          ကားလိုင်းရှာဖွေခြင်း၊ လမ်းကြောင်းရှာခြင်းနှင့် မြေပုံကြည့်ရှုခြင်း — အားလုံးတစ်နေရာတည်း
        </p>
      </section>

      {/* Quick Actions */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {quickActions.map(action => (
          <button
            key={action.path}
            onClick={() => navigate(action.path)}
            className="ui-card ui-card-interactive p-4 flex flex-col items-center gap-3 text-center"
          >
            <div className={`${action.color} p-3 rounded-xl text-white`}>
              <action.icon size={22} />
            </div>
            <span className="text-sm font-semibold text-slate-800">{action.label}</span>
          </button>
        ))}
      </section>

      {/* Travel Tips */}
      <section className="space-y-4">
        <h3 className="ui-section-title">ခရီးသွားရန် အကြံပြုချက်များ</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {TRAVEL_TIPS.map((tip, i) => (
            <div key={i} className="ui-card p-4 flex gap-4">
              <div className="bg-slate-100 p-2.5 rounded-xl h-fit shrink-0">
                <tip.icon size={18} className="text-slate-600" />
              </div>
              <div className="space-y-1 min-w-0">
                <p className="font-semibold text-slate-800 text-sm">{tip.title}</p>
                <p className="text-xs text-slate-500 leading-relaxed">{tip.desc}</p>
                <p className="text-xs text-slate-400 leading-relaxed">{tip.descEn}</p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};

const RoutesPage: React.FC<{
  onRouteClick: (r: BusRoute) => void,
  onStopClick: (s: BusStop) => void,
  favorites: Set<string>,
  onToggleFavorite: (routeId: string) => void
  routes: BusRoute[];
  stops: BusStop[];
}> = ({ onRouteClick, onStopClick, favorites, onToggleFavorite, routes, stops }) => {
  const [search, setSearch] = useState('');

  const stopInfoMap = useMemo(() => {
    const map = new Map<string, { township: string, name_en: string }>();
    stops.forEach(s => map.set(s.name_mm, { township: s.township_mm, name_en: s.name_en }));
    return map;
  }, [stops]);

  const filtered = useMemo(() => {
    let result = routes;

    // Apply search filter
    const term = search.toLowerCase().trim();
    if (term) {
      result = result.filter(r => {
        const startStop = r.stops[0];
        const endStop = r.stops[r.stops.length - 1];
        const startTownship = stopInfoMap.get(startStop)?.township || "";
        const endTownship = stopInfoMap.get(endStop)?.township || "";
        const startStopEn = stopInfoMap.get(startStop)?.name_en || "";
        const endStopEn = stopInfoMap.get(endStop)?.name_en || "";

        // Check route ID
        if (r.id.toLowerCase().includes(term)) return true;

        // Check operator
        if (r.operator && r.operator.toLowerCase().includes(term)) return true;

        // Check townships
        if (startTownship.toLowerCase().includes(term) || endTownship.toLowerCase().includes(term)) return true;

        // Check start/end stops
        if (startStop.toLowerCase().includes(term) || endStop.toLowerCase().includes(term)) return true;
        if (startStopEn.toLowerCase().includes(term) || endStopEn.toLowerCase().includes(term)) return true;

        // Check all stops in route (limit to first 10 for performance)
        return r.stops.slice(0, 10).some(stop => {
          const stopEn = stopInfoMap.get(stop)?.name_en || "";
          return stop.toLowerCase().includes(term) || stopEn.toLowerCase().includes(term);
        });
      });
    }

    return result.sort((a, b) => {
      const numA = parseInt(a.id, 10) || 0;
      const numB = parseInt(b.id, 10) || 0;
      if (numA !== numB) return numA - numB;
      return a.id.localeCompare(b.id, 'my');
    });
  }, [routes, search, stopInfoMap]);

  const handleStopClick = (e: React.MouseEvent, stopName: string) => {
    e.stopPropagation();
    const stop = stops.find(s => s.name_mm === stopName);
    if (stop) onStopClick(stop);
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-5 md:py-8 h-full flex flex-col gap-5">
      <div className="shrink-0 space-y-2">
        <div className="relative max-w-xl mx-auto w-full">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
          <input
            type="text"
            placeholder="ကားလိုင်း သို့မဟုတ် မှတ်တိုင် ရှာဖွေပါ..."
            className="ui-input pl-11 text-sm md:text-base"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <p className="text-center text-xs text-slate-400">
          {search.trim()
            ? `${filtered.length} ခု တွေ့ရှိပါသည်`
            : `စုစုပေါင်း လိုင်း ${filtered.length} ခု`}
        </p>
      </div>
      <div className="flex-1 overflow-y-auto pb-20 md:pb-8">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {filtered.map(route => (
              <div 
                key={route.id} 
                onClick={() => onRouteClick(route)}
                className="ui-card ui-card-interactive p-4 flex flex-col gap-3 cursor-pointer border-l-[3px]"
                style={{ borderLeftColor: route.color }}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <RouteBadge routeId={route.id} color={route.color} size="sm" />
                    <div className="min-w-0">
                       <div className="flex flex-wrap items-center gap-2">
                          {route.line_name && (
                            <span className="text-sm font-medium text-slate-800 truncate">
                              {route.line_name}
                            </span>
                          )}
                          {route.operator && <OperatorBadge name={route.operator} />}
                       </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5 shrink-0">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onToggleFavorite(route.id);
                      }}
                      className={`p-2 rounded-lg transition-colors ${
                        favorites.has(route.id)
                          ? 'bg-brand-light text-brand'
                          : 'text-slate-300 hover:text-slate-500 hover:bg-slate-50'
                      }`}
                    >
                      <Star size={16} className={favorites.has(route.id) ? 'fill-current' : ''} />
                    </button>
                    <span className="ui-badge">
                      <Hash size={10} />
                      {route.stops.length}
                    </span>
                  </div>
                </div>
              </div>
          ))}
          {filtered.length === 0 && (
             <div className="text-center py-16 text-slate-400 col-span-full">
               <Search size={32} className="mx-auto mb-3 opacity-30" />
               <p className="font-medium">ရှာဖွေမှု မတွေ့ရှိပါ</p>
             </div>
          )}
        </div>
      </div>
    </div>
  );
};

const MapPage: React.FC<{ stops: BusStop[], routes: BusRoute[], onStopClick: (s: BusStop) => void }> = ({ stops, routes, onStopClick }) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<any>(null);
  const markersLayerRef = useRef<any>(null);
  const routesLayerRef = useRef<any>(null);
  const [isLocating, setIsLocating] = useState(false);
  const [search, setSearch] = useState('');
  const [showSearch, setShowSearch] = useState(false);

  const filteredStops = useMemo(() => {
    if (!search) return [];
    const term = search.toLowerCase();
    return stops.filter(s =>
      s.name_mm.toLowerCase().includes(term) ||
      s.name_en.toLowerCase().includes(term) ||
      s.road_mm.toLowerCase().includes(term) ||
      s.road_en.toLowerCase().includes(term) ||
      s.township_mm.toLowerCase().includes(term) ||
      s.township_en.toLowerCase().includes(term)
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
    routesLayerRef.current = L.featureGroup().addTo(map);

    map.on('locationfound', (e: any) => {
      setIsLocating(false);
      try {
        L.circleMarker(e.latlng, { radius: 10, fillColor: '#10b981', color: '#fff', weight: 3, fillOpacity: 1 }).addTo(map).bindPopup("သင်၏နေရာ").openPopup();
      } catch {}
      try {
        map.setView(e.latlng, 15);
      } catch {}
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
          <button id="detail-btn-${s.id}" class="w-full bg-slate-900 text-white text-[10px] py-1.5 rounded-lg font-medium hover:bg-slate-800 transition-all">အသေးစိတ်ကြည့်မည်</button>
        </div>
      `, { closeButton: false });

      marker.on('popupopen', () => {
        const btn = document.getElementById(`detail-btn-${s.id}`);
        if (btn) btn.onclick = () => onStopClick(s);
      });

      marker.addTo(markersLayerRef.current);
    });
  }, [stops, onStopClick]);

  useEffect(() => {
    const L = (window as any).L;
    if (!L || !routesLayerRef.current || routes.length === 0) return;

    routesLayerRef.current.clearLayers();

    // Route lines are hidden as per user request - only map icons are shown
  }, [routes]);

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
    <div className="relative w-full h-full bg-slate-100 overflow-hidden flex flex-col">
      <div ref={mapContainerRef} className="flex-1 w-full bg-slate-200"></div>

      <div className="absolute top-3 sm:top-4 left-3 sm:left-4 right-3 sm:right-4 md:left-auto md:w-80 md:right-4 z-[1000] space-y-2">
        <div className="relative">
          <input
            type="text"
            placeholder="မှတ်တိုင်အမည်ဖြင့် ရှာရန်..."
            className="ui-input pl-10 shadow-md text-sm"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onFocus={() => setShowSearch(true)}
          />
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
              <X size={16} />
            </button>
          )}
        </div>

        {showSearch && filteredStops.length > 0 && (
          <div className="bg-white rounded-xl shadow-lg border border-slate-100 overflow-hidden animate-slide-up max-h-[50vh] sm:max-h-[60vh] overflow-y-auto no-scrollbar">
            {filteredStops.map(s => (
              <button
                key={s.id}
                onClick={() => jumpToStop(s)}
                className="w-full p-3 flex items-center gap-3 hover:bg-slate-50 border-b border-slate-50 last:border-0 text-left transition-colors"
              >
                <div className="bg-brand-light p-1.5 rounded-lg text-brand"><MapPin size={14} /></div>
                <div>
                  <div className="text-sm font-medium text-slate-800">{s.name_mm}</div>
                  <div className="text-xs text-slate-400">{s.township_mm}</div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="absolute bottom-20 sm:bottom-24 right-3 sm:right-4 z-[1000]">
        <button
          onClick={handleLocate}
          disabled={isLocating}
          className="ui-btn-icon"
        >
          {isLocating ? <RefreshCw className="animate-spin" size={20} /> : <Locate size={20} />}
        </button>
      </div>
    </div>
  );
};

const AssistantPage: React.FC<{ onRouteClick: (r: BusRoute) => void; routes: BusRoute[]; stops: BusStop[] }> = ({ onRouteClick, routes, stops }) => {
  const [messages, setMessages] = useState<ChatMessage[]>([
    { role: 'assistant', content: 'မင်္ဂလာပါ။ YBS Assistant မှ ကြိုဆိုပါတယ်။ ဘယ်ကို သွားချင်ပါသလဲ? စာရိုက်ပြီး မေးနိုင်ပါတယ်။ ဥပမာ- "မြေနီကုန်းကနေ လှည်းတန်းကို ဘယ်လိုသွားရမလဲ"' }
  ]);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);
  const [allStopNames, setAllStopNames] = useState<string[]>([]);

  useEffect(() => {
    const names = new Set<string>();
    stops.forEach((s) => names.add(s.name_mm));
    routes.forEach((r) => r.stops.forEach((s) => names.add(s)));
    setAllStopNames(Array.from(names));
  }, [routes, stops]);


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
        results = await performBFS(extracted.start, extracted.end, routes, stops);
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
    <div className="max-w-3xl mx-auto h-full flex flex-col bg-white md:shadow-lg md:my-4 md:rounded-2xl overflow-hidden border border-slate-100">
      <div className="flex-1 overflow-y-auto p-4 space-y-5 bg-slate-50 pb-20 md:pb-4">
        {messages.map((m, i) => (
          <div key={i} className={`flex flex-col ${m.role === 'user' ? 'items-end' : 'items-start'}`}>
            <div className="flex items-end gap-2 max-w-[90%]">
              {m.role === 'assistant' && (
                <div className="w-8 h-8 rounded-full bg-slate-900 flex items-center justify-center shrink-0 mb-1">
                  <Bot size={16} className="text-white" />
                </div>
              )}
              <div className={`px-4 py-3 rounded-2xl text-sm leading-relaxed ${
                m.role === 'user' ? 'bg-slate-900 text-white rounded-br-md' : 'bg-white text-slate-700 rounded-bl-md border border-slate-100 shadow-sm'
              }`}>
                {m.content}
              </div>
              {m.role === 'user' && (
                <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center shrink-0 mb-1">
                  <User size={16} className="text-slate-500" />
                </div>
              )}
            </div>
            {m.results && (
              <div className="w-full mt-3 space-y-2.5 animate-slide-up">
                {m.results.map((res, idx) => (
                  <div key={idx} className="ui-card p-4 space-y-3 ml-10">
                    <div className="flex items-center justify-between">
                       <div className="flex gap-2">
                         {res.steps.map((step, sidx) => (
                           <RouteBadge key={sidx} routeId={step.route.id} color={step.route.color} size="sm" onClick={() => onRouteClick(step.route)} />
                         ))}
                       </div>
                       <span className="ui-badge ui-badge-accent">
                         {res.transferCount === 0 ? 'တိုက်ရိုက်' : `${res.transferCount} ဆင့်ပြောင်း`}
                       </span>
                    </div>
                    <div className="space-y-2.5">
                      {res.steps.map((step, sidx) => (
                        <div key={sidx} className="flex items-start gap-3 text-sm">
                          <div className="flex flex-col items-center mt-1.5">
                             <div className="w-2 h-2 rounded-full" style={{ backgroundColor: step.route.color }}></div>
                             {sidx < res.steps.length - 1 && <div className="w-px h-6 bg-slate-200"></div>}
                          </div>
                          <div className="flex-1">
                            <p className="font-medium text-slate-800">YBS {step.route.id}</p>
                            <p className="text-slate-500 text-xs mt-0.5">{step.fromStop} → {step.toStop}</p>
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
          <div className="flex items-start gap-2">
             <div className="w-8 h-8 rounded-full bg-slate-900 flex items-center justify-center shrink-0">
               <Bot size={16} className="text-white" />
             </div>
             <div className="bg-white px-4 py-3 rounded-2xl rounded-bl-md border border-slate-100 flex items-center gap-1.5 shadow-sm">
                <div className="w-1.5 h-1.5 bg-slate-400 rounded-full animate-bounce"></div>
                <div className="w-1.5 h-1.5 bg-slate-400 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
                <div className="w-1.5 h-1.5 bg-slate-400 rounded-full animate-bounce [animation-delay:-0.3s]"></div>
             </div>
          </div>
        )}
        <div ref={chatEndRef}></div>
      </div>

      <div className="p-4 border-t border-slate-100 bg-white shrink-0 pb-20 md:pb-4">
        <div className="flex items-center gap-2">
          <input 
            type="text" 
            placeholder="ဥပမာ- ဆူးလေကနေ လှည်းတန်းကို ဘယ်လိုသွားရမလဲ"
            className="ui-input flex-1"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleSend()}
          />
          <button 
            onClick={handleSend}
            disabled={!input.trim() || isTyping}
            className="ui-btn ui-btn-primary p-3 rounded-xl disabled:opacity-50"
          >
            <Send size={18} />
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
    <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-8 overflow-hidden bg-slate-900/40 backdrop-blur-sm animate-fade-in">
      <div className="bg-white w-full h-full md:max-w-2xl md:h-auto md:max-h-[90vh] flex flex-col md:rounded-2xl md:shadow-lg overflow-hidden animate-slide-up">
        <div className="px-5 py-4 flex items-center justify-between border-b border-slate-100 shrink-0">
          <h3 className="text-base font-semibold truncate text-slate-900">{stop.name_mm}</h3>
          <button onClick={onClose} className="ui-btn-icon"><X size={18}/></button>
        </div>
        <div id="stop-map" className="w-full h-64 md:h-72 bg-slate-100 shrink-0"></div>
        <div className="p-5 flex-1 overflow-y-auto space-y-6 pb-24 md:pb-6">
          <div className="space-y-1">
            <p className="ui-label">တည်နေရာ</p>
            <p className="text-slate-800 font-medium">{stop.road_mm}၊ {stop.township_mm}</p>
          </div>
          <div className="space-y-3">
            <p className="ui-label">ဖြတ်သန်းသွားသော လိုင်းများ ({passingRoutes.length})</p>
            <div className="flex flex-wrap gap-2">
              {passingRoutes.map(r => (
                <div key={r.id} className="flex flex-col items-center gap-1.5 bg-slate-50 p-3 rounded-xl border border-slate-100 min-w-[72px]">
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
  return (
    <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-8 overflow-hidden bg-slate-900/40 backdrop-blur-sm animate-fade-in">
      <div className="bg-white w-full h-full md:max-w-2xl md:h-[90vh] flex flex-col md:rounded-2xl md:shadow-lg overflow-hidden animate-slide-up">
        <div className="px-5 py-4 flex items-center gap-3 border-b border-slate-100 shrink-0">
          <button onClick={onClose} className="ui-btn-icon"><ChevronRight className="rotate-180" size={18}/></button>
          <RouteBadge routeId={route.id} color={route.color} size="sm" />
          {route.operator && <OperatorBadge name={route.operator} />}
          <h3 className="font-semibold text-slate-800 text-sm">လမ်းကြောင်းအသေးစိတ်</h3>
        </div>
        
        <div className="p-5 flex-1 overflow-y-auto space-y-5 pb-24 md:pb-8">
           <div className="flex items-center justify-between pb-4 border-b border-slate-100">
             <div>
               <p className="ui-label">စုစုပေါင်းမှတ်တိုင်</p>
               <p className="text-2xl font-bold text-slate-900">{route.stops.length}</p>
             </div>
             <div className="flex flex-col items-end text-sm">
               <span className="text-slate-800 font-medium text-right">{route.stops[0]}</span>
               <div className="h-4 w-px bg-slate-200 my-1 mr-2"></div>
               <span className="text-slate-800 font-medium text-right">{route.stops[route.stops.length-1]}</span>
             </div>
           </div>
           
           <div className="space-y-1">
             <p className="ui-label mb-3">မှတ်တိုင်စာရင်း</p>
             <div>
               {route.stops.map((sName, idx) => (
                 <div 
                    key={idx} 
                    className="flex items-start gap-3 group cursor-pointer"
                    onClick={() => {
                       db.busStops.where('name_mm').equals(sName).first().then(s => s && onStopClick(s));
                    }}
                 >
                   <div className="flex flex-col items-center mt-2 shrink-0">
                      <div className={`w-2.5 h-2.5 rounded-full ${idx === 0 || idx === route.stops.length-1 ? 'ring-2 ring-offset-1 ring-slate-200' : ''}`} style={{ backgroundColor: route.color }}></div>
                      {idx < route.stops.length - 1 && <div className="w-px h-10 bg-slate-100"></div>}
                   </div>
                   <div className="pb-3 w-full group-hover:bg-slate-50 transition-colors rounded-lg px-2 -ml-1 flex items-center justify-between">
                     <span className="text-sm font-medium text-slate-700 group-hover:text-slate-900">{sName}</span>
                     <MapIcon size={14} className="text-slate-300 group-hover:text-brand opacity-0 group-hover:opacity-100 transition-all" />
                   </div>
                 </div>
               ))}
             </div>
           </div>
        </div>
      </div>
    </div>
  );
};

const StopsPage: React.FC<{ stops: BusStop[], onStopClick: (s: BusStop) => void }> = ({ stops, onStopClick }) => {
  const [search, setSearch] = useState('');
  const filtered = stops.filter(s => {
    const term = search.toLowerCase();
    return (
      s.name_mm.toLowerCase().includes(term) ||
      s.name_en.toLowerCase().includes(term) ||
      s.township_mm.toLowerCase().includes(term) ||
      s.township_en.toLowerCase().includes(term) ||
      s.road_mm.toLowerCase().includes(term) ||
      s.road_en.toLowerCase().includes(term)
    );
  });

  return (
    <div className="max-w-5xl mx-auto px-4 py-5 md:py-8 h-full flex flex-col gap-5">
      <div className="relative shrink-0 max-w-xl mx-auto w-full">
        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
        <input 
          type="text" 
          placeholder="မှတ်တိုင်ရှာရန်..." 
          className="ui-input pl-11"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      <div className="flex-1 overflow-y-auto pb-24 md:pb-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {filtered.map(s => (
            <div 
              key={s.id} 
              onClick={() => onStopClick(s)} 
              className="ui-card ui-card-interactive p-4 flex items-center justify-between cursor-pointer group"
            >
              <div className="flex items-center gap-3 min-w-0">
                <div className="bg-slate-100 p-2 rounded-xl text-slate-500 group-hover:bg-brand-light group-hover:text-brand transition-colors">
                  <MapPin size={18} />
                </div>
                <div className="min-w-0">
                  <p className="font-medium text-slate-800 truncate">{s.name_mm}</p>
                  <p className="text-xs text-slate-400">{s.township_mm}</p>
                </div>
              </div>
              <ChevronRight className="text-slate-300 group-hover:text-brand transition-colors shrink-0" size={18} />
            </div>
          ))}
          {filtered.length === 0 && (
             <div className="text-center py-16 text-slate-400 col-span-full">
               <MapPin size={32} className="mx-auto mb-3 opacity-30" />
               <p className="font-medium">မှတ်တိုင် မတွေ့ပါ</p>
             </div>
          )}
        </div>
      </div>
    </div>
  );
};

const FindRoutePage: React.FC<{ onRouteClick: (r: BusRoute) => void; routes: BusRoute[]; stops: BusStop[] }> = ({ onRouteClick, routes: routesProp, stops: stopsProp }) => {
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [locating, setLocating] = useState(false);
  const [mapPickerTarget, setMapPickerTarget] = useState<'start' | 'end' | null>(null);

  const stops = stopsProp;
  const routes = routesProp;


  const allStopNames = useMemo(() => {
    const names = new Set<string>();
    stops.forEach(s => names.add(s.name_mm));
    routes.forEach(r => r.stops.forEach(s => names.add(s)));
    return Array.from(names).sort((a, b) => a.localeCompare(b, 'my'));
  }, [stops, routes]);

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
    const found = await performBFS(sTerm, eTerm, routes, stops);
    setResults(found);
    setSearching(false);
  }, [start, end, routes, stops]);

  const handleSwap = () => {
    const temp = start;
    setStart(end);
    setEnd(temp);
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-5 md:py-8 h-full overflow-y-auto pb-24 md:pb-12 space-y-6">
      <div className="ui-card p-5 md:p-8 space-y-5 max-w-3xl mx-auto">
        <div className="space-y-4">
          <StopSearchInput 
            label="စတင်မည့်မှတ်တိုင်"
            value={start}
            onChange={setStart}
            allNames={allStopNames}
            placeholder="ရှာရန်..."
            indicatorColor="bg-emerald-500"
            icon={
              <div className="flex items-center gap-1.5">
                <button 
                  onClick={handleUseCurrentLocation}
                  disabled={locating}
                  className="ui-btn-ghost p-2 rounded-lg flex items-center gap-1.5 text-brand"
                >
                  {locating ? <RefreshCw className="animate-spin" size={14} /> : <Crosshair size={14} />}
                  <span className="text-xs font-medium">Near Me</span>
                </button>
                <button 
                  onClick={() => setMapPickerTarget('start')}
                  className="ui-btn-icon p-2"
                >
                  <MapIcon size={14} />
                </button>
              </div>
            }
          />

          <div className="flex justify-center -my-2 relative z-10">
            <button 
              onClick={handleSwap}
              className="ui-btn-icon bg-white"
            >
              <ArrowRightLeft size={18} className="rotate-90 md:rotate-0" />
            </button>
          </div>

          <StopSearchInput 
            label="ဆင်းမည့်မှတ်တိုင်"
            value={end}
            onChange={setEnd}
            allNames={allStopNames}
            placeholder="ရှာရန်..."
            indicatorColor="bg-rose-500"
            icon={
              <button 
                onClick={() => setMapPickerTarget('end')}
                className="ui-btn-icon p-2"
              >
                <MapIcon size={14} />
              </button>
            }
          />
        </div>

        <button 
          onClick={handleSearch}
          disabled={!start || !end || searching}
          className="ui-btn ui-btn-primary w-full py-3.5 text-base rounded-xl disabled:opacity-50"
        >
          {searching ? <RefreshCw className="animate-spin" size={20} /> : <Search size={20} />}
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

      <div className="space-y-4 max-w-4xl mx-auto">
        {results.length > 0 && results.map((res, i) => (
          <div key={i} className="ui-card p-5 space-y-4">
            <div className="flex items-center justify-between gap-3">
               <div className="flex items-center gap-2 overflow-x-auto pb-1 no-scrollbar">
                  {res.steps.map((step, idx) => (
                    <React.Fragment key={idx}>
                      <RouteBadge routeId={step.route.id} color={step.route.color} size="sm" onClick={() => onRouteClick(step.route)} />
                      {idx < res.steps.length - 1 && <ChevronRight size={14} className="text-slate-300 shrink-0" />}
                    </React.Fragment>
                  ))}
               </div>
               <span className={`ui-badge shrink-0 ${
                 res.transferCount === 0 ? 'bg-emerald-50 text-emerald-700' : 
                 res.transferCount === 1 ? 'bg-amber-50 text-amber-700' : 'bg-rose-50 text-rose-700'
               }`}>
                 {res.transferCount === 0 ? 'တိုက်ရိုက်' : `${res.transferCount} ဆင့်ပြောင်း`}
               </span>
            </div>

            <div className="space-y-3">
               {res.steps.map((step, idx) => (
                 <div key={idx} className="flex items-start gap-3">
                    <div className="flex flex-col items-center mt-1.5 shrink-0">
                       <div className="w-2 h-2 rounded-full" style={{ backgroundColor: step.route.color }}></div>
                       {idx < res.steps.length && <div className="w-px h-10 bg-slate-100"></div>}
                    </div>
                    <div className="flex-1">
                       <div className="text-sm font-medium text-slate-800 flex items-center gap-2">
                          <span className="ui-badge">စီးရန်</span>
                          <span>YBS {step.route.id}</span>
                          {step.route.operator && <OperatorBadge name={step.route.operator} />}
                       </div>
                       <p className="mt-1 text-xs text-slate-500">
                          <span className="text-brand font-medium">{step.fromStop}</span> မှ <span className="text-brand font-medium">{step.toStop}</span> အထိ
                       </p>
                    </div>
                 </div>
               ))}
            </div>
          </div>
        ))}

        {results.length === 0 && start && end && !searching && (
          <div className="text-center py-16 space-y-4">
            <div className="bg-slate-100 p-6 rounded-full w-20 h-20 flex items-center justify-center mx-auto">
               <Search size={32} className="text-slate-300" />
            </div>
            <div className="space-y-1">
              <p className="text-slate-500 font-semibold text-lg">လမ်းကြောင်း မတွေ့ပါ</p>
              <p className="text-slate-400 text-sm max-w-sm mx-auto">မှတ်တိုင်အမည် မှန်၊ မမှန် ပြန်စစ်ပေးပါ</p>
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
    
    // Load stops from route files
    const loadedStops = await loadStopsFromRouteFiles();
    await db.busStops.clear();
    await db.busStops.bulkAdd(loadedStops);
    
    // Load routes from JSON files
    const loadedRoutes = await loadRoutesFromFiles();
    await db.busRoutes.clear();
    await db.busRoutes.bulkAdd(loadedRoutes);
    
    setStatus('done');
    setTimeout(() => setStatus('idle'), 2000);
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-6 md:py-8 space-y-6 pb-24 md:pb-8">
      <div className="ui-card p-6">
        <div className="flex items-center gap-4 mb-5">
          <div className="bg-slate-900 p-3 rounded-xl text-white">
            <Info size={20} />
          </div>
          <div>
            <h3 className="font-semibold text-slate-900">Developer Info</h3>
            <p className="text-sm text-slate-500">ဆော့ဝဲရေးသားသူ အချက်အလက်</p>
          </div>
        </div>

        <div className="space-y-3">
          <div className="bg-slate-50 rounded-xl p-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="ui-label">App Name</p>
                <p className="font-semibold text-slate-800 mt-0.5">YBS Guide</p>
              </div>
              <div>
                <p className="ui-label">Version</p>
                <p className="font-semibold text-slate-800 mt-0.5">3.0</p>
              </div>
            </div>
          </div>

          <div className="bg-slate-50 rounded-xl p-4 space-y-3">
            <div>
              <p className="ui-label">Developer</p>
              <p className="font-semibold text-slate-800 mt-0.5">Arkar Yan</p>
              <p className="text-sm text-slate-500">Project Manager | Instructor</p>
            </div>

            <div className="pt-3 border-t border-slate-200 space-y-2">
              <p className="ui-label">Get In Touch</p>
              <p className="text-sm text-brand font-medium">info@arkaryan.net</p>
              <p className="text-sm text-slate-600">arkaryan.net</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [selectedRoute, setSelectedRoute] = useState<BusRoute | null>(null);
  const [selectedStop, setSelectedStop] = useState<BusStop | null>(null);

  const [stops, setStops] = useState<BusStop[]>([]);
  const [routes, setRoutes] = useState<BusRoute[]>([]);

  // routeId driven by URL to prevent blank detail pages
  const RouteDetailFromUrl: React.FC<{
    routes: BusRoute[];
    onClose: () => void;
    onStopClick: (s: BusStop) => void;
  }> = ({ routes, onClose, onStopClick }) => {
    const { routeId } = useParams<{ routeId: string }>();
    if (!routeId) return null;

    const r = routes.find((x) => x.id === routeId);
    if (!r) {
      return (
        <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-8 overflow-hidden bg-slate-900/40 backdrop-blur-sm animate-fade-in">
          <div className="bg-white w-full h-full md:max-w-2xl md:h-auto md:max-h-[90vh] flex flex-col md:rounded-2xl md:shadow-lg overflow-hidden">
            <div className="px-5 py-4 flex items-center justify-between border-b border-slate-100 shrink-0">
              <h3 className="font-semibold text-slate-900">Route not found</h3>
              <button onClick={onClose} className="ui-btn-icon">
                <X size={18} />
              </button>
            </div>
            <div className="p-6 text-slate-600">{routeId} ကိုဒေတာထဲမှာ ရှာမတွေ့ပါ။</div>
          </div>
        </div>
      );
    }

    return <RouteDetailPage route={r} onClose={onClose} onStopClick={onStopClick} />;
  };
  const [isInitializing, setIsInitializing] = useState(true);
  const [favorites, setFavorites] = useState<Set<string>>(new Set());

  useEffect(() => {
    const loadAll = async () => {
      const [loadedStops, loadedRoutes] = await Promise.all([
        loadStopsFromRouteFiles(),
        loadRoutesFromFiles(),
      ]);

      // ensure Dexie has data (RoutesPage relies on db.*)
      // Dexie stores can throw on duplicate primary keys; use bulkPut for idempotency.
      await db.busStops.clear();
      await db.busRoutes.clear();
      await db.busStops.bulkPut(loadedStops as any);
      await db.busRoutes.bulkPut(loadedRoutes as any);


      setStops(loadedStops);
      setRoutes(loadedRoutes);
      setIsInitializing(false);
    };
    loadAll();
  }, []);


  const navigateToRoute = useCallback((r: BusRoute) => {
    setSelectedRoute(r);
    navigate(`/route-detail/${encodeURIComponent(r.id)}`);
  }, [navigate]);

  const navigateToStop = useCallback((s: BusStop) => {
    setSelectedStop(s);
    navigate('/stop-detail');
  }, [navigate]);

  const toggleFavorite = useCallback((routeId: string) => {
    setFavorites(prev => {
      const newFavorites = new Set(prev);
      if (newFavorites.has(routeId)) {
        newFavorites.delete(routeId);
      } else {
        newFavorites.add(routeId);
      }
      localStorage.setItem('ybs-favorites', JSON.stringify(Array.from(newFavorites)));
      return newFavorites;
    });
  }, []);

  const renderRoutes = () => {
    if (isInitializing) {
      return (
        <div className="flex flex-col items-center justify-center h-full gap-4 py-20">
          <div className="bg-slate-100 p-4 rounded-2xl">
            <RefreshCw className="animate-spin text-slate-600" size={32} />
          </div>
          <p className="text-slate-500 font-medium">ဒေတာများ ပြင်ဆင်နေပါသည်...</p>
        </div>
      );
    }

    return (
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/routes" element={<RoutesPage onRouteClick={navigateToRoute} onStopClick={navigateToStop} favorites={favorites} onToggleFavorite={toggleFavorite} routes={routes} stops={stops} />} />
        <Route path="/map" element={<MapPage stops={stops} routes={routes} onStopClick={navigateToStop} />} />
        <Route path="/assistant" element={<AssistantPage onRouteClick={navigateToRoute} routes={routes} stops={stops} />} />
        <Route path="/find-route" element={<FindRoutePage onRouteClick={navigateToRoute} routes={routes} stops={stops} />} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/stops" element={<StopsPage stops={stops} onStopClick={navigateToStop} />} />
        <Route path="/route-detail/:routeId" element={<RouteDetailFromUrl routes={routes} onClose={() => navigate('/routes')} onStopClick={navigateToStop} />} />
        <Route path="/stop-detail" element={selectedStop ? <StopDetailPage stop={selectedStop} onClose={() => navigate(-1)} /> : null} />
      </Routes>
    );
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col overflow-x-hidden h-screen">
      <Header />

      <main className="flex-1 relative w-full overflow-hidden">
        <div className="absolute inset-0 overflow-y-auto">
           {renderRoutes()}
        </div>
      </main>

      <MobileBottomNav />
    </div>
  );
};

export default App;
