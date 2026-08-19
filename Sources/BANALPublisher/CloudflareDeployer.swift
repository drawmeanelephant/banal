import Foundation

/// Optional Cloudflare Pages / R2 hand-off. Local note-taking never depends on this.
///
/// BANAL does **not** embed Boris's multi-tenant Worker host
/// (`hosts/cloudflare-worker`). It prepares a static artifact directory and,
/// when the user supplies credentials, a wrangler Pages deploy command.
public struct CloudflareDeployPlan: Equatable, Sendable {
    public var projectName: String
    public var accountID: String?
    public var wranglerTOML: String
    public var command: [String]
    public var dryRun: Bool

    public init(projectName: String, accountID: String?, wranglerTOML: String, command: [String], dryRun: Bool) {
        self.projectName = projectName
        self.accountID = accountID
        self.wranglerTOML = wranglerTOML
        self.command = command
        self.dryRun = dryRun
    }
}

public enum CloudflareDeployer {
    public static func plan(
        artifactDirectory: URL,
        projectName: String,
        accountID: String?,
        dryRun: Bool = true
    ) -> CloudflareDeployPlan {
        var toml = """
        name = "\(projectName)"
        compatibility_date = "2026-08-18"
        pages_build_output_dir = "."
        """
        if let accountID, !accountID.isEmpty {
            toml += "\naccount_id = \"\(accountID)\"\n"
        }
        var command = ["npx", "wrangler", "pages", "deploy", artifactDirectory.path, "--project-name", projectName]
        if let accountID, !accountID.isEmpty {
            command += ["--account-id", accountID]
        }
        return CloudflareDeployPlan(
            projectName: projectName,
            accountID: accountID,
            wranglerTOML: toml,
            command: command,
            dryRun: dryRun
        )
    }

    public static func writeWranglerConfig(plan: CloudflareDeployPlan, artifactDirectory: URL) throws -> URL {
        let url = artifactDirectory.appendingPathComponent("wrangler.toml")
        try Data(plan.wranglerTOML.utf8).write(to: url, options: .atomic)
        return url
    }

    public static func canDeploy(projectName: String, token: String?) -> Bool {
        let project = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !project.isEmpty && !secret.isEmpty
    }

    /// Runs `wrangler pages deploy` with the token in the environment.
    /// The token is never written to disk or returned in the log.
    public static func deploy(
        plan: CloudflareDeployPlan,
        token: String,
        runner: (CloudflareDeployPlan, [String: String]) throws -> String = CloudflareDeployer.runWrangler
    ) throws -> String {
        guard canDeploy(projectName: plan.projectName, token: token) else {
            throw CloudflareDeployError.notConnected
        }
        var environment = ProcessInfo.processInfo.environment
        environment["CLOUDFLARE_API_TOKEN"] = token
        let log = try runner(plan, environment)
        return redact(token, from: log)
    }

    public static func runWrangler(plan: CloudflareDeployPlan, environment: [String: String]) throws -> String {
        guard let binary = wranglerExecutable(environment: environment) else {
            throw CloudflareDeployError.wranglerMissing
        }
        let process = Process()
        process.executableURL = binary
        if binary.lastPathComponent == "npx" {
            process.arguments = ["--yes"] + Array(plan.command.dropFirst())
        } else {
            process.arguments = Array(plan.command.dropFirst(2))
        }
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            throw CloudflareDeployError.wranglerMissing
        }
        process.waitUntilExit()
        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let log = [out, err].filter { !$0.isEmpty }.joined(separator: "\n")
        if process.terminationStatus != 0 {
            throw CloudflareDeployError.failed(status: process.terminationStatus, log: log)
        }
        return log
    }

    public static func wranglerExecutable(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        let path = environment["PATH"] ?? ""
        var searchDirs = path.split(separator: ":").map(String.init)
        for fallback in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] {
            if !searchDirs.contains(fallback) {
                searchDirs.append(fallback)
            }
        }
        for name in ["wrangler", "npx"] {
            for directory in searchDirs {
                let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return nil
    }

    private static func redact(_ token: String, from log: String) -> String {
        guard !token.isEmpty else { return log }
        return log.replacingOccurrences(of: token, with: "***")
    }
}

public enum CloudflareDeployError: Error, Equatable, Sendable {
    case notConnected
    case wranglerMissing
    case failed(status: Int32, log: String)
}
