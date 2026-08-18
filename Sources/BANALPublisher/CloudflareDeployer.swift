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
}
