import Foundation

@main
struct BanalCLIExecutable {
    static func main() {
        let code = BanalCLI.run(
            Array(CommandLine.arguments.dropFirst()),
            out: { FileHandle.standardOutput.write(Data($0.utf8)) },
            err: { FileHandle.standardError.write(Data($0.utf8)) }
        )
        if code != 0 {
            exit(code)
        }
    }
}
