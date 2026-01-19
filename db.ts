
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
    // version() is a standard Dexie instance method inherited from the Dexie base class.
    this.version(1).stores({
      busStops: 'id, name_mm, name_en, township_mm',
      busRoutes: 'id',
      favoriteStops: 'stopId',
      favoriteRoutes: 'routeId'
    });
  }
}

export const db = new YBSDatabase();
