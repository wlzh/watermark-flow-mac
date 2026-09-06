import AppKit
import Foundation

MainActor.assumeIsolated {
    if CommandLine.arguments.contains("--self-test") {
        do {
            try SelfTest.run()
            exit(EXIT_SUCCESS)
        } catch {
            fputs("SELF_TEST_FAILED: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}
