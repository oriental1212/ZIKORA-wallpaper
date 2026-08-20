import Foundation

struct ProbeFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw ProbeFailure(message)
    }
}

func reportPass(_ message: String) {
    print("PASS: \(message)")
}

