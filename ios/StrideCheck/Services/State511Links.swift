import Foundation

/// Hand-curated 511 / traveler-info entry points by U.S. state (two-letter code). Expand as needed.
enum State511Links {
    /// State-specific 511 portal when `code` is a two-letter U.S. abbreviation; otherwise the federal 511 directory.
    static func url(forStateAbbrev code: String?) -> URL {
        if let c = code?.uppercased(), c.count == 2, let template = links[c], let u = URL(string: template) {
            return u
        }
        return URL(string: "https://www.fhwa.dot.gov/trafficinfo/511.htm")!
    }

    private static let links: [String: String] = [
        "AL": "https://algotraffic.com/",
        "AK": "https://511.alaska.gov/",
        "AZ": "https://www.az511.gov/",
        "AR": "https://www.idrivearkansas.com/",
        "CA": "https://quickmap.dot.ca.gov/",
        "CO": "https://www.codot.gov/travel/cotrip/",
        "CT": "https://www.ct511.org/",
        "DE": "https://www.deldot.gov/",
        "DC": "https://traffic.dc.gov/",
        "FL": "https://www.fl511.com/",
        "GA": "https://511ga.org/",
        "HI": "https://hidot.hawaii.gov/highways/road-conditions/",
        "ID": "https://511.idaho.gov/",
        "IL": "https://www.gettingaroundillinois.com/",
        "IN": "https://511in.org/",
        "IA": "https://511ia.org/",
        "KS": "https://www.kandrive.gov/",
        "KY": "https://goky.ky.gov/",
        "LA": "https://www.511la.org/",
        "ME": "https://newengland511.org/",
        "MD": "https://chart.maryland.gov/",
        "MA": "https://www.mass511.com/",
        "MI": "https://www.michigan.gov/mdot/travel/",
        "MN": "https://511mn.org/",
        "MS": "https://www.mdottraffic.com/",
        "MO": "https://traveler.modot.org/",
        "MT": "https://www.mdt.mt.gov/travinfo/",
        "NE": "https://www.511.nebraska.gov/",
        "NV": "https://www.nvroads.com/",
        "NH": "https://newengland511.org/",
        "NJ": "https://www.511nj.org/",
        "NM": "https://www.nmroads.com/",
        "NY": "https://511ny.org/",
        "NC": "https://www.ncdot.gov/travel/",
        "ND": "https://www.dot.nd.gov/travel-info-v2/",
        "OH": "https://www.ohgo.com/",
        "OK": "https://www.oktraffic.org/",
        "OR": "https://www.tripcheck.com/",
        "PA": "https://www.511pa.com/",
        "RI": "https://newengland511.org/",
        "SC": "https://www.511sc.org/",
        "SD": "https://www.safetravelusa.com/sd/",
        "TN": "https://www.tn.gov/tdot/traffic.html",
        "TX": "https://drivetexas.org/",
        "UT": "https://www.udottraffic.utah.gov/",
        "VT": "https://newengland511.org/",
        "VA": "https://www.511virginia.org/",
        "WA": "https://wsdot.com/travel/real-time/map/",
        "WV": "https://wv511.org/",
        "WI": "https://511wi.gov/",
        "WY": "https://www.wyoroad.info/"
    ]
}
