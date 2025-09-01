//
//  SimpleContentView.swift
//  Secure Heart
//
//  Simple test version to debug crashes
//

import SwiftUI

struct SimpleContentView: View {
    var body: some View {
        VStack {
            Text("Secure Heart")
                .font(.largeTitle)
                .padding()
            
            Text("Daily Heart Rate Graph")
                .font(.headline)
                .padding()
            
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 200)
                .overlay(
                    Text("Heart Rate Graph Placeholder")
                        .foregroundColor(.blue)
                )
                .padding()
            
            Spacer()
        }
        .navigationTitle("Dashboard")
    }
}