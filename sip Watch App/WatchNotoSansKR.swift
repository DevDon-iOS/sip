//
//  WatchNotoSansKR.swift
//  sip Watch App
//
//  Created by 이돈혁 on 8/20/26.
//

import CoreText
import OSLog
import SwiftUI

enum WatchNotoSansKR {
    enum Weight {
        case medium
        case bold

        fileprivate var fontWeight: Font.Weight {
            switch self {
            case .medium: .medium
            case .bold: .bold
            }
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.codling.sip.watchkitapp",
        category: "FontRegistration"
    )

    private static let registration: Void = {
        guard let fontURL = Bundle.main.url(
            forResource: "NotoSansKR-Variable",
            withExtension: "ttf"
        ) else {
            logger.error("Bundled Noto Sans KR font resource was not found.")
            return
        }

        var registrationError: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(
            fontURL as CFURL,
            .process,
            &registrationError
        )

        if !didRegister, let error = registrationError?.takeRetainedValue() {
            logger.error("Noto Sans KR registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }()

    static func font(
        size: CGFloat,
        weight: Weight,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        _ = registration
        return Font.custom(
            "Noto Sans KR",
            size: size,
            relativeTo: textStyle
        )
        .weight(weight.fontWeight)
    }
}
