import Foundation

/// Reading and writing GPX files, the common format for routes.
nonisolated enum GPX {
    /// The most waypoints an imported file may add; longer tracks are thinned evenly.
    static let maxPoints = 500

    /// A GPX document with the waypoints as a route (`rte`) and, if it is more detailed than the
    /// waypoints, the planned path as a track (`trk`).
    static func document(name: String, waypoints: [Spot], path: [Spot]) -> String {
        func point(_ tag: String, _ spot: Spot) -> String {
            String(format: "      <%@ lat=\"%.6f\" lon=\"%.6f\"/>\n", tag, spot.latitude, spot.longitude)
        }
        let escaped = name
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="RePlace." xmlns="http://www.topografix.com/GPX/1/1">
          <rte>
            <name>\(escaped)</name>

        """
        xml += waypoints.map { point("rtept", $0) }.joined()
        xml += "  </rte>\n"
        if path.count > waypoints.count {
            xml += "  <trk>\n    <name>\(escaped)</name>\n    <trkseg>\n"
            xml += path.map { point("trkpt", $0) }.joined()
            xml += "    </trkseg>\n  </trk>\n"
        }
        xml += "</gpx>\n"
        return xml
    }

    /// The points of a GPX file: the route if there is one, otherwise the track, otherwise the
    /// single waypoints. Empty if the file cannot be read.
    static func points(in data: Data) -> [Spot] {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse() else { return [] }
        let chosen = [reader.route, reader.track, reader.waypoints].first { $0.count >= 2 } ?? []
        return thinned(chosen, to: maxPoints)
    }

    /// At most `limit` points, spread evenly, always keeping the first and the last.
    static func thinned(_ spots: [Spot], to limit: Int) -> [Spot] {
        guard spots.count > limit, limit >= 2 else { return spots }
        return (0..<limit).map { spots[Int((Double($0) * Double(spots.count - 1) / Double(limit - 1)).rounded())] }
    }

    private final class Reader: NSObject, XMLParserDelegate {
        var route: [Spot] = []
        var track: [Spot] = []
        var waypoints: [Spot] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes: [String: String] = [:]) {
            guard let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init),
                  (-90...90).contains(lat), (-180...180).contains(lon)
            else { return }
            let spot = Spot(latitude: lat, longitude: lon)
            switch elementName.split(separator: ":").last.map(String.init) {
            case "rtept": route.append(spot)
            case "trkpt": track.append(spot)
            case "wpt": waypoints.append(spot)
            default: break
            }
        }
    }
}
