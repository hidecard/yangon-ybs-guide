
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
  operator?: string;
  /** "Line Name" shown on the /routes page (from route_info.Line Name) */
  line_name?: string;
  stops: string[]; // List of name_mm
  shape?: {
    geometry: {
      coordinates: [number, number][]; // [lng, lat] pairs
      type: string;
    };
    properties: any;
    type: string;
  };
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
