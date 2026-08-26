//
//  NotoSansKR.swift
//  sip
//
//  Created by 이돈혁 on 8/19/26.
//

import CoreText
import OSLog
import SwiftUI
import UIKit

enum NotoSansKR {
    enum Weight: CGFloat {
        case regular = 400
        case medium = 500
        case bold = 700
        case black = 900

        fileprivate var fallbackWeight: UIFont.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .bold: .bold
            case .black: .black
            }
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.codling.sip",
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
        relativeTo textStyle: UIFont.TextStyle
    ) -> Font {
        _ = registration

        let baseFont: UIFont
        if let bundledFont = UIFont(name: "Noto Sans KR", size: size) {
            let weightAxis = NSNumber(value: 0x77676874)
            let variationAttribute = UIFontDescriptor.AttributeName(
                rawValue: kCTFontVariationAttribute as String
            )
            let descriptor = bundledFont.fontDescriptor.addingAttributes([
                variationAttribute: [weightAxis: NSNumber(value: weight.rawValue)]
            ])
            baseFont = UIFont(descriptor: descriptor, size: size)
        } else {
            logger.error("Registered Noto Sans KR family could not be resolved.")
            baseFont = UIFont.systemFont(ofSize: size, weight: weight.fallbackWeight)
        }

        let scaledFont = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
        return Font(scaledFont)
    }
}
