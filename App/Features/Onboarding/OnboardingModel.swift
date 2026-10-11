import ArtCore
import ArtData
import Foundation
import Observation

/// The five-step questionnaire (plan Part I2). Every step is skippable; "Skip" finishes with the
/// answers given so far. Completion goes through `OnboardingService` via `ProfileModel`.
@Observable
final class OnboardingModel: Identifiable {
    static let stepCount = 5

    private(set) var step = 1
    private(set) var answers = OnboardingAnswers()
    /// Step 2 selections (choice ids; two ids may map to the same department).
    private(set) var selectedDepartmentChoices: [String] = []
    private(set) var isComplete = false

    @ObservationIgnored let dataset: any DatasetProviding
    @ObservationIgnored private let profile: ProfileModel
    @ObservationIgnored private let variety: String

    init(dataset: any DatasetProviding, profile: ProfileModel) {
        self.dataset = dataset
        self.profile = profile
        variety = profile.profile.localPlayerID
    }

    var catalog: OnboardingCatalog { dataset.onboarding }

    var title: String {
        switch step {
        case 1: "Which world draws you in?"
        case 2: "And within that?"
        case 3: "What do you like to look at?"
        case 4: "Which mood?"
        default: "Why are you here?"
        }
    }

    var subtitle: String? {
        switch step {
        case 2: "Choose one or more."
        case 5: "This sets your starting difficulty. You can change it in Settings."
        default: nil
        }
    }

    /// Choices for the current step. Step 2 depends on the era picked in step 1 (plan I2).
    var choices: [OnboardingChoice] {
        let all = catalog.choices(step: step)
        guard step == 2, let era = answers.era else { return all }
        let wanted: [String] = switch era {
        case .classic: ["old_masters", "nineteenth_century", "asian_art"]
        case .modern:
            ["impressionist_modern:impressionist", "impressionist_modern:avant_garde", "asian_art", "prints_photographs"]
        }
        let picked = wanted.compactMap { id in all.first { $0.id == id } }
        return picked.isEmpty ? all : picked
    }

    /// Intent chips for step 5 (no exemplars).
    static let intents: [(intent: OnboardingAnswers.Intent, title: String, detail: String)] = [
        (.learn, "Learn", "Start easy with the category quiz."),
        (.play, "Play", "A balanced game, starting with Pick the price."),
        (.testMyEye, "Test my eye", "Hard rounds, starting with Bid."),
    ]

    /// The exemplar shown for a choice; rotates between alternates per player so repeats vary.
    func exemplar(for choice: OnboardingChoice) -> (artwork: Artwork, caption: String)? {
        let available = choice.exemplars.compactMap { e in dataset.artwork(e.artworkID).map { ($0, e.caption) } }
        guard !available.isEmpty else { return nil }
        let index = Int(fnv1a64("\(variety)|\(choice.id)") % UInt64(available.count))
        return available[index]
    }

    func isSelected(_ choice: OnboardingChoice) -> Bool { selectedDepartmentChoices.contains(choice.id) }

    /// One-tap answer for steps 1, 3 and 4 (advances); toggles for step 2.
    func choose(_ choice: OnboardingChoice) {
        switch step {
        case 1:
            answers.era = choice.era
            selectedDepartmentChoices = []
            answers.departments = []
            advance()
        case 2:
            if let i = selectedDepartmentChoices.firstIndex(of: choice.id) {
                selectedDepartmentChoices.remove(at: i)
            } else {
                selectedDepartmentChoices.append(choice.id)
            }
            answers.departments = Set(selectedDepartmentChoices.compactMap { catalog.choice($0)?.department })
        case 3:
            answers.subjects = choice.subject.map { [$0] } ?? []
            advance()
        case 4:
            answers.mood = choice.mood
            advance()
        default:
            break
        }
    }

    /// Step 5 chip.
    func choose(_ intent: OnboardingAnswers.Intent) {
        answers.intent = intent
        finish()
    }

    /// Continue from step 2 (needs at least one department).
    var canContinue: Bool { step == 2 && !selectedDepartmentChoices.isEmpty }

    func continueFromDepartments() {
        guard canContinue else { return }
        advance()
    }

    /// Skips the rest of the questionnaire, keeping the answers so far.
    func skip() { finish() }

    private func advance() {
        if step < Self.stepCount { step += 1 } else { finish() }
    }

    private func finish() {
        guard !isComplete else { return }
        isComplete = true
        profile.completeOnboarding(answers, dataset: dataset)
    }
}
