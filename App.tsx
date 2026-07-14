import React, { useState, useEffect, useCallback, useMemo, useRef, useLayoutEffect } from 'react';

import { Routes, Route, useNavigate, useLocation, useParams } from 'react-router-dom';
import { loadRoutesFromFiles, loadStopsFromRouteFiles, saveToLocalCache, loadFromLocalCache, clearLocalCache, CACHE_KEY, LocalCache } from './data_constants';
import { Page, BusStop, BusRoute } from './types';
import { db } from './db';
import {
  getUserId,
  connectUrl,
  getAlertStatus,
  setAlert,
  cancelAlert,
  type AlertStatus,
} from './telegramAlert';
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
  ArrowRight,
  CheckCircle2,
  Bell
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

interface StopOption {
  raw: string;
  display: string;
  id?: number; // Added to support unique identification
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

  const routeStopPositions = new Map<string, Map<string, number[]>>();
  allRoutes.forEach(r => {
    const idxMap = new Map<string, number[]>();
    r.stops.forEach((s, i) => {
      if (!idxMap.has(s)) idxMap.set(s, []);
      idxMap.get(s)!.push(i);
    });
    routeStopPositions.set(r.id, idxMap);
  });

  const queue: { currentStop: string; path: PathStep[]; usedRouteIds: Set<string> }[] = [
    { currentStop: start, path: [], usedRouteIds: new Set() }
  ];
  const visited = new Set<string>();
  const finalResults: SearchResult[] = [];
  const MAX_TRANSFERS = 2; // Reduced from 4 to 2 for better relevance and performance

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
    const { currentStop, path, usedRouteIds } = queue.shift()!;

    if (visited.has(currentStop)) continue;
    visited.add(currentStop);

    if (path.length > MAX_TRANSFERS + 1) continue;

    const availableRoutes = allRoutes.filter(r => r.stops.includes(currentStop));
    for (const route of availableRoutes) {
      if (usedRouteIds.has(route.id)) continue;

      const newUsedRouteIds = new Set(usedRouteIds);
      newUsedRouteIds.add(route.id);

      const positions = routeStopPositions.get(route.id)?.get(currentStop) || [];

      for (const pos of positions) {
        // Look ahead for the destination in the current route
        const destIdx = route.stops.indexOf(end, pos + 1);
        if (destIdx !== -1) {
          const stepPath = [...path, { route, fromStop: currentStop, toStop: end }];
          finalResults.push({ 
            steps: stepPath, 
            transferCount: stepPath.length - 1, 
            totalDistance: calculatePathDistance(stepPath) 
          });
          continue; // Found direct path in this route, no need to explore further for this route
        }

        // If not found, add potential transfer points (every 5th stop to keep search space manageable)
        if (path.length <= MAX_TRANSFERS) {
          for (let i = pos + 1; i < route.stops.length; i += 5) {
            const nextStop = route.stops[i];
            const stepPath = [...path, { route, fromStop: currentStop, toStop: nextStop }];
            queue.push({ currentStop: nextStop, path: stepPath, usedRouteIds: new Set(newUsedRouteIds) });
          }
        }
      }
    }
    if (finalResults.length >= 10) break;
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
  title: string,
  stopOptions?: StopOption[]
}> = ({ stops, onSelect, onClose, title, stopOptions }) => {
  const mapRef = useRef<any>(null);
  const markerLayerRef = useRef<any>(null);
  const radiusCircleRef = useRef<any>(null);
  const userMarkerRef = useRef<any>(null);
  const [isLocating, setIsLocating] = useState(false);
  const [nearbyStops, setNearbyStops] = useState<(BusStop & { distance: number })[]>([]);

  const stopDisplayMap = useMemo(() => {
    const map = new Map<string, string>();
    stopOptions?.forEach(o => map.set(o.raw, o.display));
    return map;
  }, [stopOptions]);

  const getStopDisplay = (rawName: string): string => {
    return stopDisplayMap.get(rawName) || rawName;
  };

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
          <b class="text-sm">${getStopDisplay(s.name_mm)}</b><br>
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
  }, [stops, onSelect, onClose, stopDisplayMap]);

  useEffect(() => {
    const L = (window as any).L;
    if (!L) return;

    const map = L.map('selection-map', { zoomControl: false, scrollWheelZoom: true, dragging: true, touchZoom: true, tap: false }).setView([16.8, 96.15], 14);
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

const buildDisambiguatedStops = (stops: BusStop[], routes: BusRoute[]): StopOption[] => {
  const seen = new Set<string>();
  const options: StopOption[] = [];

  stops.forEach(stop => {
    const road = stop.road_mm || stop.township_mm || '';
    const key = `${stop.name_mm}|${road}`;

    if (seen.has(key)) return;
    seen.add(key);

    const display = `${stop.name_mm} [${road}]`;
    options.push({ raw: stop.name_mm, display, id: stop.id });
  });

  return options.sort((a, b) => a.display.localeCompare(b.display));
};

const StopSearchInput: React.FC<{ 
  label: string, 
  value: string, 
  onChange: (v: string) => void, 
  allOptions: StopOption[],
  placeholder?: string,
  indicatorColor?: string,
  icon?: React.ReactNode
}> = ({ label, value, onChange, allOptions, placeholder, indicatorColor, icon }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [displayValue, setDisplayValue] = useState(value);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!value) setDisplayValue('');
    else {
      const opt = allOptions.find(o => o.raw === value);
      if (opt) setDisplayValue(opt.display);
      else setDisplayValue(value);
    }
  }, [value, allOptions]);

  const filtered = useMemo(() => {
    if (!displayValue) return [];
    const term = displayValue.toLowerCase();
    return allOptions.filter(o => 
      o.display.toLowerCase().includes(term) || 
      o.raw.toLowerCase().includes(term)
    ).slice(0, 50);
  }, [displayValue, allOptions]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <div className="space-y-2 relative" ref={containerRef}>
      <div className="flex items-center justify-between">
        <label className="text-xs font-semibold text-slate-500 uppercase tracking-wider">{label}</label>
        {icon}
      </div>
      <div className="relative">
        <div className={`absolute left-0 top-0 bottom-0 w-1 rounded-l-xl ${indicatorColor || 'bg-brand'}`}></div>
        <input 
          type="text"
          className="ui-input pl-5 pr-4 py-3.5 text-sm md:text-base bg-slate-50 border-transparent focus:bg-white focus:border-brand/20 transition-all"
          placeholder={placeholder}
          value={displayValue}
          onFocus={() => setIsOpen(true)}
          onChange={(e) => {
            setDisplayValue(e.target.value);
            setIsOpen(true);
            if (!e.target.value) onChange('');
          }}
        />
        {isOpen && filtered.length > 0 && (
          <div className="absolute top-full left-0 right-0 mt-1.5 bg-white border border-slate-200 rounded-xl shadow-lg z-[80] max-h-60 overflow-y-auto">
            {filtered.map((option, i) => (
              <div 
                key={i}
                className="px-4 py-3 hover:bg-slate-50 cursor-pointer text-sm text-slate-700 border-b border-slate-50 last:border-0"
                onClick={() => {
                  onChange(option.raw);
                  setDisplayValue(option.display);
                  setIsOpen(false);
                }}
              >
                {option.display}
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
    { id: '/stops', icon: MapPin, label: 'မှတ်တိုင်များ' },
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

const TelegramConnect: React.FC = () => {
  const [open, setOpen] = useState(false);
  const [status, setStatus] = useState<AlertStatus | null>(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const userId = useMemo(() => getUserId(), []);

  useEffect(() => {
    if (!open) return;
    getAlertStatus(userId)
      .then((s) => setStatus(s))
      .catch(() => setStatus({ linked: false, alert: null }));
  }, [open, userId]);

  return (
    <>
      <button onClick={() => setOpen(true)} className="ui-btn-ghost p-2 rounded-xl" title="Telegram ချိတ်ဆက်">
        <Bot size={20} />
      </button>

      {open && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm" onClick={() => setOpen(false)}>
          <div className="bg-white w-full max-w-md rounded-2xl p-5 space-y-4" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="text-base font-semibold text-slate-900 flex items-center gap-2">
                <Bot size={18} className="text-blue-600" /> Telegram ချိတ်ဆက်
              </h3>
              <button onClick={() => setOpen(false)} className="ui-btn-icon"><X size={18} /></button>
            </div>

            <p className="text-sm text-slate-600">မှတ်တိုင် နီးကပ်လျှင် သတိပေးခံရန် သင့် Telegram ကို ချိတ်ဆက်ပါ။</p>

            {status && status.alert ? (
              <div className="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-sm text-emerald-700 space-y-2">
                <p>🔔 <b>{status.alert.stopName}</b> မှတ်တိုင်သို့ ရောက်လျှင် သတိပေးပါမည်။</p>
                <p className="text-xs text-emerald-600">Bot သို့ Live Location ပို့ပေးပါ။</p>
                <button
                  onClick={async () => { await cancelAlert(userId); setStatus((s) => (s ? { ...s, alert: null } : s)); setMsg('🚫 သတိပေးချက် ပယ်ဖျက်ပြီးပါပြီ။'); }}
                  className="w-full ui-btn-ghost py-2 text-rose-600 border-rose-200 hover:bg-rose-50"
                >သတိပေးချက် ပယ်ဖျက်မည်</button>
              </div>
            ) : status && status.linked ? (
              <div className="bg-emerald-50 border border-emerald-100 rounded-xl p-3 text-sm text-emerald-700 space-y-1.5">
                <p>✅ ချိတ်ဆက်ပြီးပါပြီ။ မှတ်တိုင်တစ်ခုချက် ဖွင့်ပြီး "သတိပေးပါ" ကို နှိပ်ပါ။</p>
              </div>
            ) : (
              <div className="space-y-3">
                <a
                  href={connectUrl(userId)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-center gap-2 w-full py-2.5 px-4 bg-[#26A5E4] hover:bg-[#2297cc] text-white font-medium rounded-xl text-sm"
                >
                  <Send size={16} /> Telegram နဲ့ ချိတ်ဆက်မည်
                </a>
                <div className="bg-white rounded-xl border border-slate-200 p-3 space-y-1.5">
                  <p className="text-[11px] text-slate-500 leading-relaxed">
                    Bot ကို အရင် ဖွင့်ထားပြီးသားဆိုရင် Link နှိပ်ပြီးနောက် Bot ထဲမှာ အောက်ပါ ကုဒ်ကို တိုက်ရိုက် ပို့ပါ (သို့မဟုတ် <code className="bg-slate-100 px-1 rounded">/start {userId}</code>):
                  </p>
                  <div className="flex items-center justify-between gap-2 bg-slate-50 rounded-lg px-3 py-2">
                    <span className="font-mono font-semibold tracking-widest text-slate-800 select-all">{userId}</span>
                    <button type="button" onClick={() => navigator.clipboard?.writeText(userId)} className="text-xs font-medium text-blue-600 hover:text-blue-700">ကူးယူ</button>
                  </div>
                </div>
              </div>
            )}

            {msg && <p className="text-xs text-center text-slate-600">{msg}</p>}
          </div>
        </div>
      )}
    </>
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
            <span className="text-[10px] font-semibold text-slate-400 bg-slate-100 px-1.5 py-0.5 rounded">3.1</span>
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

        <TelegramConnect />
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
    { path: '/stops', icon: MapPin, label: 'မှတ်တိုင်များ', color: 'bg-emerald-600' },
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

    const term = search.toLowerCase().trim();
    if (term) {
      result = result.filter(r => {
        const startStop = r.stops[0];
        const endStop = r.stops[r.stops.length - 1];
        const startTownship = stopInfoMap.get(startStop)?.township || "";
        const endTownship = stopInfoMap.get(endStop)?.township || "";
        const startStopEn = stopInfoMap.get(startStop)?.name_en || "";
        const endStopEn = stopInfoMap.get(endStop)?.name_en || "";

        if (r.id.toLowerCase().includes(term)) return true;
        if (r.operator && r.operator.toLowerCase().includes(term)) return true;
        if (startStop && startStop.toLowerCase().includes(term)) return true;
        if (endStop && endStop.toLowerCase().includes(term)) return true;
        if (startTownship.toLowerCase().includes(term)) return true;
        if (endTownship.toLowerCase().includes(term)) return true;
        if (startStopEn.toLowerCase().includes(term)) return true;
        if (endStopEn.toLowerCase().includes(term)) return true;
        return false;
      });
    }

    return result.sort((a, b) => {
      const isAFav = favorites.has(a.id);
      const isBFav = favorites.has(b.id);
      if (isAFav && !isBFav) return -1;
      if (!isAFav && isBFav) return 1;
      
      const aNum = parseInt(a.id.replace(/\D/g, '')) || 999;
      const bNum = parseInt(b.id.replace(/\D/g, '')) || 999;
      return aNum - bNum;
    });
  }, [routes, search, favorites, stopInfoMap]);

  return (
    <div className="max-w-5xl mx-auto px-4 py-5 md:py-8 h-full flex flex-col gap-5">
      <div className="relative shrink-0 max-w-xl mx-auto w-full">
        <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
        <input 
          type="text" 
          placeholder="ကားလိုင်းနံပါတ် သို့မဟုတ် မြို့နယ်ဖြင့်ရှာရန်..." 
          className="ui-input pl-11"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="flex-1 overflow-y-auto pb-24 md:pb-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {filtered.map(r => {
            const isFav = favorites.has(r.id);
            const startStop = r.stops[0];
            const endStop = r.stops[r.stops.length - 1];
            return (
              <div 
                key={r.id} 
                onClick={() => onRouteClick(r)}
                className="ui-card ui-card-interactive p-4 flex flex-col gap-4 group"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <RouteBadge routeId={r.id} color={r.color} />
                    <div>
                      <p className="text-xs text-slate-400 font-medium">YBS Route</p>
                      {r.operator && <OperatorBadge name={r.operator} />}
                    </div>
                  </div>
                  <button 
                    onClick={(e) => { e.stopPropagation(); onToggleFavorite(r.id); }}
                    className={`p-2 rounded-lg transition-colors ${isFav ? 'text-amber-500 bg-amber-50' : 'text-slate-300 hover:text-slate-400 hover:bg-slate-50'}`}
                  >
                    <Star size={18} fill={isFav ? 'currentColor' : 'none'} />
                  </button>
                </div>

                <div className="space-y-2">
                  <div className="flex items-center gap-3">
                    <div className="w-1.5 h-1.5 rounded-full bg-slate-300 shrink-0"></div>
                    <p className="text-sm text-slate-700 truncate font-medium">{startStop}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="w-1.5 h-1.5 rounded-full bg-brand shrink-0"></div>
                    <p className="text-sm text-slate-700 truncate font-medium">{endStop}</p>
                  </div>
                </div>

                <div className="pt-3 border-t border-slate-50 flex items-center justify-between">
                  <span className="text-[10px] text-slate-400 font-medium">{r.stops.length} Stops</span>
                  <div className="flex items-center gap-1 text-brand text-xs font-semibold opacity-0 group-hover:opacity-100 transition-opacity">
                    View Detail <ChevronRight size={14} />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

const RouteDetailPage: React.FC<{ 
  route: BusRoute, 
  onClose: () => void,
  onStopClick: (s: BusStop) => void 
}> = ({ route, onClose, onStopClick }) => {
  const mapRef = useRef<any>(null);
  const markersLayerRef = useRef<any>(null);
  const routeLayerRef = useRef<any>(null);
  const [livePos, setLivePos] = useState<{ lat: number, lng: number } | null>(null);
  const [isLocating, setIsLocating] = useState(false);

  const routeStops = route.stopsDetailed || [];

  const activeIndex = useMemo(() => {
    if (!livePos || routeStops.length === 0) return -1;
    let minIdx = 0;
    let minDist = getDistance(livePos.lat, livePos.lng, routeStops[0].lat, routeStops[0].lng);
    routeStops.forEach((s, i) => {
      const d = getDistance(livePos.lat, livePos.lng, s.lat, s.lng);
      if (d < minDist) {
        minDist = d;
        minIdx = i;
      }
    });
    return minDist < 0.5 ? minIdx : -1;
  }, [livePos, routeStops]);

  useEffect(() => {
    const L = (window as any).L;
    if (!L) return;

    const map = L.map('route-map', { zoomControl: false, scrollWheelZoom: true, dragging: true, touchZoom: true, tap: false }).setView([16.8, 96.15], 12);
    mapRef.current = map;
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
    L.control.zoom({ position: 'topright' }).addTo(map);

    markersLayerRef.current = L.featureGroup().addTo(map);
    routeLayerRef.current = L.featureGroup().addTo(map);

    if (routeStops.length > 0) {
      const latlngs: [number, number][] = routeStops.map(s => [s.lat, s.lng]);
      
      const polyline = L.polyline(latlngs, {
        color: route.color,
        weight: 5,
        opacity: 0.8,
        lineJoin: 'round'
      }).addTo(routeLayerRef.current);

      routeStops.forEach((s, i) => {
        const isStart = i === 0;
        const isEnd = i === routeStops.length - 1;
        
        const marker = L.circleMarker([s.lat, s.lng], {
          radius: isStart || isEnd ? 8 : 5,
          fillColor: isStart ? '#10b981' : isEnd ? '#f43f5e' : '#fff',
          color: isStart || isEnd ? '#fff' : route.color,
          weight: 2,
          opacity: 1,
          fillOpacity: 1
        });

        marker.bindTooltip(s.name_mm, { 
          direction: 'top', 
          offset: [0, -5],
          className: 'ui-map-tooltip'
        });

        marker.on('click', () => onStopClick(s));
        marker.addTo(markersLayerRef.current);
      });

      map.fitBounds(polyline.getBounds(), { padding: [40, 40] });
    }

    return () => map.remove();
  }, [route, routeStops, onStopClick]);

  return (
    <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-6 overflow-hidden bg-slate-900/40 backdrop-blur-sm animate-fade-in">
      <div className="bg-white w-full h-full md:max-w-3xl md:h-auto md:max-h-[95vh] flex flex-col md:rounded-2xl md:shadow-lg overflow-hidden">
        <div className="px-5 py-4 flex items-center justify-between border-b border-slate-100 shrink-0">
          <div className="flex items-center gap-3">
            <RouteBadge routeId={route.id} color={route.color} size="sm" />
            <div>
              <h3 className="font-semibold text-slate-900 text-sm">{route.line_name || `YBS ${route.id}`}</h3>
              <p className="text-[10px] text-slate-400 font-medium">{route.operator}</p>
            </div>
          </div>
          <button onClick={onClose} className="ui-btn-icon">
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 flex flex-col md:flex-row overflow-hidden">
          <div className="relative h-48 md:h-auto md:w-1/2 bg-slate-100 shrink-0">
            <div id="route-map" className="w-full h-full"></div>
            <div className="absolute bottom-4 right-4 z-[1000] flex flex-col gap-2">
              <button 
                onClick={() => {
                  setIsLocating(true);
                  navigator.geolocation.getCurrentPosition(
                    (p) => setLivePos({ lat: p.coords.latitude, lng: p.coords.longitude }),
                    () => setIsLocating(false),
                    { enableHighAccuracy: true, timeout: 10000 }
                  );
                }}
                disabled={isLocating}
                className="ui-btn-icon bg-white/90 backdrop-blur"
              >
                {isLocating ? <RefreshCw className="animate-spin" size={20} /> : <Locate size={20} />}
              </button>
            </div>
          </div>

          <div className="border-t border-slate-100 flex-1 overflow-y-auto bg-white">
            <div className="p-5 space-y-4 pb-24 md:pb-6">
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <div>
                  <p className="ui-label">စုစုပေါင်းမှတ်တိုင်</p>
                  <p className="text-2xl font-bold text-slate-900">{routeStops.length}</p>
                </div>
                <div className="flex flex-col items-end text-sm">
                  <span className="text-slate-800 font-medium text-right">{routeStops[0]?.name_mm || '—'}</span>
                  <div className="h-4 w-px bg-slate-200 my-1 mr-2"></div>
                  <span className="text-slate-800 font-medium text-right">{routeStops[routeStops.length - 1]?.name_mm || '—'}</span>
                </div>
              </div>

              <div className="space-y-2">
                <p className="ui-label">မှတ်တိုင်များ ({routeStops.length})</p>

                {routeStops.length === 0 ? (
                  <div className="text-center py-10 text-slate-400">
                    ဒေတာမတွေ့သေးပါ။
                  </div>
                ) : (
                  <div className="space-y-1.5">
                    {routeStops.map((s, idx) => {
                      const isActive = idx === activeIndex;
                      const isPassed = idx < activeIndex;
                      return (
                        <div
                          key={s.id}
                          className={`flex items-start gap-3 p-3 rounded-xl border transition-colors ${
                            isActive
                              ? 'border-emerald-300 bg-emerald-50/80'
                              : isPassed
                                ? 'border-slate-100 bg-slate-50/50'
                                : 'border-slate-100 bg-white'
                          }`}
                          onClick={() => onStopClick(s)}
                          style={{ cursor: 'pointer' }}
                        >
                          <div className="flex flex-col items-center mt-1 shrink-0">
                            <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                              isActive
                                ? 'bg-emerald-600 text-white'
                                : isPassed
                                  ? 'bg-slate-200 text-slate-500'
                                  : 'bg-slate-100 text-slate-400'
                            }`}>
                              {idx + 1}
                            </div>
                            {idx < routeStops.length - 1 && (
                              <div className={`w-px h-6 ${isPassed ? 'bg-slate-200' : 'bg-slate-100'}`} />
                            )}
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between gap-3">
                              <div className="min-w-0">
                                <div className={`text-sm font-semibold truncate ${isActive ? 'text-emerald-800' : 'text-slate-800'}`}>{s.name_mm}</div>
                                <div className="text-xs text-slate-400 truncate">{s.township_mm}</div>
                              </div>
                              {isActive && (
                                <div className="shrink-0">
                                  <span className="ui-badge bg-emerald-100 text-emerald-700 border-emerald-200">လက်ရှိ</span>
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              <div className="text-xs text-slate-400">
                Live location အတွက် browser location permission ကို allow လုပ်ထားရပါမည်။
              </div>
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

const RoutePlanDetailFromState: React.FC = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const state = (location.state || {}) as any;
  const steps = (state.steps || []) as PathStep[];

  if (!steps || steps.length === 0) {
    return (
      <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-6 overflow-hidden bg-slate-900/40 backdrop-blur-sm animate-fade-in">
        <div className="bg-white w-full h-full md:max-w-3xl md:h-auto md:max-h-[95vh] flex flex-col md:rounded-2xl md:shadow-lg overflow-hidden">
          <div className="px-5 py-4 flex items-center justify-between border-b border-slate-100 shrink-0">
            <h3 className="font-semibold text-slate-900">Route plan မရှိပါ</h3>
            <button onClick={() => navigate(-1)} className="ui-btn-icon">
              <X size={18} />
            </button>
          </div>
          <div className="p-6 text-slate-600">Result card ကိုနှိပ်ပြီးမှ plan detail ဖွင့်ပါ။</div>
        </div>
      </div>
    );
  }

  return <RoutePlanDetailPage onClose={() => navigate(-1)} steps={steps} />;
};

const RoutePlanDetailPage: React.FC<{
  onClose: () => void;
  steps: PathStep[];
}> = ({ onClose, steps }) => {
  const mapRef = useRef<any>(null);
  const markersLayerRef = useRef<any>(null);
  const routeLayerRef = useRef<any>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const stepRefs = useRef<Map<number, HTMLDivElement>>(new Map());

  const setStepRef = (idx: number) => (el: HTMLDivElement | null) => {
    if (el) stepRefs.current.set(idx, el);
    else stepRefs.current.delete(idx);
  };

  const [activeStepIndex, setActiveStepIndex] = useState(0);
  const [livePos, setLivePos] = useState<{ lat: number; lng: number } | null>(null);

  // Telegram Alert States
  const userId = useMemo(() => getUserId(), []);
  const [alertLoading, setAlertLoading] = useState(false);
  const [activeAlertStop, setActiveAlertStop] = useState<string | null>(null);

  useEffect(() => {
    getAlertStatus(userId).then(s => {
      if (s.alert) setActiveAlertStop(s.alert.stopName);
    });
  }, [userId]);

  const handleToggleAlert = async (stopName: string) => {
    setAlertLoading(true);
    try {
      if (activeAlertStop === stopName) {
        await cancelAlert(userId);
        setActiveAlertStop(null);
      } else {
        const ok = await setAlert(userId, stopName);
        if (ok) setActiveAlertStop(stopName);
        else alert("Telegram ကို အရင်ချိတ်ဆက်ပေးပါ။ Settings ထဲတွင် ချိတ်ဆက်နိုင်ပါသည်။");
      }
    } catch (e) {
      console.error(e);
    } finally {
      setAlertLoading(false);
    }
  };

  const stopsByName = useMemo(() => {
    const m = new Map<string, BusStop>();
    steps.forEach((st) => {
      const detailed = st.route.stopsDetailed || [];
      detailed.forEach((s) => {
        if (!m.has(s.name_mm)) {
          m.set(s.name_mm, {
            id: s.id,
            lat: s.lat,
            lng: s.lng,
            name_en: s.name_en,
            name_mm: s.name_mm,
            road_en: s.road_en,
            road_mm: s.road_mm,
            township_en: s.township_en,
            township_mm: s.township_mm,
          });
        }
      });
    });
    return m;
  }, [steps]);

  const resolveStop = (stopName: string): BusStop | null => {
    const found = stopsByName.get(stopName);
    if (!found) return null;
    return found;
  };

  useEffect(() => {
    if (!navigator.geolocation) return;
    let watchId: number | null = null;

    const startWatch = () => {
      if (watchId !== null) return;
      watchId = navigator.geolocation.watchPosition(
        (pos) => {
          setLivePos({ lat: pos.coords.latitude, lng: pos.coords.longitude });
        },
        () => {},
        { enableHighAccuracy: true, maximumAge: 1000, timeout: 10000 }
      );
    };

    startWatch();

    return () => {
      try {
        if (watchId !== null) navigator.geolocation.clearWatch(watchId);
      } catch {}
    };
  }, []);

  useEffect(() => {
    if (!livePos || steps.length === 0) return;

    let bestIdx = 0;
    let bestDist = Infinity;

    steps.forEach((st, idx) => {
      const fromStop = resolveStop(st.fromStop);
      const toStop = resolveStop(st.toStop);
      if (!fromStop || !toStop) return;

      const distFrom = getDistance(livePos.lat, livePos.lng, fromStop.lat, fromStop.lng);
      const distTo = getDistance(livePos.lat, livePos.lng, toStop.lat, toStop.lng);
      const minDist = Math.min(distFrom, distTo);

      if (minDist < bestDist) {
        bestDist = minDist;
        bestIdx = idx;
      }
    });

    setActiveStepIndex(bestIdx);
  }, [livePos, steps, stopsByName]);

  useEffect(() => {
    const el = stepRefs.current.get(activeStepIndex);
    const container = listRef.current;
    if (!el || !container) return;
    const raf = requestAnimationFrame(() => {
      const cRect = container.getBoundingClientRect();
      const eRect = el.getBoundingClientRect();
      const offset = eRect.top - cRect.top + container.scrollTop - cRect.height / 2 + eRect.height / 2;
      container.scrollTo({ top: Math.max(0, offset), behavior: 'smooth' });
    });
    return () => cancelAnimationFrame(raf);
  }, [activeStepIndex]);

  useEffect(() => {
    const L = (window as any).L;
    if (!L || mapRef.current) return;

    const map = L.map('route-plan-map', { zoomControl: false, scrollWheelZoom: true, dragging: true, touchZoom: true, tap: false }).setView([16.8, 96.15], 13);
    mapRef.current = map;

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
    L.control.zoom({ position: 'topright' }).addTo(map);

    markersLayerRef.current = L.featureGroup().addTo(map);
    routeLayerRef.current = L.featureGroup().addTo(map);

    setTimeout(() => {
      try {
        map.invalidateSize();
      } catch {}
    }, 200);

    return () => {
      try {
        map.remove();
      } catch {}
      mapRef.current = null;
    };
  }, []);

   useEffect(() => {
    const L = (window as any).L;
    const map = mapRef.current;
    if (!L || !map || !markersLayerRef.current || !routeLayerRef.current) return;

    markersLayerRef.current.clearLayers();
    routeLayerRef.current.clearLayers();

    const active = steps[activeStepIndex];
    if (!active) return;

    const route = active.route;

    const fromStop = resolveStop(active.fromStop);
    const toStop = resolveStop(active.toStop);

    const detailed = route.stopsDetailed || [];
    const fromIdx = detailed.findIndex(s => s.name_mm === active.fromStop);
    const toIdx = detailed.findIndex(s => s.name_mm === active.toStop);

    const allLatLngs: [number, number][] = [];

    const visibleStops = fromIdx >= 0 && toIdx >= 0 && fromIdx < toIdx
      ? detailed.slice(fromIdx, toIdx + 1)
      : detailed;

    visibleStops.forEach((s) => {
      const isBoard = s.name_mm === active.fromStop;
      const isAlight = s.name_mm === active.toStop;

      if (isBoard || isAlight) return;

      const marker = L.circleMarker([s.lat, s.lng], {
        radius: 6,
        fillColor: '#ffffff',
        color: '#000000',
        weight: 2,
        opacity: 1,
        fillOpacity: 1,
      });
      marker.bindTooltip(s.name_mm, {
        permanent: true,
        direction: 'top',
        offset: [0, -10],
        className: 'text-[10px] font-bold text-black bg-white px-1.5 py-0.5 rounded border border-black',
      });
      marker.addTo(markersLayerRef.current);
      allLatLngs.push([s.lat, s.lng]);
    });

    if (fromStop) {
      const marker = L.circleMarker([fromStop.lat, fromStop.lng], {
        radius: 10,
        fillColor: '#10b981',
        color: '#fff',
        weight: 3,
        opacity: 1,
        fillOpacity: 1,
      });
      marker.bindTooltip(`စီးရန်: ${fromStop.name_mm}`, {
        permanent: true,
        direction: 'top',
        offset: [0, -12],
        className: 'text-[11px] font-bold text-white bg-emerald-600 px-2 py-1 rounded shadow-md border-none',
      });
      marker.addTo(markersLayerRef.current);
      allLatLngs.push([fromStop.lat, fromStop.lng]);
    }

    if (toStop) {
      const marker = L.circleMarker([toStop.lat, toStop.lng], {
        radius: 10,
        fillColor: '#f43f5e',
        color: '#fff',
        weight: 3,
        opacity: 1,
        fillOpacity: 1,
      });
      marker.bindTooltip(`ဆင်းရန်: ${toStop.name_mm}`, {
        permanent: true,
        direction: 'top',
        offset: [0, -12],
        className: 'text-[11px] font-bold text-white bg-rose-600 px-2 py-1 rounded shadow-md border-none',
      });
      marker.addTo(markersLayerRef.current);
      allLatLngs.push([toStop.lat, toStop.lng]);
    }

    if (visibleStops.length > 1) {
      const line = L.polyline(visibleStops.map(s => [s.lat, s.lng]), {
        color: route.color,
        weight: 6,
        opacity: 0.8,
      }).addTo(routeLayerRef.current);
      map.fitBounds(line.getBounds(), { padding: [50, 50] });
    } else if (allLatLngs.length > 0) {
      map.fitBounds(L.latLngBounds(allLatLngs), { padding: [50, 50] });
    }
  }, [activeStepIndex, steps, stopsByName]);

  return (
    <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-6 overflow-hidden bg-slate-900/40 backdrop-blur-sm animate-fade-in">
      <div className="bg-white w-full h-full md:max-w-3xl md:h-auto md:max-h-[95vh] flex flex-col md:rounded-2xl md:shadow-lg overflow-hidden">
        <div className="px-5 py-4 flex items-center justify-between border-b border-slate-100 shrink-0">
          <div className="flex items-center gap-3">
            <div className="bg-slate-900 p-2 rounded-xl text-white">
              <Navigation size={18} />
            </div>
            <div>
              <h3 className="font-semibold text-slate-900">Route Plan Detail</h3>
              <p className="text-[10px] text-slate-400 font-medium">{steps.length - 1} Transfers</p>
            </div>
          </div>
          <button onClick={onClose} className="ui-btn-icon">
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 flex flex-col md:flex-row overflow-hidden">
          <div className="relative h-[40vh] md:h-auto md:w-1/2 bg-slate-100 shrink-0">
            <div id="route-plan-map" className="w-full h-full"></div>
            {livePos && (
               <div className="absolute top-4 left-4 z-[1000]">
                  <span className="ui-badge bg-white/90 backdrop-blur text-emerald-600 font-bold border-emerald-100">Live GPS Active</span>
               </div>
            )}
          </div>

          <div ref={listRef} className="border-t border-slate-100 flex-1 overflow-y-auto bg-slate-50/50">
            <div className="p-5 space-y-4 pb-24 md:pb-6">
              {steps.map((st, idx) => {
                const isActive = idx === activeStepIndex;
                return (
                  <div
                    key={idx}
                    ref={setStepRef(idx)}
                    className={`ui-card p-4 transition-all border ${
                      isActive ? 'border-brand bg-white shadow-md ring-1 ring-brand/10' : 'border-slate-100 bg-white/60 opacity-80'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-3">
                       <div className="flex items-center gap-2">
                          <RouteBadge routeId={st.route.id} color={st.route.color} size="sm" />
                          <span className="text-xs font-bold text-slate-800">YBS {st.route.id}</span>
                       </div>
                       {isActive && <span className="ui-badge bg-brand-light text-brand">လက်ရှိစီးရမည့်ကား</span>}
                    </div>

                    <div className="space-y-4 relative">
                       <div className="absolute left-[7px] top-2 bottom-2 w-px bg-slate-200"></div>
                       
                       <div className="flex items-start gap-3 relative z-10">
                          <div className="w-4 h-4 rounded-full bg-emerald-500 border-2 border-white shadow-sm mt-0.5"></div>
                          <div className="min-w-0">
                             <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Boarding</p>
                             <p className="text-sm font-semibold text-slate-900 truncate">{st.fromStop}</p>
                          </div>
                       </div>

                       <div className="flex items-start gap-3 relative z-10">
                          <div className="w-4 h-4 rounded-full bg-rose-500 border-2 border-white shadow-sm mt-0.5"></div>
                          <div className="flex-1 min-w-0">
                             <div className="flex items-center justify-between gap-2">
                                <div className="min-w-0">
                                   <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Alighting</p>
                                   <p className="text-sm font-semibold text-slate-900 truncate">{st.toStop}</p>
                                </div>
                                <button 
                                  onClick={(e) => { e.stopPropagation(); handleToggleAlert(st.toStop); }}
                                  disabled={alertLoading}
                                  className={`p-2 rounded-lg transition-colors shrink-0 ${activeAlertStop === st.toStop ? 'text-emerald-500 bg-emerald-50' : 'text-slate-300 hover:text-slate-400 hover:bg-slate-50'}`}
                                  title="ရောက်ခါနီး သတိပေးချက်"
                                >
                                  {alertLoading && activeAlertStop !== st.toStop ? <RefreshCw size={14} className="animate-spin" /> : <Bell size={14} fill={activeAlertStop === st.toStop ? 'currentColor' : 'none'} />}
                                </button>
                             </div>
                          </div>
                       </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const StopDetailPage: React.FC<{ 
  stop: BusStop, 
  onClose: () => void, 
  onRouteClick: (r: BusRoute) => void,
  favorites: Set<string>,
  onToggleFavorite: (stopId: number) => void,
  routes: BusRoute[]
}> = ({ stop, onClose, onRouteClick, favorites, onToggleFavorite, routes }) => {
  const isFav = favorites.has(stop.id.toString());
  const passingRoutes = routes.filter(r => r.stops.includes(stop.name_mm));

  const mapRef = useRef<any>(null);

  useEffect(() => {
    const L = (window as any).L;
    if (!L) return;

    const map = L.map('stop-map', { zoomControl: false, scrollWheelZoom: true, dragging: true, touchZoom: true, tap: false }).setView([stop.lat, stop.lng], 16);
    mapRef.current = map;
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
    L.control.zoom({ position: 'topright' }).addTo(map);

    L.circleMarker([stop.lat, stop.lng], {
      radius: 10,
      fillColor: "#2563eb",
      color: "#fff",
      weight: 3,
      opacity: 1,
      fillOpacity: 1
    }).addTo(map).bindPopup(stop.name_mm).openPopup();

    return () => map.remove();
  }, [stop]);

  const userId = useMemo(() => getUserId(), []);
  const [alertLoading, setAlertLoading] = useState(false);
  const [alertActive, setAlertActive] = useState(false);

  useEffect(() => {
    getAlertStatus(userId).then(s => {
      if (s.alert && s.alert.stopName === stop.name_mm) setAlertActive(true);
    });
  }, [userId, stop.name_mm]);

  const handleAlert = async () => {
    setAlertLoading(true);
    try {
      if (alertActive) {
        await cancelAlert(userId);
        setAlertActive(false);
      } else {
        const ok = await setAlert(userId, stop.name_mm);
        if (ok) setAlertActive(true);
        else alert("Telegram ကို အရင်ချိတ်ဆက်ပေးပါ။ Settings ထဲတွင် ချိတ်ဆက်နိုင်ပါသည်။");
      }
    } catch (e) {
      console.error(e);
    } finally {
      setAlertLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[60] flex md:items-center justify-center md:p-6 overflow-hidden bg-slate-900/40 backdrop-blur-sm animate-fade-in">
      <div className="bg-white w-full h-full md:max-w-2xl md:h-auto md:max-h-[90vh] flex flex-col md:rounded-2xl md:shadow-lg overflow-hidden">
        <div className="px-5 py-4 flex items-center justify-between border-b border-slate-100 shrink-0">
          <div className="flex items-center gap-3">
            <div className="bg-slate-100 p-2 rounded-xl text-slate-500">
              <MapPin size={18} />
            </div>
            <div>
              <h3 className="font-semibold text-slate-900 text-sm">{stop.name_mm}</h3>
              <p className="text-[10px] text-slate-400 font-medium uppercase tracking-wider">{stop.township_mm}</p>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <button 
              onClick={handleAlert}
              disabled={alertLoading}
              className={`ui-btn-icon ${alertActive ? 'text-emerald-500 bg-emerald-50' : 'text-slate-400'}`}
              title="ရောက်ခါနီး သတိပေးချက်"
            >
              {alertLoading ? <RefreshCw size={18} className="animate-spin" /> : <Bell size={18} fill={alertActive ? 'currentColor' : 'none'} />}
            </button>
            <button onClick={onClose} className="ui-btn-icon">
              <X size={18} />
            </button>
          </div>
        </div>

        <div className="flex-1 flex flex-col overflow-hidden">
          <div className="relative h-48 md:h-64 bg-slate-100 shrink-0">
            <div id="stop-map" className="w-full h-full"></div>
          </div>

          <div className="flex-1 overflow-y-auto p-5 space-y-6 bg-slate-50/50">
             <div className="grid grid-cols-2 gap-3">
                <div className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm">
                   <p className="ui-label">မြို့နယ်</p>
                   <p className="text-sm font-semibold text-slate-800 mt-1">{stop.township_mm}</p>
                </div>
                <div className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm">
                   <p className="ui-label">လမ်း</p>
                   <p className="text-sm font-semibold text-slate-800 mt-1">{stop.road_mm || '—'}</p>
                </div>
             </div>

             <div className="space-y-3">
                <div className="flex items-center justify-between">
                   <h4 className="ui-section-title">ဖြတ်သန်းသွားသော ကားလိုင်းများ</h4>
                   <span className="ui-badge">{passingRoutes.length} လိုင်း</span>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                   {passingRoutes.map(r => (
                     <div 
                        key={r.id} 
                        onClick={() => onRouteClick(r)}
                        className="bg-white p-3 rounded-xl border border-slate-100 flex items-center gap-3 cursor-pointer hover:border-brand/30 hover:shadow-sm transition-all group"
                     >
                        <RouteBadge routeId={r.id} color={r.color} size="sm" />
                        <span className="text-xs font-bold text-slate-700 group-hover:text-brand">YBS {r.id}</span>
                     </div>
                   ))}
                </div>
             </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const FindRoutePage: React.FC<{ 
  routes: BusRoute[], 
  stops: BusStop[],
  onRouteClick: (r: BusRoute) => void
}> = ({ routes: routesProp, stops: stopsProp, onRouteClick }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [locating, setLocating] = useState(false);
  const [mapPickerTarget, setMapPickerTarget] = useState<'start' | 'end' | null>(null);

  const stops = stopsProp;
  const routes = routesProp;

  const stopOptions = useMemo(() => buildDisambiguatedStops(stops, routes), [stops, routes]);

  const stopDetailsByName = useMemo(() => {
    const m = new Map<string, BusStop>();
    stops.forEach(s => {
      if (!m.has(s.name_mm)) m.set(s.name_mm, s);
    });
    return m;
  }, [stops]);

  const duplicateStopNames = useMemo(() => {
    const count = new Map<string, number>();
    stops.forEach(s => {
      count.set(s.name_mm, (count.get(s.name_mm) || 0) + 1);
    });
    const dupes = new Set<string>();
    count.forEach((c, name) => {
      if (c > 1) dupes.add(name);
    });
    return dupes;
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
            allOptions={stopOptions}
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
            allOptions={stopOptions}
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
          stopOptions={stopOptions}
        />
      )}

      <div className="space-y-4 max-w-4xl mx-auto">
        {results.length > 0 && results.map((res, i) => (
          <div
            key={i}
            className="ui-card p-5 space-y-4 cursor-pointer"
            onClick={() => navigate('/route-plan-detail', { state: { steps: res.steps } })}
          >

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
               {res.steps.map((step, idx) => {
                 const fromDetail = stopDetailsByName.get(step.fromStop);
                 const toDetail = stopDetailsByName.get(step.toStop);
                 const fromDup = duplicateStopNames.has(step.fromStop);
                 const toDup = duplicateStopNames.has(step.toStop);
                 return (
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
                             {step.route.line_name && <span className="text-[10px] text-slate-400 font-normal truncate max-w-[120px]">{step.route.line_name}</span>}
                             {step.route.qrPayment === '✅ Supported' && (
                               <span className="ui-badge bg-amber-50 text-amber-700 border border-amber-100" title="QR Payment ပံ့ပိုးမှု">
                                 <CreditCard size={10} className="mr-1" />
                                 QR
                               </span>
                             )}
                          </div>
                         <p className="mt-1 text-xs text-slate-500">
                            <span className="text-brand font-medium">
                              {step.fromStop}
                              {fromDup && fromDetail && <span className="text-slate-400 font-normal"> ({fromDetail.township_mm})</span>}
                            </span>
                            မှ
                            <span className="text-brand font-medium">
                              {step.toStop}
                              {toDup && toDetail && <span className="text-slate-400 font-normal"> ({toDetail.township_mm})</span>}
                            </span>
                            အထိ
                         </p>
                         {fromDetail && toDetail && (
                           <p className="mt-1 text-[10px] text-slate-400">
                             {getDistance(fromDetail.lat, fromDetail.lng, toDetail.lat, toDetail.lng).toFixed(2)} km
                           </p>
                         )}
                      </div>
                  </div>
                 );
               })}
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
  const [cacheInfo, setCacheInfo] = useState<{ size: string; age: string } | null>(null);
  
  // Phone Copy State များ
  const [copiedKpay, setCopiedKpay] = useState(false);
  const [copiedWave, setCopiedWave] = useState(false);

  // Telegram link / alert status
  const userId = useMemo(() => getUserId(), []);
  const [tgStatus, setTgStatus] = useState<AlertStatus | null>(null);
  const [tgBusy, setTgBusy] = useState(false);
  const [tgMsg, setTgMsg] = useState('');

  useEffect(() => {
    let cancelled = false;
    getAlertStatus(userId)
      .then((s) => { if (!cancelled) setTgStatus(s); })
      .catch(() => { if (!cancelled) setTgStatus({ linked: false, alert: null }); });
    return () => { cancelled = true; };
  }, [userId]);

  const handleCancelTgAlert = async () => {
    setTgBusy(true);
    setTgMsg('');
    try {
      await cancelAlert(userId);
      setTgStatus((s) => (s ? { ...s, alert: null } : s));
      setTgMsg('🚫 သတိပေးချက် ပယ်ဖျက်ပြီးပါပြီ။');
    } catch {
      setTgMsg('ပယ်ဖျက်၍ မရပါ။');
    } finally {
      setTgBusy(false);
    }
  };

  useEffect(() => {
    const updateCacheInfo = () => {
      try {
        const raw = localStorage.getItem(CACHE_KEY);
        if (!raw) {
          setCacheInfo(null);
          return;
        }
        const cache = JSON.parse(raw) as LocalCache;
        const size = new Blob([raw]).size;
        const sizeStr = size > 1024 * 1024 ? `${(size / (1024 * 1024)).toFixed(1)} MB` : `${(size / 1024).toFixed(0)} KB`;
        const age = new Date(cache.timestamp);
        const ageStr = age.toLocaleDateString('my-MM', { year: 'numeric', month: 'short', day: 'numeric' });
        setCacheInfo({ size: sizeStr, age: ageStr });
      } catch {
        setCacheInfo(null);
      }
    };
    updateCacheInfo();
  }, [status]);

  // Data Update လုပ်ဆောင်ချက် (bulkAdd မှ bulkPut သို့ ပြောင်းလဲထားပါသည်)
  const updateData = async () => {
    setStatus('updating');
    try {
      const loadedStops = await loadStopsFromRouteFiles();
      await db.busStops.clear();
      await db.busStops.bulkPut(loadedStops);
      
      const loadedRoutes = await loadRoutesFromFiles();
      await db.busRoutes.clear();
      await db.busRoutes.bulkPut(loadedRoutes);

      saveToLocalCache(loadedStops, loadedRoutes);
    } catch (error) {
      console.error("Update failed:", error);
    } finally {
      setStatus('done');
      setTimeout(() => setStatus('idle'), 2000);
    }
  };

  const handleClearCache = () => {
    clearLocalCache();
    setCacheInfo(null);
  };

  // Phone Copy လုပ်ဆောင်ချက်
  const handleCopy = (text: string, type: 'kpay' | 'wave') => {
    navigator.clipboard.writeText(text).then(() => {
      if (type === 'kpay') {
        setCopiedKpay(true);
        setTimeout(() => setCopiedKpay(false), 2000);
      } else {
        setCopiedWave(true);
        setTimeout(() => setCopiedWave(false), 2000);
      }
    });
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-6 md:py-8 space-y-6 pb-24 md:pb-8">
      
      {/* 1. App Data Sync / Update Card (အပေါ်က Function အတွက် UI ကတ်ပြား) */}
      <div className="ui-card p-6 bg-white rounded-2xl shadow-sm border border-slate-100">
        <div className="flex items-center gap-4 mb-5">
          <div className="bg-slate-900 p-3 rounded-xl text-white">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/><path d="M16 16h5v5"/></svg>
          </div>
          <div>
            <h3 className="font-semibold text-slate-900">Application Data</h3>
            <p className="text-sm text-slate-500">လမ်းကြောင်းနှင့် မှတ်တိုင်အချက်အလက်များ အပ်ဒိတ်လုပ်ရန်</p>
          </div>
        </div>

        <div className="bg-slate-50 rounded-xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-slate-700">Offline Database Version</p>
            <p className="text-xs text-slate-500 mt-0.5">နောက်ဆုံးထွက်လမ်းကြောင်းများကို ဖုန်းထဲသို့ ဒေါင်းလုဒ်ဆွဲထည့်ပါ။</p>
            {cacheInfo && (
              <p className="text-[10px] text-slate-400 mt-1">
                Local cache: {cacheInfo.size} • Updated {cacheInfo.age}
              </p>
            )}
          </div>
          
          <div className="flex items-center gap-2">
            {cacheInfo && (
              <button
                onClick={handleClearCache}
                className="px-3 py-2 rounded-xl text-xs font-medium bg-white border border-slate-200 text-slate-600 hover:bg-slate-50 active:scale-[0.98] transition-all"
              >
                Clear Cache
              </button>
            )}
            <button
              onClick={updateData}
              disabled={status === 'updating'}
              className={`w-full sm:w-auto px-5 py-2.5 rounded-xl text-sm font-medium transition-all shadow-sm active:scale-[0.98] ${
                status === 'updating' 
                  ? 'bg-slate-100 text-slate-400 cursor-not-allowed'
                  : status === 'done'
                  ? 'bg-emerald-500 text-white'
                  : 'bg-slate-900 hover:bg-slate-800 text-white'
              }`}
            >
              {status === 'updating' && (
                <span className="flex items-center justify-center gap-2">
                  <svg className="animate-spin h-4 w-4 text-slate-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                  ခဏစောင့်ပါ...
                </span>
              )}
              {status === 'done' && '✓ Sync အောင်မြင်ပါသည်'}
              {status === 'idle' && 'လမ်းကြောင်းများ Update လုပ်မည်'}
            </button>
          </div>
        </div>
      </div>

      {/* 1b. Telegram Alert / Link Card */}
      <div className="ui-card p-6 bg-white rounded-2xl shadow-sm border border-slate-100">
        <div className="flex items-center gap-4 mb-5">
          <div className="bg-gradient-to-tr from-sky-500 to-blue-400 p-3 rounded-xl text-white">
            <Bot size={20} />
          </div>
          <div>
            <h3 className="font-semibold text-slate-900">Telegram သတိပေးချက်</h3>
            <p className="text-sm text-slate-500">မှတ်တိုင် နီးကပ်လျှင် သတိပေးခံရန် ချိတ်ဆက်ပါ</p>
          </div>
        </div>

        {tgStatus && tgStatus.alert ? (
          <div className="bg-emerald-50 border border-emerald-100 rounded-xl p-4 space-y-2">
            <p className="text-sm text-emerald-700">🔔 <b>{tgStatus.alert.stopName}</b> မှတ်တိုင်သို့ ရောက်လျှင် သတိပေးပါမည်။</p>
            <p className="text-xs text-emerald-600">Bot သို့ Live Location ပို့ပေးပါ။</p>
            <button
              onClick={handleCancelTgAlert}
              disabled={tgBusy}
              className="ui-btn-ghost w-full justify-center py-2 text-rose-600 border-rose-200 hover:bg-rose-50 disabled:opacity-50"
            >သတိပေးချက် ပယ်ဖျက်မည်</button>
          </div>
        ) : tgStatus && tgStatus.linked ? (
          <div className="bg-emerald-50 border border-emerald-100 rounded-xl p-4 text-sm text-emerald-700">
            ✅ ချိတ်ဆက်ပြီးပါပြီ။ မှတ်တိုင်တစ်ခုချက် ဖွင့်ပြီး "သတိပေးပါ" ကို နှိပ်ပါ။
          </div>
        ) : (
          <div className="space-y-3">
            <p className="text-xs text-slate-600">Telegram နှင့် ချိတ်ဆက်ပြီး မှတ်တိုင် နီးကပ်လျှင် သတိပေးခံရန် ရွေးချယ်ပါ။</p>
            <a
              href={connectUrl(userId)}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2 w-full py-2.5 px-4 bg-[#26A5E4] hover:bg-[#2297cc] text-white font-medium rounded-xl shadow-sm transition-colors text-sm"
            >
              <Send size={16} /> Telegram နဲ့ ချိတ်ဆက်မည်
            </a>
            <div className="bg-white rounded-xl border border-slate-200 p-3 space-y-1.5">
              <p className="text-[11px] text-slate-500 leading-relaxed">
                Bot ကို အရင် ဖွင့်ထားပြီးသားဆိုရင် Link နှိပ်ပြီးနောက် Bot ထဲမှာ အောက်ပါ ကုဒ်ကို တိုက်ရိုက် ပို့ပါ (သို့မဟုတ် <code className="bg-slate-100 px-1 rounded">/start {userId}</code>):
              </p>
              <div className="flex items-center justify-between gap-2 bg-slate-50 rounded-lg px-3 py-2">
                <span className="font-mono font-semibold tracking-widest text-slate-800 select-all">{userId}</span>
                <button
                  type="button"
                  onClick={() => navigator.clipboard?.writeText(userId)}
                  className="text-xs font-medium text-blue-600 hover:text-blue-700"
                >ကူးယူ</button>
              </div>
            </div>
          </div>
        )}

        {tgMsg && <p className="text-xs text-center text-slate-600 mt-3">{tgMsg}</p>}
      </div>

      {/* 2. Developer Info Card */}
      <div className="ui-card p-6 bg-white rounded-2xl shadow-sm border border-slate-100">
        <div className="flex items-center gap-4 mb-5">
          <div className="bg-slate-900 p-3 rounded-xl text-white">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
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
                <p className="ui-label text-xs font-medium text-slate-400 uppercase tracking-wider">App Name</p>
                <p className="font-semibold text-slate-800 mt-0.5">YBS Guide</p>
              </div>
              <div>
                <p className="ui-label text-xs font-medium text-slate-400 uppercase tracking-wider">Version</p>
                <p className="font-semibold text-slate-800 mt-0.5">3.1</p>
              </div>
            </div>
          </div>

          <div className="bg-slate-50 rounded-xl p-4 space-y-3">
            <div>
              <p className="ui-label text-xs font-medium text-slate-400 uppercase tracking-wider">Developer</p>
              <p className="font-semibold text-slate-800 mt-0.5">Arkar Yan</p>
              <p className="text-sm text-slate-500">Project Manager | Instructor</p>
            </div>

            <div className="pt-3 border-t border-slate-200 space-y-2">
              <p className="ui-label text-xs font-medium text-slate-400 uppercase tracking-wider">Get In Touch</p>
              <p className="text-sm text-blue-600 font-medium">info@arkaryan.net</p>
              <p className="text-sm text-slate-600">https://www.arkaryan.net/</p>
            </div>
          </div>
        </div>
      </div>

      {/* 3. App Announcement / Version 3.0 Info Card */}
      <div className="ui-card p-6 bg-white rounded-2xl shadow-sm border border-slate-100 space-y-5">
        <div className="flex items-center gap-4 border-b border-slate-100 pb-4">
          <div className="bg-gradient-to-tr from-amber-500 to-orange-400 p-3 rounded-xl text-white">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/><path d="m5 3 1 2.5L8.5 6 6 7 5 9.5 4 7 1.5 6 4 5.5z"/><path d="m19 17 1 2.5 2.5.5-2.5 1-1 2.5-1-2.5-2.5-1 2.5-1z"/></svg>
          </div>
          <div>
            <h3 className="font-semibold text-slate-900">What's New in V3.1</h3>
            <p className="text-sm text-slate-500">ဗားရှင်းသစ် အချက်အလက်များ</p>
          </div>
        </div>

        {/* Main Banner Text */}
        <div className="bg-blue-50/60 rounded-xl p-4 border border-blue-100/50">
          <p className="text-sm text-slate-700 leading-relaxed font-medium">
            <span className="font-semibold text-blue-600">YBS Guide Bot Version 3.1</span> ကို Telegram တွင် စတင်အသုံးပြုနိုင်ပြီဖြစ်ကြောင်း သတင်းကောင်းပါးအပ်ပါတယ် ✌️
          </p>
          <p className="text-sm text-slate-600 leading-relaxed mt-2">
            ရန်ကုန်မြို့နေ မိဘပြည်သူများ ဘတ်စ်ကားစီးနင်းရာတွင် ပိုမိုအဆင်ပြေချောမွေ့စေဖို့အတွက် YBS AI Version 3.1 ကို အောက်ပါ Features အသစ်တွေနဲ့ မွမ်းမံထားပါတယ်။
          </p>
        </div>

        {/* Features List */}
        <div className="space-y-3">
          <div className="flex items-start gap-3">
            <div className="mt-1 bg-emerald-100 p-1 rounded-full text-emerald-600">
              <CheckCircle2 size={14} />
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-800">AI-Powered Assistant</p>
              <p className="text-xs text-slate-500">လမ်းကြောင်းများကို မြန်မာလို မေးမြန်းနိုင်ခြင်း။</p>
            </div>
          </div>

          <div className="flex items-start gap-3">
            <div className="mt-1 bg-emerald-100 p-1 rounded-full text-emerald-600">
              <CheckCircle2 size={14} />
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-800">Telegram Alert System</p>
              <p className="text-xs text-slate-500">မှတ်တိုင်နီးကပ်လျှင် Telegram မှတဆင့် သတိပေးချက်ပေးပို့ခြင်း။</p>
            </div>
          </div>

          <div className="flex items-start gap-3">
            <div className="mt-1 bg-emerald-100 p-1 rounded-full text-emerald-600">
              <CheckCircle2 size={14} />
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-800">Advanced Route Finding</p>
              <p className="text-xs text-slate-500">အမြန်ဆုံးနှင့် အဆင်ပြေဆုံး လမ်းကြောင်းများကို ပိုမိုတိကျစွာ ရှာဖွေပေးခြင်း။</p>
            </div>
          </div>
        </div>
      </div>

      {/* 4. Donation Card */}
      <div className="ui-card p-6 bg-gradient-to-br from-slate-900 to-slate-800 rounded-2xl shadow-lg text-white">
        <div className="flex items-center gap-4 mb-6">
          <div className="bg-white/10 p-3 rounded-xl backdrop-blur-sm">
            <Sparkles size={20} className="text-amber-400" />
          </div>
          <div>
            <h3 className="font-semibold text-white">Support This Project</h3>
            <p className="text-sm text-slate-300">YBS Guide ကို ဆက်လက်ဖွံ့ဖြိုးရန် ကူညီနိုင်ပါသည်</p>
          </div>
        </div>

        <p className="text-sm text-slate-300 leading-relaxed mb-6">
          YBS Guide ကို အခမဲ့ ဝန်ဆောင်မှုပေးနေခြင်း ဖြစ်ပါတယ်။ Server ဖိုးနှင့် အခြားကုန်ကျစရိတ်များအတွက် မိမိတတ်နိုင်သလောက် ပါဝင်လှူဒါန်းနိုင်ပါတယ်။
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div className="bg-white/5 rounded-2xl p-4 border border-white/10 flex items-center justify-between group">
            <div className="flex items-center gap-3">
              <div className="bg-blue-600 p-2 rounded-lg text-xs font-bold">K</div>
              <div>
                <p className="text-[10px] text-slate-400 font-medium uppercase tracking-wider">Kpay</p>
                <p className="text-sm font-mono font-semibold">09420030017</p>
              </div>
            </div>
            <button 
              onClick={() => handleCopy('09420030017', 'kpay')}
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
            >
              {copiedKpay ? <CheckCircle2 size={16} className="text-emerald-400" /> : <Hash size={16} className="text-slate-400" />}
            </button>
          </div>

          <div className="bg-white/5 rounded-2xl p-4 border border-white/10 flex items-center justify-between group">
            <div className="flex items-center gap-3">
              <div className="bg-yellow-500 p-2 rounded-lg text-xs font-bold text-slate-900">W</div>
              <div>
                <p className="text-[10px] text-slate-400 font-medium uppercase tracking-wider">Wave Money</p>
                <p className="text-sm font-mono font-semibold">09420030017</p>
              </div>
            </div>
            <button 
              onClick={() => handleCopy('09420030017', 'wave')}
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
            >
              {copiedWave ? <CheckCircle2 size={16} className="text-emerald-400" /> : <Hash size={16} className="text-slate-400" />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

// --- Main App ---

const App: React.FC = () => {
  const [stops, setStops] = useState<BusStop[]>([]);
  const [routes, setRoutes] = useState<BusRoute[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeRoute, setActiveRoute] = useState<BusRoute | null>(null);
  const [activeStop, setActiveStop] = useState<BusStop | null>(null);
  const [favorites, setFavorites] = useState<Set<string>>(new Set());

  const navigate = useNavigate();

  useEffect(() => {
    const init = async () => {
      const cached = loadFromLocalCache();
      if (cached) {
        setStops(cached.stops);
        setRoutes(cached.routes);
        setLoading(false);
      }

      const loadedStops = await loadStopsFromRouteFiles();
      const loadedRoutes = await loadRoutesFromFiles();
      setStops(loadedStops);
      setRoutes(loadedRoutes);
      saveToLocalCache(loadedStops, loadedRoutes);
      setLoading(false);
    };
    init();

    const favs = localStorage.getItem('ybs-favorites');
    if (favs) setFavorites(new Set(JSON.parse(favs)));
  }, []);

  const toggleFavorite = (id: string) => {
    const next = new Set(favorites);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setFavorites(next);
    localStorage.setItem('ybs-favorites', JSON.stringify(Array.from(next)));
  };

  if (loading) {
    return (
      <div className="fixed inset-0 flex flex-col items-center justify-center bg-slate-50 gap-4">
        <div className="bg-slate-900 p-4 rounded-3xl shadow-xl animate-bounce">
          <Bus size={40} className="text-white" />
        </div>
        <div className="flex flex-col items-center gap-2">
          <p className="text-slate-900 font-bold text-xl tracking-tight">YBS Guide</p>
          <div className="flex items-center gap-2 text-slate-400 text-sm font-medium">
            <RefreshCw size={14} className="animate-spin" />
            <span>အချက်အလက်များ ရယူနေပါသည်...</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col font-sans selection:bg-brand/10 selection:text-brand">
      <Header />
      <main className="flex-1 relative">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/routes" element={
            <RoutesPage 
              routes={routes} 
              stops={stops}
              favorites={favorites} 
              onToggleFavorite={toggleFavorite}
              onRouteClick={setActiveRoute}
              onStopClick={setActiveStop}
            />
          } />
          <Route path="/stops" element={
            <StopsPage 
              stops={stops} 
              onStopClick={setActiveStop} 
            />
          } />
          <Route path="/find-route" element={
            <FindRoutePage 
              routes={routes} 
              stops={stops} 
              onRouteClick={setActiveRoute}
            />
          } />
          <Route path="/route-plan-detail" element={<RoutePlanDetailFromState />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/assistant" element={
             <div className="max-w-3xl mx-auto p-4 h-[calc(100vh-140px)]">
                <ChatInterface routes={routes} stops={stops} onRouteClick={setActiveRoute} />
             </div>
          } />
        </Routes>
      </main>

      {activeRoute && (
        <RouteDetailPage 
          route={activeRoute} 
          onClose={() => setActiveRoute(null)} 
          onStopClick={setActiveStop}
        />
      )}

      {activeStop && (
        <StopDetailPage 
          stop={activeStop} 
          onClose={() => setActiveStop(null)} 
          onRouteClick={setActiveRoute}
          favorites={favorites}
          onToggleFavorite={(id) => toggleFavorite(id.toString())}
          routes={routes}
        />
      )}

      <MobileBottomNav />
    </div>
  );
};

const ChatInterface: React.FC<{ routes: BusRoute[], stops: BusStop[], onRouteClick: (r: BusRoute) => void }> = ({ routes, stops, onRouteClick }) => {
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([
    { role: 'assistant', content: 'မင်္ဂလာပါ! ဘယ်ကိုသွားချင်ပါသလဲ? ဥပမာ - "မြေနီကုန်းကနေ ဆူးလေကို ဘယ်လိုသွားရမလဲ" လို့ မေးမြန်းနိုင်ပါတယ်။' }
  ]);
  const [loading, setLoading] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();

  const stopNames = useMemo(() => stops.map(s => s.name_mm), [stops]);

  const handleSend = async () => {
    if (!input.trim() || loading) return;
    
    const userMsg = input.trim();
    setInput('');
    setMessages(prev => [...prev, { role: 'user', content: userMsg }]);
    setLoading(true);

    const extracted = extractStopsFromText(userMsg, stopNames);
    
    setTimeout(async () => {
      if (extracted && extracted.start && extracted.end) {
        const results = await performBFS(extracted.start, extracted.end, routes, stops);
        if (results.length > 0) {
          setMessages(prev => [...prev, { 
            role: 'assistant', 
            content: `${extracted.start} မှ ${extracted.end} သို့ သွားနိုင်သော လမ်းကြောင်း ${results.length} ခု တွေ့ရှိပါသည်။`,
            results: results.slice(0, 3)
          }]);
        } else {
          setMessages(prev => [...prev, { role: 'assistant', content: 'စိတ်မရှိပါနဲ့၊ အဲ့ဒီမှတ်တိုင်နှစ်ခုကြား တိုက်ရိုက် သို့မဟုတ် တစ်ဆင့်ပြောင်း လမ်းကြောင်း ရှာမတွေ့ပါ။' }]);
        }
      } else {
        setMessages(prev => [...prev, { role: 'assistant', content: 'တောင်းပန်ပါတယ်။ မှတ်တိုင်အမည်တွေကို သေချာမသိလိုက်လို့ပါ။ "A မှ B သို့" ဆိုတဲ့ ပုံစံမျိုးနဲ့ ပြန်မေးပေးပါဦး။' }]);
      }
      setLoading(false);
    }, 800);
  };

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  return (
    <div className="flex flex-col h-full bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
      <div className="flex-1 overflow-y-auto p-4 space-y-4" ref={scrollRef}>
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[85%] p-3 rounded-2xl text-sm ${
              m.role === 'user' ? 'bg-brand text-white rounded-tr-none' : 'bg-slate-100 text-slate-800 rounded-tl-none'
            }`}>
              <p className="leading-relaxed">{m.content}</p>
              {m.results && (
                <div className="mt-3 space-y-2">
                  {m.results.map((res, ri) => (
                    <div 
                      key={ri} 
                      onClick={() => navigate('/route-plan-detail', { state: { steps: res.steps } })}
                      className="bg-white/80 p-2 rounded-xl border border-slate-200 text-slate-800 cursor-pointer hover:bg-white transition-colors"
                    >
                      <div className="flex items-center gap-1.5 flex-wrap">
                        {res.steps.map((s, si) => (
                          <React.Fragment key={si}>
                            <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-slate-900 text-white">YBS {s.route.id}</span>
                            {si < res.steps.length - 1 && <ChevronRight size={10} className="text-slate-400" />}
                          </React.Fragment>
                        ))}
                      </div>
                      <p className="text-[10px] mt-1.5 text-slate-500">
                        {res.transferCount === 0 ? 'တိုက်ရိုက်' : `${res.transferCount} ဆင့်ပြောင်း`} • {res.totalDistance.toFixed(1)} km
                      </p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ))}
        {loading && (
          <div className="flex justify-start">
            <div className="bg-slate-100 p-3 rounded-2xl rounded-tl-none">
              <RefreshCw size={16} className="animate-spin text-slate-400" />
            </div>
          </div>
        )}
      </div>
      <div className="p-4 border-t border-slate-100 bg-slate-50">
        <div className="flex gap-2">
          <input 
            type="text" 
            className="ui-input flex-1 bg-white"
            placeholder="မေးမြန်းလိုသည်များကို ရိုက်ထည့်ပါ..."
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
          />
          <button 
            onClick={handleSend}
            disabled={!input.trim() || loading}
            className="ui-btn ui-btn-primary p-3 rounded-xl"
          >
            <Send size={18} />
          </button>
        </div>
      </div>
    </div>
  );
};

export default App;
