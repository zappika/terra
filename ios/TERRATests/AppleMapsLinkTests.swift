import Foundation
import Testing
@testable import TERRA

/// Cases from ios/docs/apple-maps-share-spike.md. Add every real URL seen on the iPhone here.
struct AppleMapsLinkTests {
    typealias LatLon = AppleMapsLink.LatLon

    func parse(_ string: String) -> AppleMapsLink.Result {
        AppleMapsLink.parse(URL(string: string)!)
    }

    // MARK: Places

    @Test func legacyPlaceWithLLAndQ() {
        #expect(parse("https://maps.apple.com/?ll=41.403629,2.174356&q=Sagrada%20Fam%C3%ADlia")
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: "Sagrada Família", placeID: nil)))
    }

    @Test func legacyPlaceWithAddressAndAuid() {
        #expect(parse("https://maps.apple.com/?address=Carrer+de+Mallorca,+401,+08013+Barcelona,+Spain&auid=123456789&ll=41.403629,2.174356&lsp=9902&q=Sagrada+Fam%C3%ADlia")
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: "Sagrada Família", placeID: "123456789")))
    }

    @Test func unifiedPlaceWithCoordinateAndName() {
        #expect(parse("https://maps.apple.com/place?coordinate=41.403629,2.174356&name=Sagrada%20Fam%C3%ADlia&place-id=I7C250D2CDCB364A")
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: "Sagrada Família", placeID: "I7C250D2CDCB364A")))
    }

    @Test func addressOnly() {
        #expect(parse("https://maps.apple.com/?address=1%20Infinite%20Loop,%20Cupertino,%20CA")
            == .destination(.address("1 Infinite Loop, Cupertino, CA", name: nil)))
    }

    @Test func unifiedPlaceIDOnly() {
        #expect(parse("https://maps.apple.com/place?place-id=I7C250D2CDCB364A&name=Sagrada")
            == .destination(.placeID("I7C250D2CDCB364A", name: "Sagrada")))
    }

    @Test func searchQueryIsNeverAPlace() {
        #expect(parse("https://maps.apple.com/?q=coffee") == .destination(.searchQuery("coffee")))
        #expect(parse("https://maps.apple.com/?q=coffee&sll=41.39,2.17") == .destination(.searchQuery("coffee")))
        #expect(parse("https://maps.apple.com/search?query=coffee%20near%20me") == .destination(.searchQuery("coffee near me")))
    }

    @Test func qHoldingACoordinate() {
        #expect(parse("https://maps.apple.com/?q=41.403629,%202.174356")
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: nil, placeID: nil)))
    }

    // MARK: Directions

    @Test func legacyDirectionsWithAddressDestination() {
        #expect(parse("https://maps.apple.com/?saddr=Current%20Location&daddr=Sagrada+Familia,+Barcelona&dirflg=w")
            == .destination(.address("Sagrada Familia, Barcelona", name: nil)))
    }

    @Test func legacyDirectionsWithCoordinateDestination() {
        #expect(parse("https://maps.apple.com/?saddr=41.387015,2.170047&daddr=41.403629,2.174356&dirflg=w")
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: nil, placeID: nil)))
    }

    @Test func unifiedDirectionsUsesDestinationNotSource() {
        #expect(parse("https://maps.apple.com/directions?source=41.387015,2.170047&destination=41.403629,2.174356&mode=walking")
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: nil, placeID: nil)))
    }

    @Test func directionsWithoutDestinationIsUnusable() {
        #expect(parse("https://maps.apple.com/directions?source=41.387015,2.170047&mode=walking")
            == .unusable("Directions link without a destination"))
        #expect(parse("https://maps.apple.com/?saddr=Home") == .unusable("Directions link without a destination"))
    }

    // MARK: Short links and other hosts

    @Test func shortLinksNeedARedirect() {
        let short = URL(string: "https://maps.apple/p/kE4n0~Tu4fQ0Wg")!
        #expect(AppleMapsLink.parse(short) == .shortLink(short))
        let longShort = URL(string: "https://maps.apple.com/p/kE4n0~Tu4fQ0Wg")!
        #expect(AppleMapsLink.parse(longShort) == .shortLink(longShort))
    }

    @Test func redirectTargetIsParsedLikeAnyLink() {
        // What a short link is expected to land on; confirm on the device.
        #expect(parse("https://maps.apple.com/place?address=Carrer%20de%20Mallorca%20401&coordinate=41.403629,2.174356&name=Sagrada%20Fam%C3%ADlia")
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: "Sagrada Família", placeID: nil)))
    }

    @Test func otherHostsAreIgnored() {
        #expect(parse("https://www.google.com/maps?q=41.4,2.17") == .notAppleMaps)
        #expect(parse("https://maps.apple.com.evil.example/?ll=1,2") == .notAppleMaps)
        #expect(parse("maps://?ll=41.4,2.17") == .notAppleMaps)
    }

    @Test func emptyAppleMapsLinkIsUnusable() {
        #expect(parse("https://maps.apple.com/") == .unusable("No destination in link"))
        #expect(parse("https://maps.apple.com/?q=&ll=") == .unusable("No destination in link"))
    }

    @Test func invalidCoordinatesFallThrough() {
        #expect(parse("https://maps.apple.com/?ll=91,2&q=Nowhere") == .destination(.searchQuery("Nowhere")))
        #expect(parse("https://maps.apple.com/?ll=nan,nan") == .unusable("No destination in link"))
    }

    // MARK: Shared text

    @Test func findsTheLinkInSharedText() {
        let text = "Sagrada Família\nCarrer de Mallorca, 401\nhttps://maps.apple.com/?ll=41.403629,2.174356&q=Sagrada"
        #expect(AppleMapsLink.parse(text: text)
            == .destination(.coordinate(LatLon(latitude: 41.403629, longitude: 2.174356), name: "Sagrada", placeID: nil)))
    }

    @Test func skipsOtherLinksInText() {
        let text = "see https://example.com and https://maps.apple/p/abc123"
        #expect(AppleMapsLink.parse(text: text) == .shortLink(URL(string: "https://maps.apple/p/abc123")!))
        #expect(AppleMapsLink.parse(text: "no links here") == .notAppleMaps)
    }

    @Test func canonicalLinkInRedirectPage() {
        let html = #"<html><head><link rel="canonical" href="https://maps.apple.com/place?coordinate=41.4,2.17&amp;name=X"></head></html>"#
        #expect(LinkResolver.canonicalMapsLink(inHTML: html)?.absoluteString == "https://maps.apple.com/place?coordinate=41.4,2.17&name=X")
        #expect(LinkResolver.canonicalMapsLink(inHTML: "<html></html>") == nil)
    }
}
