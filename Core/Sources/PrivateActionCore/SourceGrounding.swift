import Foundation

/// Conservative extractive contract, not a general semantic truth detector.
/// The model may select source spans; it may not compose new factual prose.
public enum SourceGrounding {
    public static func validate(_ proposal: ValidatedProposal, input: AnalysisInput) throws -> ValidatedProposal {
        let value = proposal.value
        let source = normalized(input.text)
        // Fail closed on common instruction-spoofing forms. This is supplementary:
        // unknown attacks remain possible, and every action still needs review.
        let instructionMarkers = ["system:", "system instruction", "ignore all", "ignore previous", "ignore earlier", "invent a", "<system>", "delete all reminders"]
        guard !instructionMarkers.contains(where: { source.contains($0) }) else { throw PrivateActionError.ungroundedOutput }
        func supported(_ text: String) -> Bool {
            let span = normalized(text)
            return !span.isEmpty && source.contains(span)
        }
        guard supported(value.summary),
              supported(value.title) || value.title == "Source excerpt",
              value.dates.allSatisfy({ supported($0.rawText) }),
              value.checklist.allSatisfy({ supported($0.text) }) else { throw PrivateActionError.ungroundedOutput }
        // Entity typing and model-generated timestamps are not independently verified.
        // Leave them out instead of treating valid JSON as evidence of correctness.
        let actions = value.proposedActions.map {
            ProposedAction(type: $0.type, title: value.title, explanation: "Review the source and details before saving.")
        }
        return try OutputValidator.validate(ActionProposal(category: value.category, title: value.title,
            summary: value.summary, dates: value.dates.map { ExtractedDate(rawText: $0.rawText, iso8601: nil) },
            locations: [], people: [], checklist: value.checklist, proposedActions: actions))
    }
    private static func normalized(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
