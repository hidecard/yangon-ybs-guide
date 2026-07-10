// Use default import for Dexie to ensure class methods like .version() are correctly inherited and recognized by the TypeScript compiler.
import Dexie, { Table } from 'dexie';
import { BusStop, BusRoute, FavoriteStop, FavoriteRoute } from './types';

export class YBSDatabase extends Dexie {
  busStops!: Table<BusStop, number>;
  busRoutes!: Table<BusRoute, string>;
  favoriteStops!: Table<FavoriteStop, number>;
  favoriteRoutes!: Table<FavoriteRoute, string>;

  constructor() {
    super('YBSDatabase');
    
    // Defining database schema with versioning
    this.version(1).stores({
      busStops: 'id, name_mm, name_en, township_mm',
      busRoutes: 'id',
      favoriteStops: 'stopId',
      favoriteRoutes: 'routeId'
    });
  }
}

export const db = new YBSDatabase();

if (typeof window !== 'undefined' && navigator.storage && navigator.storage.persist) {
  navigator.storage.persist().then((isPersisted) => {
    if (isPersisted) {
      console.log("🚀 Storage persisted: Data will not be cleared by the mobile browser/OS automatically.");
    } else {
      console.log("⚠️ Storage persistence denied: Data might be cleared if device storage is running very low.");
    }
  });
}