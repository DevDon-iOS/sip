//
//  HomeView.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedColorIndex = 0
    
//    private var stepRecords: [(String, String)] {
//        let values = ["1", "2", "3"]
//        let dates = (0..<14).map { "2025. 5. \(23 - $0)" }
//        return Array(zip(values, dates))
//    }
    
    var body: some View {
        NavigationStack {
            Text("HomeView")
                .navigationTitle("Sip")
        }
    }
}

#Preview {
    HomeView()
}
