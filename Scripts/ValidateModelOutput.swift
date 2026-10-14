import Foundation

// Compile together with Core/Sources/PrivateActionCore/*.swift for the offline probe.
@main struct ValidateModelOutput {
    static func main() {
        guard CommandLine.arguments.count >= 2 else { exit(2) }
        switch CommandLine.arguments[1] {
        case "--prompt": print(PromptBuilder.system, terminator: "")
        case "--retry": print(PromptBuilder.system(attempt: 1), terminator: "")
        default:
            do {
                let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
                var value = try OutputValidator.decode(ModelOutputEnvelope.normalize(bytes))
                if CommandLine.arguments.count == 3 {
                    let source = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
                    value = try SourceGrounding.validate(value, input: AnalysisInput(text: source))
                }
                print(String(decoding: try JSONEncoder().encode(value.value), as: UTF8.self))
            } catch { exit(1) }
        }
    }
}
