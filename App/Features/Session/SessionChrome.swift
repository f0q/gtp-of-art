import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Progress shown in the session top bar.
enum SessionProgress: Equatable {
    /// Fixed-length session: `current` is 1-based.
    case lots(current: Int, total: Int)
    /// Endless streak.
    case streak(Int)
}

/// Top bar: glass ✕ with quit confirmation, segmented progress (or streak) and the score capsule.
struct SessionTopBar: View {
    let progress: SessionProgress
    let score: Int
    let onQuit: () -> Void
    @State private var confirmingQuit = false

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.m) {
                Button { confirmingQuit = true } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .frame(width: Tokens.Size.minTarget, height: Tokens.Size.minTarget)
                        .artGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quit session")
                .accessibilityIdentifier("session.close")

                Text(caption)
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityIdentifier("session.progressLabel")
                Spacer(minLength: Tokens.Space.s)
                Text("\(score)")
                    .artTextStyle(Tokens.Typography.label)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(score)))
                    .foregroundStyle(Tokens.Color.accentGilt)
                    .padding(.horizontal, Tokens.Space.m)
                    .frame(minHeight: Tokens.Size.minTarget)
                    .artGlass()
                    .accessibilityLabel("Score \(score)")
            }
            if case .lots(let current, let total) = progress {
                SegmentedProgress(current: current, total: total)
            }
        }
        .confirmationDialog("Leave this session?", isPresented: $confirmingQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive, action: onQuit)
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Rounds you have answered are kept in your stats.")
        }
    }

    private var caption: String {
        switch progress {
        case .lots(let current, let total): "Lot \(current) of \(total)"
        case .streak(let n): "Streak \(n)"
        }
    }
}

/// One capsule per lot: done, current, upcoming.
struct SegmentedProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            ForEach(1...max(total, 1), id: \.self) { lot in
                Capsule()
                    .fill(fill(for: lot))
                    .frame(height: Tokens.Space.xs)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Lot \(current) of \(total)")
        .accessibilityIdentifier("session.progress")
    }

    private func fill(for lot: Int) -> Color {
        if lot < current { return Tokens.Color.textSecondary }
        if lot == current { return Tokens.Color.textPrimary }
        return Tokens.Color.lineHairline
    }
}

/// The one primary action at the bottom of a session screen.
struct SessionPrimaryButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .artButtonStyle(.prominent)
        .accessibilityIdentifier(identifier)
    }
}
