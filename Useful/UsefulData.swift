//
//  UsefulData.swift
//  Useful
//
//  Created by Andrew Gibiansky on 1/1/23.
//

import SwiftUI
import Foundation

struct UsefulSettings: Codable {
    // How many minutes to stretch per day.
    var stretchingMinutesPerDay: Int = 5
    
    // How many minutes to practice skills per day.
    var practiceMinutesPerDay: Int = 5
    
    // How many calories today.
    var caloriesToday: Int = 0
    
    init() { }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Required field
        stretchingMinutesPerDay = try values.decode(Int.self, forKey: .stretchingMinutesPerDay)
        
        // Optional field
        practiceMinutesPerDay = try values.decodeIfPresent(Int.self, forKey: .practiceMinutesPerDay) ?? 1
        caloriesToday = try values.decodeIfPresent(Int.self, forKey: .caloriesToday) ?? 0
    }
}

enum UsefulAction: Codable {
    // Stretch for a given number of seconds
    case stretch(Int)
    
    // Practice skills for a given number of seconds
    case practice(Int)
}

struct UsefulState: Codable {
    // How many seconds are remaining to stretch
    var stretchingSecondsRemaining: Int = 0
    
    // How many seconds are remaining to stretch
    var practiceSecondsRemaining: Int = 0
    
    // When was the last time the app updated
    var lastUpdateDay: DateComponents? = nil
    
    init() { }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Required field
        stretchingSecondsRemaining = try values.decode(Int.self, forKey: .stretchingSecondsRemaining)
        lastUpdateDay = try values.decode(DateComponents?.self, forKey: .lastUpdateDay)
        
        // Optional field
        practiceSecondsRemaining = try values.decodeIfPresent(Int.self, forKey: .practiceSecondsRemaining) ?? 0
    }
}

struct DailyTimeLog: Identifiable {
    let date: Date
    let minutes: Double
    var id = UUID()
    
    init(_ date: Date, _ minutes: Double) {
        self.date = date
        self.minutes = minutes
    }
}

class UsefulData: Codable {
    // Current app settings
    var settings: UsefulSettings = UsefulSettings()
    
    // Current app state
    var current: UsefulState = UsefulState()
    
    // All logged actions
    var actions: [DateComponents: [UsefulAction]] = [:]
    
    static func currentYearMonthDay() -> DateComponents {
        let calendar = Calendar.autoupdatingCurrent
        let yearMonthDay = calendar.dateComponents([.year, .month, .day], from: Date.now)
        return yearMonthDay
    }
    
    func update() {
        // Compute normalized dates for start and end
        let calendar = Calendar(identifier: .gregorian)
        let currentDay = UsefulData.currentYearMonthDay()
        if current.lastUpdateDay == currentDay {
            return
        }
        
        let lastUpdateDay = current.lastUpdateDay ?? currentDay
        let lastUpdateDate = calendar.date(from: lastUpdateDay)!
        let todayDate = calendar.date(from: UsefulData.currentYearMonthDay())!
        
        // Find number of days that have elapsed
        let intervalSeconds = Int(lastUpdateDate.distance(to: todayDate))
        let intervalDays = intervalSeconds / (24 * 60 * 60)
        
        // Update the data using the elapsed days
        current.stretchingSecondsRemaining += intervalDays * settings.stretchingMinutesPerDay * 60
        current.practiceSecondsRemaining += intervalDays * settings.practiceMinutesPerDay * 60
        current.lastUpdateDay = UsefulData.currentYearMonthDay()
        
        // Reset calories if it's a new day
        if intervalDays > 0 {
            settings.caloriesToday = 0
        }
    }
    
    func minutesOverTime() -> ([DailyTimeLog], [DailyTimeLog]) {
        let calendar = Calendar.autoupdatingCurrent
        
        // Allow for testing with a toggle
        let realMode = true
        let selectedActions = realMode ? actions : [
            DateComponents(year: 2022, month: 10, day: 13): [UsefulAction.stretch(130), UsefulAction.stretch(130), UsefulAction.stretch(130)],
            DateComponents(year: 2022, month: 12, day: 13): [UsefulAction.stretch(130), UsefulAction.stretch(130), UsefulAction.stretch(130)],
            DateComponents(year: 2022, month: 12, day: 14): [UsefulAction.stretch(130)],
            DateComponents(year: 2022, month: 12, day: 17): [UsefulAction.stretch(130), UsefulAction.stretch(130)],
            DateComponents(year: 2022, month: 12, day: 31): [UsefulAction.stretch(300)],
        ]
        
        if selectedActions.isEmpty {
            return ([], [])
        }
        
        // Get the first and last dates
        let minComponent = selectedActions.min() {
            a, b in
            let aDate = calendar.date(from: a.key)!
            let bDate = calendar.date(from: b.key)!
            return aDate < bDate
        }!.key
        
        // Make a list of all dates between them
        var date = calendar.date(from: minComponent)!
        let endDate = Date.now
        var allComponents: [DateComponents] = []
        while date <= endDate {
            allComponents.append(calendar.dateComponents([.year, .month, .day], from: date))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Collect the log
        var stretchLog: [DailyTimeLog] = []
        var practiceLog: [DailyTimeLog] = []
        for component in allComponents {
            let dailyActions = selectedActions[component] ?? []
            let date = calendar.date(from: component)!
            var stretchMinutes = 0.0
            var practiceMinutes = 0.0
            for action in dailyActions {
                switch(action) {
                case .stretch(let seconds):
                    stretchMinutes += Double(seconds) / 60.0
                case .practice(let seconds):
                    practiceMinutes += Double(seconds) / 60.0
                }
            }
            stretchLog.append(DailyTimeLog(date, stretchMinutes))
            practiceLog.append(DailyTimeLog(date, practiceMinutes))
        }
        return (stretchLog, practiceLog)
    }
    
    func addAction(_ action: UsefulAction) {
        let currentComponent = UsefulData.currentYearMonthDay()
        if self.actions[currentComponent] == nil {
            self.actions[currentComponent] = []
        }
        self.actions[currentComponent]!.append(action)
    }
}

class UsefulDataStore: ObservableObject {
    // Current app settings
    @Published var data: UsefulData = UsefulData()
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
            .appendingPathComponent("useful.data")
    }
    
    static func load(completion: @escaping (Result<UsefulData, Error>)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let fileURL = try fileURL()
                guard let file = try? FileHandle(forReadingFrom: fileURL) else {
                    DispatchQueue.main.async {
                        completion(.success(UsefulData()))
                    }
                    return
                }
                let result = try JSONDecoder().decode(UsefulData.self, from: file.availableData)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    

    
    static func save(data: UsefulData, onError: @escaping (Error)->Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(data)
                let outfile = try fileURL()
                try data.write(to: outfile)
            } catch {
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }
    }
}
