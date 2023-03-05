//
//  ContentView.swift
//  Useful
//
//  Created by Andrew Gibiansky on 12/31/22.
//

import SwiftUI
import Charts

var existingTimer: Timer?

struct RemainingSecondsView : View {
    @Binding var secondsRemaining: Int
    
    @State private var isTiming: Bool = false
    @State private var elapsedMs: Int = 0
    @State private var lastStartTimeNs = DispatchTime.now().uptimeNanoseconds
    
    let updateRemainingTime: () -> Void
    let recordStretch: (Int) -> Void
    
    var body : some View {
        var remainingMs = Float(secondsRemaining * 1000)
        if isTiming {
            remainingMs -= Float(elapsedMs)
        }
        let remaining: Float = remainingMs / 1000;
        let rounded = Int(remaining)
        let minutes = rounded / 60
        let seconds = rounded % 60
        let centiseconds = Int(100 * (remaining - Float(rounded)))
        let display = String(format: "%02d:%02d:%02d", minutes, seconds, centiseconds)
        
        return VStack {
            Text("Remaining: \(display)")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .padding()
                .monospacedDigit()
            Button(isTiming ? "Stop" : "Start") {
                // Trigger an update in case its needed
                DispatchQueue.main.async {
                    updateRemainingTime()
                }
                
                isTiming.toggle()
                
                // Stop any running timers
                existingTimer?.invalidate()
                
                if isTiming {
                    elapsedMs = 0
                    lastStartTimeNs = DispatchTime.now().uptimeNanoseconds
                    existingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                        let currentTimeNs = DispatchTime.now().uptimeNanoseconds
                        elapsedMs = Int((currentTimeNs - lastStartTimeNs) / 1_000_000)
                        
                        let elapsedSec = elapsedMs / 1000
                        let remainingAfterSec = secondsRemaining - elapsedSec
                        if remainingAfterSec <= 0 {
                            isTiming = false
                            secondsRemaining = 0
                            
                            DispatchQueue.main.async {
                                recordStretch(elapsedSec)
                            }
                        }
                        
                        if !isTiming {
                            timer.invalidate()
                        }
                    }
                } else {
                    let elapsedSec = elapsedMs / 1000
                    secondsRemaining -= elapsedSec
                    DispatchQueue.main.async {
                        recordStretch(elapsedSec)
                    }
                    elapsedMs = 0
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct SettingsView : View {
    @Binding var secondsRemaining: Int
    @Binding var minutesPerDay: Int
    
    var body : some View {
        VStack {
            Stepper(value: $minutesPerDay) {
                Text("Minutes / Day: \(minutesPerDay)").padding()
            }.padding()
            Button("Reset Time") {
                secondsRemaining = minutesPerDay * 60
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Add 5 Minutes") {
                secondsRemaining += 5 * 60
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct GraphView : View {
    let data: [StretchLog]
    @State private var pastDaysToShow: Int = 30
    
    var body : some View {
        // Compute stats
        let dataSlice = data.suffix(pastDaysToShow)
        var totalMinutes = 0.0
        var totalMinutesNonzero = 0.0
        var daysNonzero = 0.0
        var totalDays = 0.0
        
        for log in dataSlice {
            totalDays += 1
            totalMinutes += log.minutes
            if log.minutes > 0 {
                daysNonzero += 1
                totalMinutesNonzero += log.minutes
            }
        }
        
        if totalDays == 0 {
            totalDays = 1
        }
        if daysNonzero == 0 {
            daysNonzero = 1
        }
        
        let percentNonzero = Int(100.0 * daysNonzero / totalDays)
        let avgMinutes = totalMinutes / totalDays
        let avgMinutesNonzero = totalMinutesNonzero / daysNonzero
        
        let display0 = String(format: "Showing past %d days...", Int(totalDays))
        let display1 = String(format: "Days Stretched: %d%%", percentNonzero)
        let display2 = String(format: "Average Minutes: %.1f", avgMinutes)
        let display3 = String(format: "Average Minutes (When Stretching): %.1f", avgMinutesNonzero)
        
        return VStack {
            Text("Your Stretching")
                .font(.largeTitle)
                .padding()
            Chart(dataSlice) {
                LineMark(
                    x: .value("Date", $0.date),
                    y: .value("Minutes", $0.minutes)
                )
                .interpolationMethod(.stepStart)
                .lineStyle(StrokeStyle(lineWidth: 4))
            }
            .chartXAxisLabel("Date")
            .chartYAxisLabel("Minutes")
            .padding(50)
            Text(display0)
            Text(display1)
            Text(display2)
            Text(display3)
            HStack {
                Button("Year") {
                    pastDaysToShow = 365
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                Button("Month") {
                    pastDaysToShow = 30
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Week") {
                    pastDaysToShow = 7
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
        
    }
}

struct ContentView: View {
    @Binding var secondsRemaining: Int
    @Binding var minutesPerDay: Int
    
    @Environment(\.scenePhase) private var scenePhase
    
    let stretchLog: [StretchLog]
    let updateRemainingTime: () -> Void
    let recordStretch: (Int) -> Void
    let onSave: () -> Void
    
    var body: some View {
        return TabView {
            // Timer tab
            RemainingSecondsView(
                secondsRemaining: $secondsRemaining,
                updateRemainingTime: updateRemainingTime,
                recordStretch: recordStretch)
            .tabItem {
                Label("Timer", systemImage: "clock")
            }
            
            // Settings tab
            GraphView(data: stretchLog)
                .tabItem {
                    Label("Graph", systemImage: "chart.bar.fill")
                }
            
            // Settings tab
            SettingsView(
                secondsRemaining: $secondsRemaining,
                minutesPerDay: $minutesPerDay)
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .onChange(of: scenePhase) { phase in
            updateRemainingTime()
            
            if phase == .inactive {
                onSave()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    @StateObject private static var store: UsefulDataStore = UsefulDataStore()
    static var previews: some View {
        ContentView(
            secondsRemaining: $store.data.current.stretchingSecondsRemaining,
            minutesPerDay: $store.data.settings.stretchingMinutesPerDay,
            stretchLog: store.data.minutesOverTime()) {
                store.data.update()
            } recordStretch: {
                _ in
                // Do nothing
            } onSave: {
                // Do nothing
            }
    }
}
