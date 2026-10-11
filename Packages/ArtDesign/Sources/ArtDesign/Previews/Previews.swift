import SwiftUI

// `#Preview` needs Xcode's SwiftUI macro plugin; see Package.swift (ART_SWIFTUI_MACROS).
#if ART_SWIFTUI_MACROS

// MARK: Typography
#Preview("Typography · Light") { TypographySpecimen().previewVariant(.light) }
#Preview("Typography · Dark") { TypographySpecimen().previewVariant(.dark) }
#Preview("Typography · AX5") { TypographySpecimen().previewVariant(.ax5) }
#Preview("Typography · Reduce Motion") { TypographySpecimen().previewVariant(.reduceMotion) }

// MARK: Glass
#Preview("Glass · Light") { GlassSpecimen().previewVariant(.light) }
#Preview("Glass · Dark") { GlassSpecimen().previewVariant(.dark) }
#Preview("Glass · AX5") { GlassSpecimen().previewVariant(.ax5) }
#Preview("Glass · Reduce Motion") { GlassSpecimen().previewVariant(.reduceMotion) }

// MARK: ArtworkFrame
#Preview("ArtworkFrame · Light") { ArtworkFrameSpecimen().previewVariant(.light) }
#Preview("ArtworkFrame · Dark") { ArtworkFrameSpecimen().previewVariant(.dark) }
#Preview("ArtworkFrame · AX5") { ArtworkFrameSpecimen().previewVariant(.ax5) }
#Preview("ArtworkFrame · Reduce Motion") { ArtworkFrameSpecimen().previewVariant(.reduceMotion) }

// MARK: CardStack
#Preview("CardStack · Light") { CardStackSpecimen().previewVariant(.light) }
#Preview("CardStack · Dark") { CardStackSpecimen().previewVariant(.dark) }
#Preview("CardStack · AX5") { CardStackSpecimen().previewVariant(.ax5) }
#Preview("CardStack · Reduce Motion") { CardStackSpecimen().previewVariant(.reduceMotion) }

// MARK: LogSlider
#Preview("LogSlider · Light") { LogSliderSpecimen().previewVariant(.light) }
#Preview("LogSlider · Dark") { LogSliderSpecimen().previewVariant(.dark) }
#Preview("LogSlider · AX5") { LogSliderSpecimen().previewVariant(.ax5) }
#Preview("LogSlider · Reduce Motion") { LogSliderSpecimen().previewVariant(.reduceMotion) }

// MARK: HammerReveal
#Preview("HammerReveal · Light") { HammerRevealSpecimen().previewVariant(.light) }
#Preview("HammerReveal · Dark") { HammerRevealSpecimen().previewVariant(.dark) }
#Preview("HammerReveal · AX5") { HammerRevealSpecimen().previewVariant(.ax5) }
#Preview("HammerReveal · Reduce Motion") { HammerRevealSpecimen().previewVariant(.reduceMotion) }

// MARK: ShareCard
#Preview("ShareCard · Light") { ShareCardSpecimen().previewVariant(.light) }
#Preview("ShareCard · Dark") { ShareCardSpecimen().previewVariant(.dark) }
#Preview("ShareCard · AX5") { ShareCardSpecimen().previewVariant(.ax5) }
#Preview("ShareCard · Reduce Motion") { ShareCardSpecimen().previewVariant(.reduceMotion) }
#endif
