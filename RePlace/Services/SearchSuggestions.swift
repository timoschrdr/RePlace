import MapKit
import Observation

/// Suggestions for the address field while the user types, from Apple Maps.
@Observable
final class SearchSuggestions: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var items: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                items = []
                completer.cancel()
            } else {
                completer.queryFragment = query
            }
        }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        MainActor.assumeIsolated { items = Array(results.prefix(5)) }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { items = [] }
    }
}
