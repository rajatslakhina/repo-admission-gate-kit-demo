import SwiftUI
import RepoAdmission
import RepoAdmissionUI

/// The demo app owns the admission policy — exactly as a team's tooling repo
/// would — and hands it to the library's console.
///
/// It starts from `.strict` and allow-lists one package pin: `swift-syntax` at
/// the exact revision the red-team fixture's `Package.resolved` records. That
/// is how an allow-list is meant to shrink the surface a human has to review:
/// by content (identity + revision), never by name or version range. Move the
/// pin and the package is back on the approval surface.
@main
struct DemoApp: App {
    static let policy: AdmissionPolicy = {
        var policy = AdmissionPolicy.strict
        policy.allowedPackages = [
            PackagePin(identity: "swift-syntax", revision: RedTeamFixture.swiftSyntaxRevision),
        ]
        return policy
    }()

    var body: some Scene {
        WindowGroup {
            AdmissionConsoleView(policy: Self.policy)
        }
    }
}
