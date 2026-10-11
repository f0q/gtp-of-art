import ArtCore
import Foundation

/// Applies the onboarding questionnaire to the player profile (plan Part I2–I3).
///
/// `PlayerProfile.hasOnboarded` is the single source of truth for onboarding state. Completing
/// stores the `TastePrior` in `profile.json` and also appends an `OnboardingLogEntry` to
/// `rounds.jsonl`, so a profile rebuilt from history keeps the prior.
public enum OnboardingService {
    /// Answers restricted to the dataset: department ids the taxonomy does not know are dropped.
    public static func sanitized(_ answers: OnboardingAnswers, dataset: any DatasetProviding) -> OnboardingAnswers {
        let known = Set(dataset.departments.map(\.id))
        var a = answers
        a.departments = answers.departments.filter { known.contains($0) }
        return a
    }

    /// The prior for a set of answers, or nil when every step was skipped.
    public static func prior(for answers: OnboardingAnswers, dataset: any DatasetProviding) -> TastePrior? {
        let clean = sanitized(answers, dataset: dataset)
        return clean == OnboardingAnswers() ? nil : TastePrior.from(answers: clean)
    }

    /// Pure: sets `prior`, re-seeds the taste profile (replacing any previous seeds; swipes are
    /// kept) and marks the player onboarded.
    public static func complete(answers: OnboardingAnswers, profile: PlayerProfile, dataset: any DatasetProviding)
        -> PlayerProfile
    {
        var p = profile
        p.prior = prior(for: answers, dataset: dataset)
        p.taste = p.taste.seeded(from: p.prior ?? .none)
        p.hasOnboarded = true
        return p
    }

    /// Pure: "redo questionnaire" — clears the prior and seeds and shows onboarding again.
    /// Swipes, stats and daily state are kept.
    public static func reset(profile: PlayerProfile) -> PlayerProfile {
        var p = profile
        p.prior = nil
        p.taste = p.taste.seeded(from: .none)
        p.hasOnboarded = false
        return p
    }

    /// Completes onboarding against a store: logs the entry, saves and flushes the profile.
    @discardableResult
    public static func complete(
        answers: OnboardingAnswers, store: any ProfileStoring, dataset: any DatasetProviding,
        now: Int64 = Int64(Date().timeIntervalSince1970)
    ) async throws -> PlayerProfile {
        let updated = complete(answers: answers, profile: await store.profile(), dataset: dataset)
        try await store.appendOnboarding(
            OnboardingLogEntry(
                action: .complete, answers: sanitized(answers, dataset: dataset), prior: updated.prior, recordedAt: now))
        await store.save(updated)
        try await store.flush()
        return updated
    }

    /// Resets onboarding against a store: logs the reset, saves and flushes the profile.
    @discardableResult
    public static func reset(store: any ProfileStoring, now: Int64 = Int64(Date().timeIntervalSince1970))
        async throws -> PlayerProfile
    {
        let updated = reset(profile: await store.profile())
        try await store.appendOnboarding(OnboardingLogEntry(action: .reset, answers: nil, prior: nil, recordedAt: now))
        await store.save(updated)
        try await store.flush()
        return updated
    }
}
