//
//  TimeZonePickerView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI

struct TimeZonePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var worldClocks: [WorldClock]
    @State private var searchText = ""
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    
    // 获取所有时区并创建城市名称和国家/地区信息
    var availableTimeZones: [(cityName: String, region: String, identifier: String)] {
        TimeZone.knownTimeZoneIdentifiers.compactMap { identifier in
            // 从时区标识符中提取城市名称和地区信息
            let components = identifier.split(separator: "/")
            if components.count >= 2 {
                // 替换下划线为空格，让名称更易读
                let cityName = components.last!
                    .replacingOccurrences(of: "_", with: " ")
                
                // 获取地区/国家信息
                let region = getRegionForTimeZone(identifier: identifier)
                
                return (cityName: cityName, region: region, identifier: identifier)
            } else if components.count == 1 {
                // 处理没有斜杠的时区（如 UTC, GMT）
                return (cityName: String(components[0]), region: "Standard Time", identifier: identifier)
            }
            return nil
        }
        .sorted { $0.cityName < $1.cityName }
    }
    
    // 获取时区对应的国家/地区名称
    func getRegionForTimeZone(identifier: String) -> String {
        let components = identifier.split(separator: "/")
        
        // 处理有国家信息的时区 (如 America/Argentina/Buenos_Aires)
        if components.count >= 3 {
            let country = String(components[1]).replacingOccurrences(of: "_", with: " ")
            
            // 特殊处理一些国家名称
            switch country {
            case "Indiana", "Kentucky", "North Dakota": return "United States"
            default: return country
            }
        }
        
        // 根据时区标识符直接映射国家
        switch identifier {
        // 美国
        case let id where id.starts(with: "America/") && 
            ["New_York", "Chicago", "Denver", "Los_Angeles", "Phoenix", "Anchorage", "Honolulu", "Detroit", "Indianapolis"].contains(where: { id.contains($0) }):
            return "United States"
            
        // 加拿大
        case let id where id.starts(with: "America/") &&
            ["Toronto", "Vancouver", "Montreal", "Edmonton", "Winnipeg", "Halifax", "St_Johns", "Regina"].contains(where: { id.contains($0) }):
            return "Canada"
            
        // 中国
        case "Asia/Shanghai", "Asia/Urumqi", "Asia/Harbin", "Asia/Chongqing":
            return "China"
            
        // 日本
        case "Asia/Tokyo":
            return "Japan"
            
        // 韩国
        case "Asia/Seoul":
            return "South Korea"
            
        // 印度
        case "Asia/Kolkata", "Asia/Calcutta":
            return "India"
            
        // 澳大利亚
        case let id where id.starts(with: "Australia/"):
            return "Australia"
            
        // 英国
        case "Europe/London", "Europe/Belfast":
            return "United Kingdom"
            
        // 法国
        case "Europe/Paris":
            return "France"
            
        // 德国
        case "Europe/Berlin":
            return "Germany"
            
        // 俄罗斯
        case let id where id.starts(with: "Europe/") &&
            ["Moscow", "Kaliningrad", "Samara", "Volgograd"].contains(where: { id.contains($0) }):
            return "Russia"
            
        // 巴西
        case let id where id.starts(with: "America/") && id.contains("Brazil"):
            return "Brazil"
            
        // 墨西哥
        case let id where id.starts(with: "America/") && 
            ["Mexico_City", "Cancun", "Tijuana", "Monterrey"].contains(where: { id.contains($0) }):
            return "Mexico"
            
        // 新加坡
        case "Asia/Singapore":
            return "Singapore"
            
        // 香港
        case "Asia/Hong_Kong":
            return "Hong Kong"
            
        // 台北
        case "Asia/Taipei":
            return "Taiwan"
            
        // 迪拜
        case "Asia/Dubai":
            return "United Arab Emirates"
            
        // 其他主要城市
        case "Europe/Rome": return "Italy"
        case "Europe/Madrid": return "Spain"
        case "Europe/Amsterdam": return "Netherlands"
        case "Europe/Brussels": return "Belgium"
        case "Europe/Zurich": return "Switzerland"
        case "Europe/Stockholm": return "Sweden"
        case "Europe/Oslo": return "Norway"
        case "Europe/Copenhagen": return "Denmark"
        case "Europe/Helsinki": return "Finland"
        case "Europe/Vienna": return "Austria"
        case "Europe/Prague": return "Czech Republic"
        case "Europe/Warsaw": return "Poland"
        case "Europe/Athens": return "Greece"
        case "Europe/Lisbon": return "Portugal"
        case "Europe/Dublin": return "Ireland"
        case "Asia/Bangkok": return "Thailand"
        case "Asia/Jakarta": return "Indonesia"
        case "Asia/Manila": return "Philippines"
        case "Asia/Kuala_Lumpur": return "Malaysia"
        case "Asia/Ho_Chi_Minh": return "Vietnam"
        case "Asia/Yangon": return "Myanmar"
        case "Asia/Dhaka": return "Bangladesh"
        case "Asia/Karachi": return "Pakistan"
        case "Asia/Tehran": return "Iran"
        case "Asia/Baghdad": return "Iraq"
        case "Asia/Jerusalem": return "Israel"
        case "Asia/Beirut": return "Lebanon"
        case "Asia/Amman": return "Jordan"
        case "Asia/Riyadh": return "Saudi Arabia"
        case "Africa/Cairo": return "Egypt"
        case "Africa/Lagos": return "Nigeria"
        case "Africa/Johannesburg": return "South Africa"
        case "Africa/Nairobi": return "Kenya"
        case "Africa/Casablanca": return "Morocco"
        case "Pacific/Auckland": return "New Zealand"
        case "Pacific/Fiji": return "Fiji"
        case "America/Buenos_Aires": return "Argentina"
        case "America/Santiago": return "Chile"
        case "America/Lima": return "Peru"
        case "America/Bogota": return "Colombia"
        case "America/Caracas": return "Venezuela"
        case "America/Panama": return "Panama"
        case "America/Guatemala": return "Guatemala"
        case "America/Havana": return "Cuba"
        case "America/Jamaica": return "Jamaica"
            
        // 其他情况，返回大洲名称
        default:
            if components.count >= 1 {
                let continent = String(components[0])
                switch continent {
                case "Africa": return "Africa"
                case "America": return "Americas"
                case "Antarctica": return "Antarctica"
                case "Arctic": return "Arctic"
                case "Asia": return "Asia"
                case "Atlantic": return "Atlantic Ocean"
                case "Australia": return "Australia"
                case "Europe": return "Europe"
                case "Indian": return "Indian Ocean"
                case "Pacific": return "Pacific Ocean"
                default: return continent
                }
            }
            return "Unknown"
        }
    }
    
    // 过滤搜索结果
    var filteredTimeZones: [(cityName: String, region: String, identifier: String)] {
        if searchText.isEmpty {
            return availableTimeZones
        } else {
            return availableTimeZones.filter { 
                $0.cityName.localizedCaseInsensitiveContains(searchText) ||
                $0.region.localizedCaseInsensitiveContains(searchText) ||
                $0.identifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 将时区按首字母分组
    var groupedTimeZones: [String: [(cityName: String, region: String, identifier: String)]] {
        Dictionary(grouping: filteredTimeZones) { timeZone in
            let firstChar = timeZone.cityName.prefix(1).uppercased()
            // 确保是字母，否则归类到 "#"
            if firstChar.rangeOfCharacter(from: .letters) != nil {
                return firstChar
            } else {
                return "#"
            }
        }
    }
    
    // 获取排序后的分组键
    var sortedKeys: [String] {
        groupedTimeZones.keys.sorted { key1, key2 in
            // "#" 符号排在最后
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if filteredTimeZones.isEmpty {
                    // Empty state when no search results
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(sortedKeys, id: \.self) { key in
                            Section(header: Text(key)
                                .font(.headline)
                                .foregroundStyle(.secondary)) {
                                    
                                ForEach(groupedTimeZones[key] ?? [], id: \.identifier) { timeZone in
                                    Button(action: {
                                        addClock(cityName: timeZone.cityName, identifier: timeZone.identifier)
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(timeZone.cityName)
    
                                                Text(timeZone.region)
                                                    .foregroundStyle(.secondary)
                                                    .font(.subheadline)
                                            }
                                            Spacer()
                                            // 显示当前时间预览
                                            if let tz = TimeZone(identifier: timeZone.identifier) {
                                                Text(currentTime(for: tz))
                                                    .foregroundStyle(.secondary)
                                                    .monospacedDigit()
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search")
            // Title
            .navigationTitle("Choose a City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
    
    // 添加时钟
    func addClock(cityName: String, identifier: String) {
        let newClock = WorldClock(cityName: cityName, timeZoneIdentifier: identifier)
        
        // 检查是否已存在相同的时区
        if !worldClocks.contains(where: { $0.timeZoneIdentifier == identifier }) {
            worldClocks.append(newClock)
        }
        
        dismiss()
    }
    
    // 获取时区的当前时间（用于预览）
    func currentTime(for timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX") // 确保时间格式一致
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
        }
        return formatter.string(from: Date())
    }
}

#Preview {
    TimeZonePickerView(worldClocks: .constant(WorldClockData.defaultClocks))
}
