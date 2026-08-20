import Foundation

@main
struct P00Spikes {
    @MainActor
    static func main() async {
        do {
            try PersistenceSchemaProbe.run()
            try await ImageAndNetworkProbe.run()
            SystemAPIProbe.run()
            print("P00 isolated probes completed successfully.")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
