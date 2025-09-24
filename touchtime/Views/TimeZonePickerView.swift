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
    
    // 获取所有时区并创建城市名称
    var availableTimeZones: [(cityName: String, identifier: String)] {
        TimeZone.knownTimeZoneIdentifiers.compactMap { identifier in
            // 从时区标识符中提取城市名称
            let components = identifier.split(separator: "/")
            if components.count >= 2 {
                // 替换下划线为空格，让名称更易读
                let cityName = components.last!
                    .replacingOccurrences(of: "_", with: " ")
                return (cityName: cityName, identifier: identifier)
            } else if components.count == 1 {
                // 处理没有斜杠的时区（如 UTC, GMT）
                return (cityName: String(components[0]), identifier: identifier)
            }
            return nil
        }
        .sorted { $0.cityName < $1.cityName }
    }
    
    // 过滤搜索结果
    var filteredTimeZones: [(cityName: String, identifier: String)] {
        if searchText.isEmpty {
            return availableTimeZones
        } else {
            return availableTimeZones.filter { 
                $0.cityName.localizedCaseInsensitiveContains(searchText) ||
                $0.identifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 将时区按首字母分组
    var groupedTimeZones: [String: [(cityName: String, identifier: String)]] {
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
                                .foregroundColor(.secondary)) {
                                ForEach(groupedTimeZones[key] ?? [], id: \.identifier) { timeZone in
                                    Button(action: {
                                        addClock(cityName: timeZone.cityName, identifier: timeZone.identifier)
                                    }) {
                                        HStack {
                                                Text(timeZone.cityName)
                                                    .foregroundColor(.primary)
                                            Spacer()
                                            // 显示当前时间预览
                                            if let tz = TimeZone(identifier: timeZone.identifier) {
                                                Text(currentTime(for: tz))
                                                    .foregroundColor(.secondary)
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
            .navigationTitle("Choose a City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
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
