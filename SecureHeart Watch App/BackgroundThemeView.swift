//
//  BackgroundThemeView.swift
//  Secure Heart Watch App
//
//  Background color selector for watch faces
//

import SwiftUI

struct BackgroundThemeView: View {
    @AppStorage("watchFaceBackgroundColor") private var selectedBackgroundColor = 0
    
    // All the Custom Colors palette from the screenshot - exact same colors and layout
    let backgroundColors: [Color] = [
        // Row 1: Primary colors
        .red, .orange, .yellow, .green, .mint,
        
        // Row 2: Blues and purples  
        .teal, .cyan, .blue, Color(red: 0.7, green: 0.5, blue: 1.0), .purple,
        
        // Row 3: Neutrals and basics
        Color(red: 1.0, green: 0.2, blue: 0.4), // Hot pink
        .brown, .white, .gray, .black,
        
        // Row 4: Sunset Terra palette
        Color(red: 0.98, green: 0.93, blue: 0.89), // Cream
        Color(red: 1.0, green: 0.78, blue: 0.74),  // Coral Pink
        Color(red: 0.87, green: 0.70, blue: 0.60), // Warm Brown
        Color(red: 0.97, green: 0.88, blue: 0.82), // Peachy Cream
        Color(red: 0.97, green: 0.77, blue: 0.68), // Salmon
        
        // Row 5: Gelato Days palette
        Color(red: 1.0, green: 0.80, blue: 0.76),  // Soft Coral
        Color(red: 0.62, green: 0.90, blue: 0.31), // Lime Green
        Color(red: 1.0, green: 0.88, blue: 0.66),  // Pale Yellow
        Color(red: 0.55, green: 0.85, blue: 0.93), // Sky Blue
        Color(red: 0.86, green: 0.78, blue: 0.93)  // Lavender
    ]
    
    var currentBackgroundColor: Color {
        if selectedBackgroundColor < backgroundColors.count {
            return backgroundColors[selectedBackgroundColor]
        }
        return .black
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Background Colors")
                    .font(.headline)
                    .padding(.top)
                
                // Background color picker row (like Custom themes)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Watch Face Background")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Circle()
                            .fill(currentBackgroundColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Color grid (exactly like Custom color picker)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                        ForEach(Array(backgroundColors.enumerated()), id: \.offset) { index, color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(selectedBackgroundColor == index ? Color.white : Color.white.opacity(0.3), 
                                               lineWidth: selectedBackgroundColor == index ? 2 : 1)
                                )
                                .scaleEffect(selectedBackgroundColor == index ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedBackgroundColor == index)
                                .onTapGesture {
                                    selectedBackgroundColor = index
                                }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                )
                
                // Preview section (like Custom themes)
                VStack(spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Circle()
                        .fill(currentBackgroundColor)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.top)
                
                // Tips section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips:")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.gray)
                        Text("Double-tap any watch face to quickly cycle through colors")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.gray)
                        Text("Dark colors save battery on OLED displays")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Background")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    BackgroundThemeView()
}