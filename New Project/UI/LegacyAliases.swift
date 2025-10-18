//
//  LegacyAliases.swift
//  New Project
//
//  Created by Celeste van Dokkum on 10/15/25.
//

import SwiftUI

// Tokens
typealias BrandTheme       = AppUI.Tokens
typealias GenTheme         = AppUI.Tokens
typealias ListBrandTheme   = AppUI.Tokens
typealias DetailBrandTheme = AppUI.Tokens
typealias ProgBrandTheme   = AppUI.Tokens
typealias ProfBrand        = AppUI.Tokens

extension AppUI.Tokens {
    static var corner: CGFloat { cardCorner }          // old ".corner" -> new ".cardCorner"
    static var bg: Color { pageBG }                    // old ".bg"     -> new ".pageBG"
    static var card: Color { cardBG }                  // old ".card"   -> new ".cardBG"
    static var stroke: Color { separator }             // old ".stroke" -> new ".separator"
}

// Backgrounds
typealias BrandedBlobBackground = AppUI.BlobBackground
typealias BlobBackground        = AppUI.BlobBackground
typealias BlobBackgroundList    = AppUI.BlobBackground
typealias BlobBackgroundDetail  = AppUI.BlobBackground
typealias ProfileBackground     = AppUI.BlobBackground

// Cards / Headers
typealias SectionHeader              = AppUI.SectionHeader
typealias ListSectionHeader          = AppUI.SectionHeader
typealias SectionCard<Content: View> = AppUI.SectionCard<Content>
typealias ProfileCard<Content: View> = AppUI.SectionCard<Content>
typealias ProgSectionCard<Content: View> = AppUI.SectionCard<Content>

// Common components
typealias TagChip   = AppUI.TagChip
typealias MetricTile = AppUI.MetricTile
