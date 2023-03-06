//
//  UsefulApp.swift
//  Useful
//
//  Created by Andrew Gibiansky on 12/31/22.
//

import SwiftUI

@main
struct UsefulApp: App {
    @StateObject private var store = UsefulDataStore()
    
    var body: some Scene {
        let doSave = {
            UsefulDataStore.save(data: store.data) { error in
                fatalError(error.localizedDescription)
            }
        }
        let (stretchLog, practiceLog) = store.data.minutesOverTime()
        return WindowGroup {
            ContentView(
                stretchSecondsRemaining: $store.data.current.stretchingSecondsRemaining,
                stretchMinutesPerDay: $store.data.settings.stretchingMinutesPerDay,
                practiceSecondsRemaining: $store.data.current.practiceSecondsRemaining,
                practiceMinutesPerDay: $store.data.settings.practiceMinutesPerDay,
                caloriesToday: $store.data.settings.caloriesToday,
                stretchLog: stretchLog,
                practiceLog: practiceLog) {
                store.data.update()
            } recordStretch: { seconds in
                if seconds > 5 {
                    store.data.addAction(UsefulAction.stretch(seconds))
                }
                doSave()
            } recordPractice: { seconds in
                if seconds > 5 {
                    store.data.addAction(UsefulAction.practice(seconds))
                }
                doSave()
            } onSave: {
                doSave()
            }
            .onAppear {
                // Don't sleep
                UIApplication.shared.isIdleTimerDisabled = true
                
                UsefulDataStore.load { result in
                    switch result {
                    case .failure(let error):
                        fatalError(error.localizedDescription)
                    case .success(let data):
                        store.data = data
                    }
                }
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
}
