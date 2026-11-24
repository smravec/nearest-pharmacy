import Foundation

/// A pharmacy name split into words that tell it apart and words that don't.
struct PharmacyName {
    let words: Set<String>
    let distinctive: Set<String>

    init(_ name: String) {
        words = Set(Self.folded(name).split { !$0.isLetter && !$0.isNumber }.map(String.init))
            .subtracting(Self.connectors)
        distinctive = words.subtracting(Self.genericWords)
    }

    /// "Alexa Apotheke" and "Alexa-Apotheke". Purely generic names must agree in full.
    func equals(_ other: PharmacyName) -> Bool {
        if distinctive.isEmpty || other.distinctive.isEmpty { return !words.isEmpty && words == other.words }
        return distinctive == other.distinctive
    }

    /// One name has more words: "Kallion apteekki" and "Kallion Apteekki Oy".
    func overlaps(_ other: PharmacyName) -> Bool {
        // An empty set is a subset of everything.
        guard !distinctive.isEmpty, !other.distinctive.isEmpty else { return false }
        return distinctive.isSubset(of: other.distinctive) || other.distinctive.isSubset(of: distinctive)
    }

    /// "Punavuoren apteekki" and "Apteekki Punavuori", or a plain "Apteekki". Only for places at the
    /// same spot. Apple's pharmacy category includes other shops, so `other` must say it is a pharmacy.
    func couldBe(_ other: PharmacyName) -> Bool {
        guard !other.words.isDisjoint(with: Self.pharmacyWords) else { return false }
        if distinctive.isEmpty || other.distinctive.isEmpty { return true }
        return distinctive.contains { word in
            other.distinctive.contains { word.commonPrefix(with: $0).count >= 5 }
        }
    }

    private static let pharmacyWords = Set([
        "apteekki", "apteekin", "sivuapteekki", "apotek", "apoteket", "apotheke", "apteka", "apteek",
        "pharmacy", "pharmacie", "pharma", "farmacia", "farmacija", "farmacie", "chemist", "chemists",
        "drugstore", "lekarna", "lekaren", "ljekarna", "patika", "gyogyszertar",
        "aptieka", "vaistine", "eczane", "eczanesi", "аптека", "φαρμακείο",
    ].map(folded))

    private static let genericWords = pharmacyWords.union(["drug", "store"])

    private static let connectors: Set<String> = [
        "de", "la", "le", "am", "der", "die", "das", "the", "of", "and", "at", "y", "et",
    ]

    private static func folded(_ text: String) -> String {
        text.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
