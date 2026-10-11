import ArtCore

extension DatasetValidator {
    /// Round specs some mode actually plays: every fixed recipe plus all endless difficulties.
    static var playedSpecs: Set<RoundSpec> {
        var specs = Set<RoundSpec>()
        for mode in GameMode.allCases {
            if let recipe = GameSession.recipe(for: mode) { specs.formUnion(recipe) }
        }
        for d in Difficulty.allCases { specs.insert(RoundSpec(.higherLower, d)) }
        return specs
    }

    /// Category quiz readiness (rules v2: any active category may be a distractor, so only the
    /// truth needs `min_quiz_items`). No quiz-eligible category at all is an error; active
    /// categories below `min_quiz_items` are a warning (never asked as the truth yet). Failing
    /// category sessions are reported by the session probes.
    static func checkCategoryCoverage(pool: GamePool, report: inout DatasetValidationReport) {
        let coverage = GeneratorProbe.categoryCoverage(pool: pool)
        report.categoryCoverage = coverage
        let thin = coverage.filter { $0.active && !$0.quizEligible }
        if !thin.isEmpty {
            let list = thin.map { "\($0.id) \($0.primaryCount)/\($0.minQuizItems)" }.joined(separator: ", ")
            report.add(.warning, "category_below_quiz_minimum",
                "\(thin.count) active categories have fewer primary works than min_quiz_items: \(list)")
        }
        if !coverage.contains(where: \.quizEligible) {
            report.add(.error, "quiz_categories_none", "no category reaches min_quiz_items; the category quiz cannot run")
        }
    }

    /// The daily proof, per-kind round probes and per-mode session probes.
    static func checkGeneration(
        pool: GamePool, datasetVersion: String, options: ValidationOptions, report: inout DatasetValidationReport
    ) {
        let daily = DailyValidator.check(
            pool, from: options.dailyStart, days: options.dailyDays, datasetVersion: datasetVersion,
            dailyRulesVersion: options.dailyRulesVersion)
        report.daily = daily
        if !daily.isValid {
            var reasons: [String: Int] = [:]
            for f in daily.failures { reasons[f.reason, default: 0] += 1 }
            let detail = reasons.sorted { $0.value > $1.value }.map { "\($0.key) ×\($0.value)" }.joined(separator: "; ")
            report.add(.error, "daily_failed",
                "\(Set(daily.failures.map(\.day)).count) of \(daily.daysChecked) days from \(options.dailyStart) fail: \(detail)")
        }

        let played = playedSpecs
        for kind in RoundKind.allCases {
            for difficulty in Difficulty.allCases {
                let probe = GeneratorProbe.probeRounds(
                    kind: kind, difficulty: difficulty, pool: pool, attempts: options.probeRounds)
                report.roundProbes.append(probe)
                classify(probe, isPlayed: played.contains(RoundSpec(kind, difficulty)), report: &report)
            }
        }

        for mode in GameMode.allCases where mode != .daily {
            let probe = GeneratorProbe.probeSessions(mode: mode, pool: pool, attempts: options.probeSessions)
            report.sessionProbes.append(probe)
            if probe.successes < probe.attempts {
                let detail = probe.failures.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: " ")
                report.add(.error, "session_failed",
                    "\(mode.rawValue): \(probe.attempts - probe.successes)/\(probe.attempts) sessions fail (\(detail))")
            }
            if let run = probe.shortestPerfectRun, run < 15 {
                report.add(.warning, "endless_short",
                    "\(mode.rawValue): a perfect run can end after \(run) rounds (hard tier starts at round 15)")
            }
        }
    }

    /// Round probe severity: a played spec that never generates is an error; partial failures, or
    /// a spec no mode plays that never generates, are warnings; pairs mostly relaxed are a warning.
    static func classify(_ p: RoundProbeResult, isPlayed: Bool, report: inout DatasetValidationReport) {
        let name = "\(p.kind.rawValue).\(p.difficulty.rawValue)"
        let detail = p.failures.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: " ")
        if p.successes == 0 {
            report.add(isPlayed ? .error : .warning, "round_kind_unplayable",
                "\(name): 0/\(p.attempts) rounds generate (\(detail))" + (isPlayed ? "" : " — not used by any mode"))
        } else if p.successes < p.attempts {
            report.add(.warning, "round_kind_partial", "\(name): \(p.successes)/\(p.attempts) rounds generate (\(detail))")
        }
        if p.kind == .higherLower, p.successes > 0, p.relaxed * 2 > p.successes {
            report.add(.warning, "pairs_relaxed",
                "\(name): \(p.relaxed)/\(p.successes) pairs needed relaxed constraints (effectively easier)")
        }
    }
}
