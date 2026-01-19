
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
    // Fix: Ensure version() is correctly called on the class instance.
    // Using default import for Dexie is the recommended approach for subclassing in TypeScript to avoid property recognition issues.
    this.version(1).stores({
      busStops: 'id, name_mm, name_en, township_mm',
      busRoutes: 'id',
      favoriteStops: 'stopId',
      favoriteRoutes: 'routeId'
    });
  }
}

export const db = new YBSDatabase();
