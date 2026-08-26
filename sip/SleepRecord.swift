//
//  SleepRecord.swift
//  sip
//
//  Created by 이돈혁 on 7/14/25.
//

import Foundation

struct SleepRecord: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
}
