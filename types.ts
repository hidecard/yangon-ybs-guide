
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

export interface BusStopDetailed {
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
  operator?: string;
  /** "Line Name" shown on the /routes page (from route_info.Line Name) */
  line_name?: string;
  stops: string[]; // List of name_mm

  /** Route-specific ordered stops with coordinates (prevents cross-bus mixing) */
  stopsDetailed?: BusStopDetailed[];

  shape?: {
    geometry: {
      coordinates: [number, number][]; // [lng, lat] pairs
      type: string;
    };
    properties: any;
    type: string;
  };

  /** QR Payment support status from route_info["QR Payment"] */
  qrPayment?: string;
}



export interface FavoriteStop {
  stopId: number;
}

export interface FavoriteRoute {
  routeId: string;
}

export interface FavoriteTripStep {
  route: BusRoute;
  fromStop: string;
  toStop: string;
}

export interface FavoriteTrip {
  id: string;
  steps: FavoriteTripStep[];
  createdAt: number;
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
