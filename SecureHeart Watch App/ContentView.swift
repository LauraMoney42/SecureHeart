//
//  ContentView.swift
//  Secure Heart Watch App
//
//  Created by Laura Money on 8/25/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var heartRateManager: HeartRateManager
    
    var body: some View {
        HeartRateView()
            .environmentObject(heartRateManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(HeartRateManager())
}
