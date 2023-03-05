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
        
        return WindowGroup {
            ContentView(
                secondsRemaining: $store.data.current.stretchingSecondsRemaining,
                minutesPerDay: $store.data.settings.stretchingMinutesPerDay,
                stretchLog: store.data.minutesOverTime()) {
                store.data.update()
            } recordStretch: { seconds in
                if seconds > 5 {
                    store.data.addAction(UsefulAction.stretch(seconds))
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
