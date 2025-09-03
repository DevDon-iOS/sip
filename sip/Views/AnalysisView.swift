//
//  AnalysisView.swift
//  sip
//
//  Created by 이돈혁 on 7/15/25.
//

import SwiftUI

struct AnalysisView: View {
    @State private var selectedColorIndex = 0
    
//    private var stepRecords: [(String, String)] {
//        let values = ["1", "2", "3"]
//        let dates = (0..<14).map { "2025. 5. \(23 - $0)" }
//        return Array(zip(values, dates))
//    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("기간 선택", selection: $selectedColorIndex) {
                        Text("최신").tag(0)
                        Text("1달").tag(1)
                        Text("전체 기록").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                Spacer()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ㅇㅇ")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        // 낮잠의 질
                        NavigationLink(destination: NapQualityView()) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("낮잠의 질")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                HStack {
                                    Text("아직 데이터가 없습니다.")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }

                        // 평균 낮잠 시간
                        NavigationLink(destination: AverNapTimeView()) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("평균 낮잠 시간")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                HStack {
                                    Text("아직 데이터가 없습니다.")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("분석")
        }
    }
}

#Preview {
    AnalysisView()
}
