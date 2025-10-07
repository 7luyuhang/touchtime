//
//  WorldClock.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import Foundation

struct WorldClock: Identifiable, Codable, Equatable {
    let id: UUID
    var cityName: String
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
    
    func currentTime(use24Hour: Bool = false, offset: TimeInterval = 0) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX") // 确保时间格式不受系统区域设置影响
        
        if use24Hour {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        
        let adjustedDate = Date().addingTimeInterval(offset)
        return formatter.string(from: adjustedDate)
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
            return "+\(difference)h"
        } else {
            return "\(difference)h"
        }
    }
    
    func currentDate(baseDate: Date = Date(), offset: TimeInterval = 0) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return ""
        }
        
        // The adjusted time for the target timezone
        let adjustedTime = baseDate.addingTimeInterval(offset)
        
        // 创建用于本地时区的日历
        let localCalendar = Calendar.current
        
        // 创建用于目标时区的日历
        var targetCalendar = Calendar.current
        targetCalendar.timeZone = targetTimeZone
        
        // 获取本地时区的今天（基于原始 baseDate，不加 offset）
        let localToday = localCalendar.dateComponents([.year, .month, .day], from: baseDate)
        
        // 获取目标时区的日期（基于调整后的时间）
        let targetDate = targetCalendar.dateComponents([.year, .month, .day], from: adjustedTime)
        
        // 如果目标时区的日期与本地的今天相同，显示 "Today"
        if targetDate.year == localToday.year &&
           targetDate.month == localToday.month &&
           targetDate.day == localToday.day {
            return "Today"
        } else {
            // 检查是否是明天（基于原始 baseDate 计算）
            if let tomorrow = localCalendar.date(byAdding: .day, value: 1, to: baseDate) {
                let localTomorrow = localCalendar.dateComponents([.year, .month, .day], from: tomorrow)
                if targetDate.year == localTomorrow.year &&
                   targetDate.month == localTomorrow.month &&
                   targetDate.day == localTomorrow.day {
                    return "Tomorrow"
                }
            }
            
            // 检查是否是昨天（基于原始 baseDate 计算）
            if let yesterday = localCalendar.date(byAdding: .day, value: -1, to: baseDate) {
                let localYesterday = localCalendar.dateComponents([.year, .month, .day], from: yesterday)
                if targetDate.year == localYesterday.year &&
                   targetDate.month == localYesterday.month &&
                   targetDate.day == localYesterday.day {
                    return "Yesterday"
                }
            }
            
            // 否则显示具体日期
            let formatter = DateFormatter()
            formatter.timeZone = targetTimeZone
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            
            return formatter.string(from: adjustedTime)
        }
    }
}

// Default world clocks data
struct WorldClockData {
    static let defaultClocks: [WorldClock] = [
        WorldClock(cityName: "London", timeZoneIdentifier: "Europe/London"),
        WorldClock(cityName: "Shanghai", timeZoneIdentifier: "Asia/Shanghai"),
        WorldClock(cityName: "Tokyo", timeZoneIdentifier: "Asia/Tokyo"),
        WorldClock(cityName: "Los Angeles", timeZoneIdentifier: "America/Los_Angeles"),
        WorldClock(cityName: "New York", timeZoneIdentifier: "America/New_York"),
        WorldClock(cityName: "Sydney", timeZoneIdentifier: "Australia/Sydney")
    ]
}
