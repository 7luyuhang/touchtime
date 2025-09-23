//
//  WorldClock.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import Foundation

struct WorldClock: Identifiable, Codable, Equatable {
    let id: UUID
    let cityName: String
    let timeZoneIdentifier: String
    
    init(cityName: String, timeZoneIdentifier: String) {
        self.id = UUID()
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
    }
    
    // 实现 Equatable 协议用于比较
    static func == (lhs: WorldClock, rhs: WorldClock) -> Bool {
        return lhs.id == rhs.id
    }
    
    func currentTime(use24Hour: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX") // 确保时间格式不受系统区域设置影响
        
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        
        return formatter.string(from: Date())
    }
    
    var timeDifference: String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier),
              let localTimeZone = TimeZone.current as TimeZone? else {
            return ""
        }
        
        let difference = (targetTimeZone.secondsFromGMT() - localTimeZone.secondsFromGMT()) / 3600
        
        if difference == 0 {
            return ""
        } else if difference > 0 {
            return "+\(difference) hrs"
        } else {
            return "\(difference) hrs"
        }
    }
    
    func currentDate() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX") // 保持一致的区域设置
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: Date())
    }
}

// Default world clocks data
struct WorldClockData {
    static let defaultClocks: [WorldClock] = [
        WorldClock(cityName: "San Francisco", timeZoneIdentifier: "America/Los_Angeles"),
        WorldClock(cityName: "New York", timeZoneIdentifier: "America/New_York"),
        WorldClock(cityName: "London", timeZoneIdentifier: "Europe/London"),
        WorldClock(cityName: "Paris", timeZoneIdentifier: "Europe/Paris"),
        WorldClock(cityName: "Tokyo", timeZoneIdentifier: "Asia/Tokyo"),
        WorldClock(cityName: "Sydney", timeZoneIdentifier: "Australia/Sydney"),
        WorldClock(cityName: "Beijing", timeZoneIdentifier: "Asia/Shanghai"),
        WorldClock(cityName: "Dubai", timeZoneIdentifier: "Asia/Dubai"),
        WorldClock(cityName: "Moscow", timeZoneIdentifier: "Europe/Moscow"),
        WorldClock(cityName: "Singapore", timeZoneIdentifier: "Asia/Singapore")
    ]
}
