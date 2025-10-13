//
//  EarthView.swift
//  touchtime
//
//  Created on 02/10/2025.
//

import SwiftUI
import MapKit
import Combine

struct EarthView: View {
    @Binding var worldClocks: [WorldClock]
    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
    ))
    @State private var currentDate = Date()
    @State private var timerCancellable: AnyCancellable?
    @State private var showShareSheet = false
    @State private var showSettingsSheet = false
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showSkyDot") private var showSkyDot = true
    
    // 設置地圖縮放限制
    private let cameraBounds = MapCameraBounds(
        minimumDistance: 5000000,     // 最小高度 1,000km（最大放大）
        maximumDistance: nil
    )
    
    // Convert timezone identifier to coordinate
    func getCoordinate(for timeZoneIdentifier: String) -> CLLocationCoordinate2D? {
        // Map of major cities/timezones to their coordinates
        let cityCoordinates: [String: CLLocationCoordinate2D] = [
            // Americas - North America
            "America/New_York": CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            "America/Chicago": CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),
            "America/Denver": CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            "America/Los_Angeles": CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            "America/Vancouver": CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207),
            "America/Toronto": CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
            "America/Montreal": CLLocationCoordinate2D(latitude: 45.5017, longitude: -73.5673),
            "America/Edmonton": CLLocationCoordinate2D(latitude: 53.5461, longitude: -113.4938),
            "America/Winnipeg": CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384),
            "America/Regina": CLLocationCoordinate2D(latitude: 50.4452, longitude: -104.6189),
            "America/Halifax": CLLocationCoordinate2D(latitude: 44.6488, longitude: -63.5752),
            "America/St_Johns": CLLocationCoordinate2D(latitude: 47.5615, longitude: -52.7126),
            "America/Anchorage": CLLocationCoordinate2D(latitude: 61.2181, longitude: -149.9003),
            "America/Phoenix": CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740),
            "America/Detroit": CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458),
            "America/Miami": CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918),
            "America/Boston": CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589),
            "America/Seattle": CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321),
            "America/Indianapolis": CLLocationCoordinate2D(latitude: 39.7684, longitude: -86.1581),
            "America/Juneau": CLLocationCoordinate2D(latitude: 58.3019, longitude: -134.4197),
            "America/Nome": CLLocationCoordinate2D(latitude: 64.5011, longitude: -165.4064),
            "America/Adak": CLLocationCoordinate2D(latitude: 51.8800, longitude: -176.6581),
            "America/Yakutat": CLLocationCoordinate2D(latitude: 59.5469, longitude: -139.7272),
            "America/Sitka": CLLocationCoordinate2D(latitude: 57.0531, longitude: -135.3300),
            "America/Metlakatla": CLLocationCoordinate2D(latitude: 55.1291, longitude: -131.5721),
            
            // Americas - Mexico & Central America
            "America/Mexico_City": CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
            "America/Cancun": CLLocationCoordinate2D(latitude: 21.1619, longitude: -86.8515),
            "America/Tijuana": CLLocationCoordinate2D(latitude: 32.5149, longitude: -117.0382),
            "America/Monterrey": CLLocationCoordinate2D(latitude: 25.6866, longitude: -100.3161),
            "America/Mazatlan": CLLocationCoordinate2D(latitude: 23.2329, longitude: -106.4062),
            "America/Chihuahua": CLLocationCoordinate2D(latitude: 28.6353, longitude: -106.0889),
            "America/Hermosillo": CLLocationCoordinate2D(latitude: 29.0729, longitude: -110.9559),
            "America/Merida": CLLocationCoordinate2D(latitude: 20.9674, longitude: -89.5926),
            "America/Bahia_Banderas": CLLocationCoordinate2D(latitude: 20.8085, longitude: -105.2542),
            "America/Guatemala": CLLocationCoordinate2D(latitude: 14.6349, longitude: -90.5069),
            "America/Belize": CLLocationCoordinate2D(latitude: 17.5046, longitude: -88.1962),
            "America/El_Salvador": CLLocationCoordinate2D(latitude: 13.6929, longitude: -89.2182),
            "America/Tegucigalpa": CLLocationCoordinate2D(latitude: 14.0723, longitude: -87.1921),
            "America/Managua": CLLocationCoordinate2D(latitude: 12.1150, longitude: -86.2362),
            "America/Costa_Rica": CLLocationCoordinate2D(latitude: 9.9281, longitude: -84.0907),
            "America/Panama": CLLocationCoordinate2D(latitude: 8.9824, longitude: -79.5199),
            
            // Americas - Caribbean
            "America/Havana": CLLocationCoordinate2D(latitude: 23.1136, longitude: -82.3666),
            "America/Nassau": CLLocationCoordinate2D(latitude: 25.0480, longitude: -77.3554),
            "America/Jamaica": CLLocationCoordinate2D(latitude: 18.1096, longitude: -77.2975),
            "America/Port-au-Prince": CLLocationCoordinate2D(latitude: 18.5944, longitude: -72.3074),
            "America/Santo_Domingo": CLLocationCoordinate2D(latitude: 18.4861, longitude: -69.9312),
            "America/Puerto_Rico": CLLocationCoordinate2D(latitude: 18.2208, longitude: -66.5901),
            "America/Barbados": CLLocationCoordinate2D(latitude: 13.1939, longitude: -59.5432),
            "America/Martinique": CLLocationCoordinate2D(latitude: 14.6415, longitude: -61.0242),
            "America/Grand_Turk": CLLocationCoordinate2D(latitude: 21.4675, longitude: -71.1389),
            "America/Grenada": CLLocationCoordinate2D(latitude: 12.1165, longitude: -61.6790),
            "America/Guadeloupe": CLLocationCoordinate2D(latitude: 16.2650, longitude: -61.5510),
            "America/Aruba": CLLocationCoordinate2D(latitude: 12.5211, longitude: -69.9683),
            "America/Curacao": CLLocationCoordinate2D(latitude: 12.1696, longitude: -68.9900),
            
            // Americas - South America
            "America/Sao_Paulo": CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333),
            "America/Buenos_Aires": CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816),
            "America/Santiago": CLLocationCoordinate2D(latitude: -33.4489, longitude: -70.6693),
            "America/Lima": CLLocationCoordinate2D(latitude: -12.0464, longitude: -77.0428),
            "America/Bogota": CLLocationCoordinate2D(latitude: 4.7110, longitude: -74.0721),
            "America/Caracas": CLLocationCoordinate2D(latitude: 10.4806, longitude: -66.9036),
            "America/La_Paz": CLLocationCoordinate2D(latitude: -16.4897, longitude: -68.1193),
            "America/Asuncion": CLLocationCoordinate2D(latitude: -25.2637, longitude: -57.5759),
            "America/Montevideo": CLLocationCoordinate2D(latitude: -34.9011, longitude: -56.1645),
            "America/Guayaquil": CLLocationCoordinate2D(latitude: -2.1710, longitude: -79.9224),
            "America/Cayenne": CLLocationCoordinate2D(latitude: 4.9227, longitude: -52.3269),
            "America/Paramaribo": CLLocationCoordinate2D(latitude: 5.8520, longitude: -55.2038),
            "America/Guyana": CLLocationCoordinate2D(latitude: 6.8013, longitude: -58.1551),
            "America/Rio_Branco": CLLocationCoordinate2D(latitude: -9.9754, longitude: -67.8250),
            "America/Manaus": CLLocationCoordinate2D(latitude: -3.1190, longitude: -60.0217),
            "America/Fortaleza": CLLocationCoordinate2D(latitude: -3.7172, longitude: -38.5434),
            "America/Recife": CLLocationCoordinate2D(latitude: -8.0476, longitude: -34.8770),
            "America/Belem": CLLocationCoordinate2D(latitude: -1.4558, longitude: -48.4902),
            "America/Maceio": CLLocationCoordinate2D(latitude: -9.6658, longitude: -35.7353),
            "America/Bahia": CLLocationCoordinate2D(latitude: -12.9714, longitude: -38.5014),
            "America/Campo_Grande": CLLocationCoordinate2D(latitude: -20.4697, longitude: -54.6201),
            "America/Cuiaba": CLLocationCoordinate2D(latitude: -15.5989, longitude: -56.0949),
            "America/Porto_Velho": CLLocationCoordinate2D(latitude: -8.7612, longitude: -63.9039),
            "America/Boa_Vista": CLLocationCoordinate2D(latitude: 2.8197, longitude: -60.6733),
            "America/Santarem": CLLocationCoordinate2D(latitude: -2.4406, longitude: -54.7009),
            "America/Noronha": CLLocationCoordinate2D(latitude: -3.8538, longitude: -32.4240),
            "America/Argentina/Buenos_Aires": CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816),
            "America/Argentina/Cordoba": CLLocationCoordinate2D(latitude: -31.4201, longitude: -64.1888),
            "America/Argentina/Mendoza": CLLocationCoordinate2D(latitude: -32.8895, longitude: -68.8458),
            "America/Argentina/Ushuaia": CLLocationCoordinate2D(latitude: -54.8019, longitude: -68.3029),
            
            // Europe
            "Europe/London": CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            "Europe/Dublin": CLLocationCoordinate2D(latitude: 53.3498, longitude: -6.2603),
            "Europe/Belfast": CLLocationCoordinate2D(latitude: 54.5973, longitude: -5.9301),
            "Europe/Edinburgh": CLLocationCoordinate2D(latitude: 55.9533, longitude: -3.1883),
            "Europe/Isle_of_Man": CLLocationCoordinate2D(latitude: 54.2361, longitude: -4.5481),
            "Europe/Jersey": CLLocationCoordinate2D(latitude: 49.2144, longitude: -2.1313),
            "Europe/Guernsey": CLLocationCoordinate2D(latitude: 49.4657, longitude: -2.5853),
            "Europe/Paris": CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            "Europe/Berlin": CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
            "Europe/Madrid": CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
            "Europe/Rome": CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964),
            "Europe/Amsterdam": CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041),
            "Europe/Brussels": CLLocationCoordinate2D(latitude: 50.8503, longitude: 4.3517),
            "Europe/Vienna": CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            "Europe/Zurich": CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
            "Europe/Stockholm": CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
            "Europe/Oslo": CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
            "Europe/Copenhagen": CLLocationCoordinate2D(latitude: 55.6761, longitude: 12.5683),
            "Europe/Helsinki": CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384),
            "Europe/Tallinn": CLLocationCoordinate2D(latitude: 59.4370, longitude: 24.7536),
            "Europe/Riga": CLLocationCoordinate2D(latitude: 56.9496, longitude: 24.1052),
            "Europe/Vilnius": CLLocationCoordinate2D(latitude: 54.6872, longitude: 25.2797),
            "Europe/Warsaw": CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
            "Europe/Prague": CLLocationCoordinate2D(latitude: 50.0755, longitude: 14.4378),
            "Europe/Budapest": CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402),
            "Europe/Bratislava": CLLocationCoordinate2D(latitude: 48.1486, longitude: 17.1077),
            "Europe/Ljubljana": CLLocationCoordinate2D(latitude: 46.0569, longitude: 14.5058),
            "Europe/Zagreb": CLLocationCoordinate2D(latitude: 45.8150, longitude: 15.9819),
            "Europe/Belgrade": CLLocationCoordinate2D(latitude: 44.7866, longitude: 20.4489),
            "Europe/Sarajevo": CLLocationCoordinate2D(latitude: 43.8563, longitude: 18.4131),
            "Europe/Podgorica": CLLocationCoordinate2D(latitude: 42.4304, longitude: 19.2594),
            "Europe/Skopje": CLLocationCoordinate2D(latitude: 41.9973, longitude: 21.4280),
            "Europe/Tirana": CLLocationCoordinate2D(latitude: 41.3275, longitude: 19.8187),
            "Europe/Sofia": CLLocationCoordinate2D(latitude: 42.6977, longitude: 23.3219),
            "Europe/Bucharest": CLLocationCoordinate2D(latitude: 44.4268, longitude: 26.1025),
            "Europe/Chisinau": CLLocationCoordinate2D(latitude: 47.0105, longitude: 28.8638),
            "Europe/Kiev": CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234),
            "Europe/Minsk": CLLocationCoordinate2D(latitude: 53.9045, longitude: 27.5615),
            "Europe/Moscow": CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173),
            "Europe/Athens": CLLocationCoordinate2D(latitude: 37.9838, longitude: 23.7275),
            "Europe/Istanbul": CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
            "Europe/Lisbon": CLLocationCoordinate2D(latitude: 38.7223, longitude: -9.1393),
            "Europe/Luxembourg": CLLocationCoordinate2D(latitude: 49.6116, longitude: 6.1319),
            "Europe/Monaco": CLLocationCoordinate2D(latitude: 43.7384, longitude: 7.4246),
            "Europe/Malta": CLLocationCoordinate2D(latitude: 35.8989, longitude: 14.5146),
            "Europe/Andorra": CLLocationCoordinate2D(latitude: 42.5063, longitude: 1.5218),
            "Europe/Vatican": CLLocationCoordinate2D(latitude: 41.9029, longitude: 12.4534),
            "Europe/San_Marino": CLLocationCoordinate2D(latitude: 43.9424, longitude: 12.4578),
            "Europe/Vaduz": CLLocationCoordinate2D(latitude: 47.1410, longitude: 9.5209),
            "Europe/Reykjavik": CLLocationCoordinate2D(latitude: 64.1466, longitude: -21.9426),
            "Europe/Kaliningrad": CLLocationCoordinate2D(latitude: 54.7104, longitude: 20.4522),
            "Europe/Samara": CLLocationCoordinate2D(latitude: 53.2415, longitude: 50.2213),
            "Europe/Volgograd": CLLocationCoordinate2D(latitude: 48.7080, longitude: 44.5133),
            "Europe/Simferopol": CLLocationCoordinate2D(latitude: 44.9521, longitude: 34.1024),
            "Europe/Zaporozhye": CLLocationCoordinate2D(latitude: 47.8388, longitude: 35.1396),
            "Europe/Uzhgorod": CLLocationCoordinate2D(latitude: 48.6208, longitude: 22.2879),
            "Europe/Mariehamn": CLLocationCoordinate2D(latitude: 60.0969, longitude: 19.9348),
            "Europe/Gibraltar": CLLocationCoordinate2D(latitude: 36.1408, longitude: -5.3536),
            
            // Asia - Middle East
            "Asia/Dubai": CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708),
            "Asia/Abu_Dhabi": CLLocationCoordinate2D(latitude: 24.4539, longitude: 54.3773),
            "Asia/Riyadh": CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
            "Asia/Kuwait": CLLocationCoordinate2D(latitude: 29.3759, longitude: 47.9774),
            "Asia/Bahrain": CLLocationCoordinate2D(latitude: 26.2285, longitude: 50.5860),
            "Asia/Qatar": CLLocationCoordinate2D(latitude: 25.2854, longitude: 51.5310),
            "Asia/Muscat": CLLocationCoordinate2D(latitude: 23.5880, longitude: 58.3829),
            "Asia/Aden": CLLocationCoordinate2D(latitude: 12.7855, longitude: 45.0187),
            "Asia/Baghdad": CLLocationCoordinate2D(latitude: 33.3152, longitude: 44.3661),
            "Asia/Tehran": CLLocationCoordinate2D(latitude: 35.6892, longitude: 51.3890),
            "Asia/Jerusalem": CLLocationCoordinate2D(latitude: 31.7683, longitude: 35.2137),
            "Asia/Tel_Aviv": CLLocationCoordinate2D(latitude: 32.0853, longitude: 34.7818),
            "Asia/Beirut": CLLocationCoordinate2D(latitude: 33.8938, longitude: 35.5018),
            "Asia/Damascus": CLLocationCoordinate2D(latitude: 33.5138, longitude: 36.2765),
            "Asia/Amman": CLLocationCoordinate2D(latitude: 31.9454, longitude: 35.9284),
            "Asia/Nicosia": CLLocationCoordinate2D(latitude: 35.1856, longitude: 33.3823),
            "Asia/Ankara": CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597),
            "Asia/Yerevan": CLLocationCoordinate2D(latitude: 40.1792, longitude: 44.4991),
            "Asia/Tbilisi": CLLocationCoordinate2D(latitude: 41.7151, longitude: 44.8271),
            "Asia/Baku": CLLocationCoordinate2D(latitude: 40.4093, longitude: 49.8671),
            
            // Asia - South Asia
            "Asia/Karachi": CLLocationCoordinate2D(latitude: 24.8607, longitude: 67.0011),
            "Asia/Islamabad": CLLocationCoordinate2D(latitude: 33.7294, longitude: 73.0931),
            "Asia/Lahore": CLLocationCoordinate2D(latitude: 31.5497, longitude: 74.3436),
            "Asia/Mumbai": CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777),
            "Asia/Delhi": CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
            "Asia/Kolkata": CLLocationCoordinate2D(latitude: 22.5726, longitude: 88.3639),
            "Asia/Calcutta": CLLocationCoordinate2D(latitude: 22.5726, longitude: 88.3639),
            "Asia/Chennai": CLLocationCoordinate2D(latitude: 13.0827, longitude: 80.2707),
            "Asia/Bangalore": CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
            "Asia/Hyderabad": CLLocationCoordinate2D(latitude: 17.3850, longitude: 78.4867),
            "Asia/Dhaka": CLLocationCoordinate2D(latitude: 23.8103, longitude: 90.4125),
            "Asia/Colombo": CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
            "Asia/Kathmandu": CLLocationCoordinate2D(latitude: 27.7172, longitude: 85.3240),
            "Asia/Thimphu": CLLocationCoordinate2D(latitude: 27.4728, longitude: 89.6393),
            "Asia/Kabul": CLLocationCoordinate2D(latitude: 34.5553, longitude: 69.2075),
            
            // Asia - Southeast Asia
            "Asia/Bangkok": CLLocationCoordinate2D(latitude: 13.7563, longitude: 100.5018),
            "Asia/Yangon": CLLocationCoordinate2D(latitude: 16.8661, longitude: 96.1951),
            "Asia/Rangoon": CLLocationCoordinate2D(latitude: 16.8661, longitude: 96.1951),
            "Asia/Phnom_Penh": CLLocationCoordinate2D(latitude: 11.5564, longitude: 104.9282),
            "Asia/Vientiane": CLLocationCoordinate2D(latitude: 17.9757, longitude: 102.6331),
            "Asia/Ho_Chi_Minh": CLLocationCoordinate2D(latitude: 10.8231, longitude: 106.6297),
            "Asia/Saigon": CLLocationCoordinate2D(latitude: 10.8231, longitude: 106.6297),
            "Asia/Hanoi": CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542),
            "Asia/Singapore": CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),
            "Asia/Kuala_Lumpur": CLLocationCoordinate2D(latitude: 3.1390, longitude: 101.6869),
            "Asia/Kuching": CLLocationCoordinate2D(latitude: 1.5533, longitude: 110.3592),
            "Asia/Jakarta": CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
            "Asia/Pontianak": CLLocationCoordinate2D(latitude: -0.0263, longitude: 109.3425),
            "Asia/Makassar": CLLocationCoordinate2D(latitude: -5.1477, longitude: 119.4327),
            "Asia/Jayapura": CLLocationCoordinate2D(latitude: -2.5916, longitude: 140.6689),
            "Asia/Manila": CLLocationCoordinate2D(latitude: 14.5995, longitude: 120.9842),
            "Asia/Brunei": CLLocationCoordinate2D(latitude: 4.5353, longitude: 114.7277),
            "Asia/Dili": CLLocationCoordinate2D(latitude: -8.5569, longitude: 125.5603),
            
            // Asia - East Asia
            "Asia/Shanghai": CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            "Asia/Beijing": CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            "Asia/Chongqing": CLLocationCoordinate2D(latitude: 29.4316, longitude: 106.9123),
            "Asia/Harbin": CLLocationCoordinate2D(latitude: 45.8038, longitude: 126.5350),
            "Asia/Urumqi": CLLocationCoordinate2D(latitude: 43.8256, longitude: 87.6168),
            "Asia/Kashgar": CLLocationCoordinate2D(latitude: 39.4704, longitude: 75.9895),
            "Asia/Hong_Kong": CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
            "Asia/Macau": CLLocationCoordinate2D(latitude: 22.1987, longitude: 113.5439),
            "Asia/Taipei": CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
            "Asia/Tokyo": CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            "Asia/Osaka": CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023),
            "Asia/Sapporo": CLLocationCoordinate2D(latitude: 43.0642, longitude: 141.3469),
            "Asia/Seoul": CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
            "Asia/Pyongyang": CLLocationCoordinate2D(latitude: 39.0392, longitude: 125.7625),
            "Asia/Ulaanbaatar": CLLocationCoordinate2D(latitude: 47.8864, longitude: 106.9057),
            "Asia/Hovd": CLLocationCoordinate2D(latitude: 48.0052, longitude: 91.6419),
            "Asia/Choibalsan": CLLocationCoordinate2D(latitude: 48.0956, longitude: 114.5350),
            
            // Asia - Central Asia
            "Asia/Almaty": CLLocationCoordinate2D(latitude: 43.2220, longitude: 76.8512),
            "Asia/Qyzylorda": CLLocationCoordinate2D(latitude: 44.8479, longitude: 65.5090),
            "Asia/Aqtobe": CLLocationCoordinate2D(latitude: 50.2839, longitude: 57.1670),
            "Asia/Aqtau": CLLocationCoordinate2D(latitude: 43.6350, longitude: 51.1605),
            "Asia/Oral": CLLocationCoordinate2D(latitude: 51.2333, longitude: 51.3667),
            "Asia/Bishkek": CLLocationCoordinate2D(latitude: 42.8746, longitude: 74.5698),
            "Asia/Tashkent": CLLocationCoordinate2D(latitude: 41.2995, longitude: 69.2401),
            "Asia/Samarkand": CLLocationCoordinate2D(latitude: 39.6542, longitude: 66.9597),
            "Asia/Dushanbe": CLLocationCoordinate2D(latitude: 38.5358, longitude: 68.7791),
            "Asia/Ashgabat": CLLocationCoordinate2D(latitude: 37.9601, longitude: 58.3261),
            
            // Asia - Siberia & Russian Far East
            "Asia/Yekaterinburg": CLLocationCoordinate2D(latitude: 56.8389, longitude: 60.6057),
            "Asia/Omsk": CLLocationCoordinate2D(latitude: 54.9885, longitude: 73.3242),
            "Asia/Novosibirsk": CLLocationCoordinate2D(latitude: 55.0084, longitude: 82.9357),
            "Asia/Barnaul": CLLocationCoordinate2D(latitude: 53.3481, longitude: 83.7799),
            "Asia/Novokuznetsk": CLLocationCoordinate2D(latitude: 53.7557, longitude: 87.1099),
            "Asia/Krasnoyarsk": CLLocationCoordinate2D(latitude: 56.0153, longitude: 92.8932),
            "Asia/Irkutsk": CLLocationCoordinate2D(latitude: 52.2870, longitude: 104.3050),
            "Asia/Chita": CLLocationCoordinate2D(latitude: 52.0340, longitude: 113.5550),
            "Asia/Yakutsk": CLLocationCoordinate2D(latitude: 62.0355, longitude: 129.6755),
            "Asia/Khandyga": CLLocationCoordinate2D(latitude: 62.6564, longitude: 135.5540),
            "Asia/Vladivostok": CLLocationCoordinate2D(latitude: 43.1056, longitude: 131.8735),
            "Asia/Sakhalin": CLLocationCoordinate2D(latitude: 46.9651, longitude: 142.7360),
            "Asia/Ust-Nera": CLLocationCoordinate2D(latitude: 64.5603, longitude: 143.2270),
            "Asia/Magadan": CLLocationCoordinate2D(latitude: 59.5681, longitude: 150.8085),
            "Asia/Srednekolymsk": CLLocationCoordinate2D(latitude: 67.4645, longitude: 153.7075),
            "Asia/Kamchatka": CLLocationCoordinate2D(latitude: 53.0167, longitude: 158.6500),
            "Asia/Anadyr": CLLocationCoordinate2D(latitude: 64.7334, longitude: 177.4968),
            
            // Africa - North Africa
            "Africa/Cairo": CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357),
            "Africa/Alexandria": CLLocationCoordinate2D(latitude: 31.2001, longitude: 29.9187),
            "Africa/Tripoli": CLLocationCoordinate2D(latitude: 32.8872, longitude: 13.1913),
            "Africa/Tunis": CLLocationCoordinate2D(latitude: 36.8065, longitude: 10.1815),
            "Africa/Algiers": CLLocationCoordinate2D(latitude: 36.7538, longitude: 3.0588),
            "Africa/Casablanca": CLLocationCoordinate2D(latitude: 33.5731, longitude: -7.5898),
            "Africa/El_Aaiun": CLLocationCoordinate2D(latitude: 27.1536, longitude: -13.2033),
            "Africa/Khartoum": CLLocationCoordinate2D(latitude: 15.5007, longitude: 32.5599),
            "Africa/Juba": CLLocationCoordinate2D(latitude: 4.8517, longitude: 31.5825),
            
            // Africa - West Africa
            "Africa/Lagos": CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792),
            "Africa/Abuja": CLLocationCoordinate2D(latitude: 9.0765, longitude: 7.3986),
            "Africa/Accra": CLLocationCoordinate2D(latitude: 5.6037, longitude: -0.1870),
            "Africa/Dakar": CLLocationCoordinate2D(latitude: 14.7167, longitude: -17.4677),
            "Africa/Bamako": CLLocationCoordinate2D(latitude: 12.6392, longitude: -8.0029),
            "Africa/Ouagadougou": CLLocationCoordinate2D(latitude: 12.3714, longitude: -1.5197),
            "Africa/Abidjan": CLLocationCoordinate2D(latitude: 5.3600, longitude: -4.0083),
            "Africa/Conakry": CLLocationCoordinate2D(latitude: 9.6412, longitude: -13.5784),
            "Africa/Freetown": CLLocationCoordinate2D(latitude: 8.4657, longitude: -13.2317),
            "Africa/Monrovia": CLLocationCoordinate2D(latitude: 6.2907, longitude: -10.7605),
            "Africa/Bissau": CLLocationCoordinate2D(latitude: 11.8816, longitude: -15.6178),
            "Africa/Niamey": CLLocationCoordinate2D(latitude: 13.5127, longitude: 2.1126),
            "Africa/Nouakchott": CLLocationCoordinate2D(latitude: 18.0735, longitude: -15.9582),
            "Africa/Banjul": CLLocationCoordinate2D(latitude: 13.4549, longitude: -16.5790),
            
            // Africa - Central Africa
            "Africa/Kinshasa": CLLocationCoordinate2D(latitude: -4.4419, longitude: 15.2663),
            "Africa/Brazzaville": CLLocationCoordinate2D(latitude: -4.2634, longitude: 15.2429),
            "Africa/Bangui": CLLocationCoordinate2D(latitude: 4.3947, longitude: 18.5582),
            "Africa/Libreville": CLLocationCoordinate2D(latitude: 0.4162, longitude: 9.4673),
            "Africa/Malabo": CLLocationCoordinate2D(latitude: 3.7504, longitude: 8.7371),
            "Africa/Douala": CLLocationCoordinate2D(latitude: 4.0511, longitude: 9.7679),
            "Africa/Ndjamena": CLLocationCoordinate2D(latitude: 12.1348, longitude: 15.0557),
            "Africa/Sao_Tome": CLLocationCoordinate2D(latitude: 0.3365, longitude: 6.7313),
            
            // Africa - East Africa
            "Africa/Nairobi": CLLocationCoordinate2D(latitude: -1.2921, longitude: 36.8219),
            "Africa/Kampala": CLLocationCoordinate2D(latitude: 0.3476, longitude: 32.5825),
            "Africa/Kigali": CLLocationCoordinate2D(latitude: -1.9706, longitude: 30.1044),
            "Africa/Bujumbura": CLLocationCoordinate2D(latitude: -3.3731, longitude: 29.3599),
            "Africa/Dar_es_Salaam": CLLocationCoordinate2D(latitude: -6.7924, longitude: 39.2083),
            "Africa/Dodoma": CLLocationCoordinate2D(latitude: -6.1630, longitude: 35.7516),
            "Africa/Addis_Ababa": CLLocationCoordinate2D(latitude: 8.9806, longitude: 38.7578),
            "Africa/Asmara": CLLocationCoordinate2D(latitude: 15.3229, longitude: 38.9251),
            "Africa/Djibouti": CLLocationCoordinate2D(latitude: 11.8251, longitude: 42.5903),
            "Africa/Mogadishu": CLLocationCoordinate2D(latitude: 2.0469, longitude: 45.3182),
            
            // Africa - Southern Africa
            "Africa/Johannesburg": CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473),
            "Africa/Cape_Town": CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241),
            "Africa/Pretoria": CLLocationCoordinate2D(latitude: -25.7479, longitude: 28.2293),
            "Africa/Durban": CLLocationCoordinate2D(latitude: -29.8587, longitude: 31.0218),
            "Africa/Maputo": CLLocationCoordinate2D(latitude: -25.9692, longitude: 32.5732),
            "Africa/Lusaka": CLLocationCoordinate2D(latitude: -15.3875, longitude: 28.3228),
            "Africa/Harare": CLLocationCoordinate2D(latitude: -17.8252, longitude: 31.0335),
            "Africa/Gaborone": CLLocationCoordinate2D(latitude: -24.6282, longitude: 25.9231),
            "Africa/Windhoek": CLLocationCoordinate2D(latitude: -22.5609, longitude: 17.0658),
            "Africa/Luanda": CLLocationCoordinate2D(latitude: -8.8390, longitude: 13.2894),
            "Africa/Maseru": CLLocationCoordinate2D(latitude: -29.3167, longitude: 27.4833),
            "Africa/Mbabane": CLLocationCoordinate2D(latitude: -26.3054, longitude: 31.1367),
            "Africa/Lilongwe": CLLocationCoordinate2D(latitude: -13.9626, longitude: 33.7741),
            
            // Indian Ocean Islands
            "Indian/Antananarivo": CLLocationCoordinate2D(latitude: -18.8792, longitude: 47.5079),
            "Indian/Mauritius": CLLocationCoordinate2D(latitude: -20.3484, longitude: 57.5522),
            "Indian/Reunion": CLLocationCoordinate2D(latitude: -21.1151, longitude: 55.5364),
            "Indian/Mayotte": CLLocationCoordinate2D(latitude: -12.8275, longitude: 45.1662),
            "Indian/Comoro": CLLocationCoordinate2D(latitude: -11.6455, longitude: 43.3333),
            "Indian/Mahe": CLLocationCoordinate2D(latitude: -4.6827, longitude: 55.4920),
            "Indian/Maldives": CLLocationCoordinate2D(latitude: 3.2028, longitude: 73.2207),
            "Indian/Chagos": CLLocationCoordinate2D(latitude: -6.3434, longitude: 71.8765),
            
            // Oceania - Australia & New Zealand
            "Australia/Sydney": CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
            "Australia/Melbourne": CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),
            "Australia/Brisbane": CLLocationCoordinate2D(latitude: -27.4698, longitude: 153.0251),
            "Australia/Perth": CLLocationCoordinate2D(latitude: -31.9505, longitude: 115.8605),
            "Australia/Adelaide": CLLocationCoordinate2D(latitude: -34.9285, longitude: 138.6007),
            "Australia/Hobart": CLLocationCoordinate2D(latitude: -42.8821, longitude: 147.3272),
            "Australia/Darwin": CLLocationCoordinate2D(latitude: -12.4634, longitude: 130.8456),
            "Australia/Canberra": CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
            "Australia/Lord_Howe": CLLocationCoordinate2D(latitude: -31.5567, longitude: 159.0860),
            "Australia/Broken_Hill": CLLocationCoordinate2D(latitude: -31.9539, longitude: 141.4539),
            "Australia/Eucla": CLLocationCoordinate2D(latitude: -31.6817, longitude: 128.8898),
            "Australia/Lindeman": CLLocationCoordinate2D(latitude: -20.4500, longitude: 149.0333),
            "Australia/Currie": CLLocationCoordinate2D(latitude: -39.9333, longitude: 143.8667),
            "Pacific/Auckland": CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633),
            "Pacific/Chatham": CLLocationCoordinate2D(latitude: -43.9500, longitude: -176.5667),
            
            // Pacific Islands
            "Pacific/Fiji": CLLocationCoordinate2D(latitude: -18.1416, longitude: 178.4419),
            "Pacific/Tongatapu": CLLocationCoordinate2D(latitude: -21.1790, longitude: -175.1982),
            "Pacific/Apia": CLLocationCoordinate2D(latitude: -13.8507, longitude: -171.7514),
            "Pacific/Pago_Pago": CLLocationCoordinate2D(latitude: -14.2781, longitude: -170.7025),
            "Pacific/Port_Moresby": CLLocationCoordinate2D(latitude: -9.4438, longitude: 147.1803),
            "Pacific/Honiara": CLLocationCoordinate2D(latitude: -9.4456, longitude: 159.9729),
            "Pacific/Noumea": CLLocationCoordinate2D(latitude: -22.2763, longitude: 166.4572),
            "Pacific/Efate": CLLocationCoordinate2D(latitude: -17.7338, longitude: 168.3273),
            "Pacific/Norfolk": CLLocationCoordinate2D(latitude: -29.0408, longitude: 167.9547),
            "Pacific/Tarawa": CLLocationCoordinate2D(latitude: 1.3278, longitude: 172.9781),
            "Pacific/Majuro": CLLocationCoordinate2D(latitude: 7.1315, longitude: 171.1845),
            "Pacific/Nauru": CLLocationCoordinate2D(latitude: -0.5477, longitude: 166.9209),
            "Pacific/Funafuti": CLLocationCoordinate2D(latitude: -8.5243, longitude: 179.1942),
            "Pacific/Guadalcanal": CLLocationCoordinate2D(latitude: -9.6100, longitude: 160.1500),
            "Pacific/Rarotonga": CLLocationCoordinate2D(latitude: -21.2329, longitude: -159.7777),
            "Pacific/Niue": CLLocationCoordinate2D(latitude: -19.0544, longitude: -169.8672),
            "Pacific/Tahiti": CLLocationCoordinate2D(latitude: -17.6509, longitude: -149.4260),
            "Pacific/Marquesas": CLLocationCoordinate2D(latitude: -9.0000, longitude: -139.5000),
            "Pacific/Gambier": CLLocationCoordinate2D(latitude: -23.1000, longitude: -134.9500),
            "Pacific/Pitcairn": CLLocationCoordinate2D(latitude: -25.0667, longitude: -130.1000),
            "Pacific/Easter": CLLocationCoordinate2D(latitude: -27.1127, longitude: -109.3497),
            "Pacific/Honolulu": CLLocationCoordinate2D(latitude: 21.3099, longitude: -157.8581),
            "Pacific/Midway": CLLocationCoordinate2D(latitude: 28.2072, longitude: -177.3735),
            "Pacific/Wake": CLLocationCoordinate2D(latitude: 19.2965, longitude: 166.6284),
            "Pacific/Guam": CLLocationCoordinate2D(latitude: 13.4443, longitude: 144.7937),
            "Pacific/Saipan": CLLocationCoordinate2D(latitude: 15.0979, longitude: 145.6739),
            "Pacific/Palau": CLLocationCoordinate2D(latitude: 7.5150, longitude: 134.5825),
            "Pacific/Chuuk": CLLocationCoordinate2D(latitude: 7.4464, longitude: 151.7837),
            "Pacific/Pohnpei": CLLocationCoordinate2D(latitude: 6.8874, longitude: 158.2150),
            "Pacific/Kosrae": CLLocationCoordinate2D(latitude: 5.3169, longitude: 162.9814),
            "Pacific/Kiritimati": CLLocationCoordinate2D(latitude: 1.8721, longitude: -157.3626),
            "Pacific/Enderbury": CLLocationCoordinate2D(latitude: -3.1333, longitude: -171.0833),
            "Pacific/Fakaofo": CLLocationCoordinate2D(latitude: -9.3651, longitude: -171.2468),
            "Pacific/Johnston": CLLocationCoordinate2D(latitude: 16.7295, longitude: -169.5332),
            "Pacific/Wallis": CLLocationCoordinate2D(latitude: -13.3000, longitude: -176.1667),
            
            // Atlantic Islands
            "Atlantic/Bermuda": CLLocationCoordinate2D(latitude: 32.3078, longitude: -64.7505),
            "Atlantic/Azores": CLLocationCoordinate2D(latitude: 37.7412, longitude: -25.6756),
            "Atlantic/Madeira": CLLocationCoordinate2D(latitude: 32.6669, longitude: -16.9241),
            "Atlantic/Canary": CLLocationCoordinate2D(latitude: 28.1235, longitude: -15.4363),
            "Atlantic/Cape_Verde": CLLocationCoordinate2D(latitude: 16.0021, longitude: -24.0133),
            "Atlantic/Stanley": CLLocationCoordinate2D(latitude: -51.6938, longitude: -57.8570),
            "Atlantic/South_Georgia": CLLocationCoordinate2D(latitude: -54.2806, longitude: -36.5080),
            "Atlantic/St_Helena": CLLocationCoordinate2D(latitude: -15.9387, longitude: -5.7168),
            "Atlantic/Faroe": CLLocationCoordinate2D(latitude: 62.0079, longitude: -6.7906),
            "Atlantic/Reykjavik": CLLocationCoordinate2D(latitude: 64.1466, longitude: -21.9426),
            
            // Antarctica
            "Antarctica/McMurdo": CLLocationCoordinate2D(latitude: -77.8500, longitude: 166.6667),
            "Antarctica/South_Pole": CLLocationCoordinate2D(latitude: -90.0000, longitude: 0.0000),
            "Antarctica/Rothera": CLLocationCoordinate2D(latitude: -67.5681, longitude: -68.1306),
            "Antarctica/Palmer": CLLocationCoordinate2D(latitude: -64.7742, longitude: -64.0542),
            "Antarctica/Mawson": CLLocationCoordinate2D(latitude: -67.6028, longitude: 62.8731),
            "Antarctica/Davis": CLLocationCoordinate2D(latitude: -68.5764, longitude: 77.9689),
            "Antarctica/Casey": CLLocationCoordinate2D(latitude: -66.2833, longitude: 110.5167),
            "Antarctica/Vostok": CLLocationCoordinate2D(latitude: -78.4642, longitude: 106.8364),
            "Antarctica/Syowa": CLLocationCoordinate2D(latitude: -69.0072, longitude: 39.5900),
            "Antarctica/DumontDUrville": CLLocationCoordinate2D(latitude: -66.6633, longitude: 140.0019),
            "Antarctica/Macquarie": CLLocationCoordinate2D(latitude: -54.4997, longitude: 158.9369),
            "Antarctica/Troll": CLLocationCoordinate2D(latitude: -72.0117, longitude: 2.5350),
            
            // Special/Other Time Zones
            "UTC": CLLocationCoordinate2D(latitude: 51.4769, longitude: -0.0005),
            "GMT": CLLocationCoordinate2D(latitude: 51.4769, longitude: -0.0005),
            "Etc/GMT": CLLocationCoordinate2D(latitude: 51.4769, longitude: -0.0005),
            "Etc/UTC": CLLocationCoordinate2D(latitude: 51.4769, longitude: -0.0005)
        ]
        
        return cityCoordinates[timeZoneIdentifier]
    }
    
    // Start the timer
    func startTimer() {
        // Immediately update the current date
        currentDate = Date()
        
        // Cancel any existing timer
        timerCancellable?.cancel()
        
        // Create a new timer
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentDate = Date()
            }
    }
    
    // Stop the timer
    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position, bounds: cameraBounds) {
                // Show world clock markers
                ForEach(worldClocks) { clock in
                    if let coordinate = getCoordinate(for: clock.timeZoneIdentifier) {
                        Annotation(clock.cityName, coordinate: coordinate) {
                            
                            VStack(spacing: 6) {
                                // Time bubble with SkyDot
                                HStack(spacing: 8) {
                                    if showSkyDot {
                                        SkyDotView(
                                            date: currentDate,
                                            timeZoneIdentifier: clock.timeZoneIdentifier
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                .blendMode(.plusLighter)
                                        )
                                        .transition(.blurReplace)
                                    }
                                    
                                    Text({
                                        let formatter = DateFormatter()
                                        formatter.timeZone = TimeZone(identifier: clock.timeZoneIdentifier)
                                        formatter.locale = Locale(identifier: "en_US_POSIX")
                                        if use24HourFormat {
                                            formatter.dateFormat = "HH:mm"
                                        } else {
                                            formatter.dateFormat = "h:mma"
                                        }
                                        return formatter.string(from: currentDate).lowercased()
                                    }())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .animation(.spring(), value: currentDate)
                        
                                }
                                .animation(.spring(), value: showSkyDot)
                                .padding(.leading, showSkyDot ? 4 : 8)
                                .padding(.trailing, 8)
                                .padding(.vertical, 4)
                                .clipShape(Capsule())
                                .glassEffect(.clear.interactive())
                            }
                        }
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls {
                MapScaleView()
            }
        }
            .navigationTitle("Touch Time")
            .navigationBarTitleDisplayMode(.inline)
            
        .animation(.spring(), value: worldClocks)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Hide share button when no cities
                    if !worldClocks.isEmpty {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSettingsSheet = true
                    }) {
                        Image(systemName: "gear")
                            .frame(width: 24)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareCitiesSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showShareSheet,
                    currentDate: currentDate,
                    timeOffset: 0
                )
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(worldClocks: $worldClocks)
            }
        }
    }  
}