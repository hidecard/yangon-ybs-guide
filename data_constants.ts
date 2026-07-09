import { BusStop, BusRoute } from './types';

export const ROUTE_FILES = [
  'ybs_1_data.json',
  'ybs_2_data.json',
  'ybs_3_data.json',
  'ybs_4_data.json',
  'ybs_5_data.json',
  'ybs_6_data.json',
  'ybs_7_industrial_zone_data.json',
  'ybs_7_nat_sin_data.json',
  'ybs_8_data.json',
  'ybs_9_nyrddc_data.json',
  'ybs_9_ward_87_data.json',
  'ybs_10_data.json',
  'ybs_11_data.json',
  'ybs_12_data.json',
  'ybs_13_data.json',
  'ybs_14_data.json',
  'ybs_15_data.json',
  'ybs_16_data.json',
  'ybs_17_data.json',
  'ybs_18_data.json',
  'ybs_19_data.json',
  'ybs_20_data.json',
  'ybs_21_data.json',
  'ybs_22_data.json',
  'ybs_23_data.json',
  'ybs_24_data.json',
  'ybs_25_data.json',
  'ybs_26_data.json',
  'ybs_27_data.json',
  'ybs_28_data.json',
  'ybs_29_data.json',
  'ybs_30_data.json',
  'ybs_31_data.json',
  'ybs_31_thilawa_housing_data.json',
  'ybs_32_data.json',
  'ybs_33_data.json',
  'ybs_34_kayan_data.json',
  'ybs_34_thone_gwa_data.json',
  'ybs_35_data.json',
  'ybs_36_data.json',
  'ybs_37_data.json',
  'ybs_38_data.json',
  'ybs_39_data.json',
  'ybs_40_data.json',
  'ybs_41_data.json',
  'ybs_42_data.json',
  'ybs_43_data.json',
  'ybs_44_data.json',
  'ybs_45_data.json',
  'ybs_46_data.json',
  'ybs_52_data.json',
  'ybs_53_meekwet_zay_data.json',
  'ybs_53_yone_shay_data.json',
  'ybs_55_data.json',
  'ybs_56_data.json',
  'ybs_57_data.json',
  'ybs_58_data.json',
  'ybs_59_data.json',
  'ybs_60_data.json',
  'ybs_60_mini_bus_data.json',
  'ybs_61_data.json',
  'ybs_62_data.json',
  'ybs_63_data.json',
  'ybs_64_khe_mar_thi_rd_data.json',
  'ybs_64_thu_dhamma_rd_data.json',
  'ybs_65_data.json',
  'ybs_66_data.json',
  'ybs_67_data.json',
  'ybs_68_data.json',
  'ybs_70_data.json',
  'ybs_70_mini_bus_data.json',
  'ybs_71_data.json',
  'ybs_72_data.json',
  'ybs_74_data.json',
  'ybs_75_data.json',
  'ybs_76_data.json',
  'ybs_77_data.json',
  'ybs_78_data.json',
  'ybs_79_data.json',
  'ybs_81_data.json',
  'ybs_82_data.json',
  'ybs_83_data.json',
  'ybs_84_data.json',
  'ybs_85_data.json',
  'ybs_86_data.json',
  'ybs_87_data.json',
  'ybs_88_data.json',
  'ybs_89_min_nanda_rd_data.json',
  'ybs_89_myin_taw_thar_rd_data.json',
  'ybs_89_national_cancer_institute_data.json',
  'ybs_90_data.json',
  'ybs_91_data.json',
  'ybs_92_data.json',
  'ybs_93_data.json',
  'ybs_94_data.json',
  'ybs_95_data.json',
  'ybs_96_data.json',
  'ybs_97_data.json',
  'ybs_98_data.json',
  'ybs_99_data.json',
  'ybs_100_data.json',
  'ybs_103_data.json',
  'ybs_104_data.json',
  'ybs_105_data.json',
  'ybs_106_data.json',
  'ybs_107_data.json',
  'ybs_108_data.json',
  'ybs_109_data.json',
  'ybs_110_data.json',
  'ybs_111_industrial_zone_data.json',
  'ybs_111_nat_sin_data.json',
  'ybs_112_data.json',
  'ybs_113_data.json',
  'ybs_114_data.json',
  'ybs_115_data.json',
  'ybs_116_data.json',
  'ybs_117_data.json',
  'ybs_118_data.json',
  'ybs_119_data.json',
  'ybs_120_data.json',
  'ybs_123_a_phyauk_data.json',
  'ybs_123_taikkyi_data.json',
  'ybs_124_data.json',
  'ybs_126_data.json',
  'ybs_128_data.json',
  'ybs_129_data.json',
  'ybs_130_data.json',
  'ybs_131_data.json',
  'ybs_132_data.json',
  'ybs_133_data.json',
  'ybs_134_data.json',
  'ybs_136_data.json',
  'ybs_137_data.json',
  'ybs_138_data.json',
  'ybs_139_data.json',
  'ybs_141_data.json',
  'ybs_142_data.json',
  'ybs_143_data.json',
  'ybs_144_data.json',
  'ybs_145_data.json',
  'ybs_197_data.json',
  'ybs_199_data.json',
  'ybs_200_data.json',
  'ybs_202_data.json',
  'ybs_203_data.json',
  'ybs_204_data.json',
  'ybs_205_data.json'
];

export const loadRoutesFromFiles = async (): Promise<BusRoute[]> => {
  const routes: BusRoute[] = [];
  for (const file of ROUTE_FILES) {
    try {
      const response = await fetch(`/routes/${file}`);
      if (!response.ok) {
        console.warn(`Failed to load ${file}: ${response.status}`);
        continue;
      }
      const data = await response.json();
      
      // Extract route ID from bus_line
      const routeIdRaw = data.bus_line || file.replace('ybs_', '').replace('_data.json', '');
      const routeId = String(routeIdRaw).trim();

      // Generate a consistent color based on route ID
      const generateColor = (id: string) => {
        let hash = 0;
        for (let i = 0; i < id.length; i++) {
          hash = id.charCodeAt(i) + ((hash << 5) - hash);
        }
        const c = (hash & 0x00FFFFFF).toString(16).toUpperCase();
        return '#' + '00000'.substring(0, 6 - c.length) + c;
      };
      
      // Extract stops with coordinates
      const stopNames: string[] = [];
      const coordinates: [number, number][] = [];
      
      if (data.stops && Array.isArray(data.stops)) {
        data.stops.forEach((stop: any) => {
          if (stop.stop_name_mm) {
            stopNames.push(stop.stop_name_mm);
          }
          if (stop.latitude && stop.longitude) {
            coordinates.push([stop.longitude, stop.latitude]);
          }
        });
      }
      
      const route: BusRoute = {
        id: routeId,
        color: generateColor(routeId),
        operator: data.route_info?.Agency || '',
        // route_info object contains: "Route Name" and "Line Name"
        line_name: data.route_info?.['Line Name'] || data.route_info?.['Line Name'.toString()] || undefined,
        stops: stopNames,
        shape: coordinates.length > 0 ? {
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: coordinates
          },
          properties: {}
        } : undefined
      };

      routes.push(route);
    } catch (error) {
      console.error(`Error loading ${file}:`, error);
    }
  }
  return routes;
};

export const loadStopsFromRouteFiles = async (): Promise<BusStop[]> => {
  const stopsMap = new Map<string, BusStop>();
  let stopIdCounter = 1;
  
  for (const file of ROUTE_FILES) {
    try {
      const response = await fetch(`/routes/${file}`);
      if (!response.ok) {
        console.warn(`Failed to load ${file}: ${response.status}`);
        continue;
      }
      const data = await response.json();
      
      if (data.stops && Array.isArray(data.stops)) {
        data.stops.forEach((stop: any) => {
          if (stop.stop_name_mm && stop.latitude && stop.longitude) {
            const key = `${stop.stop_name_mm}_${stop.latitude}_${stop.longitude}`;
            
            if (!stopsMap.has(key)) {
              const roadParts = stop.road ? stop.road.split(',') : ['', ''];
              const township = roadParts[1] ? roadParts[1].trim() : roadParts[0].trim();
              
              const busStop: BusStop = {
                id: stopIdCounter++,
                lat: stop.latitude,
                lng: stop.longitude,
                name_en: stop.stop_name_en || '',
                name_mm: stop.stop_name_mm,
                road_en: roadParts[0] ? roadParts[0].trim() : '',
                road_mm: roadParts[0] ? roadParts[0].trim() : '',
                township_en: township,
                township_mm: township
              };
              stopsMap.set(key, busStop);
            }
          }
        });
      }
    } catch (error) {
      console.error(`Error loading ${file}:`, error);
    }
  }
  
  return Array.from(stopsMap.values());
};