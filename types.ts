
export interface BusStop {
  id: number;
  lat: number;
  lng: number;
  name_en: string;
  name_mm: string;
  road_en: string;
  road_mm: string;
  township_en: string;
  township_mm: string;
}

export interface BusRoute {
  id: string;
  color: string;
  // Fix: Added optional operator property to match the data structure used in INITIAL_ROUTES
  operator?: string;
  stops: string[]; // List of name_mm
}

export interface FavoriteStop {
  stopId: number;
}

export interface FavoriteRoute {
  routeId: string;
}

export enum Page {
  Home = 'home',
  Routes = 'routes',
  RouteDetail = 'route-detail',
  Stops = 'stops',
  StopDetail = 'stop-detail',
  Map = 'map',
  FindRoute = 'find-route',
  Assistant = 'assistant',
  Favorites = 'favorites',
  Settings = 'settings'
}
