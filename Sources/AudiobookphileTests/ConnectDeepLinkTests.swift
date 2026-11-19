import XCTest
@testable import Audiobookphile

final class ConnectDeepLinkTests: XCTestCase {

    func testParseFullDeepLinkWithAutoLogin() {
        guard let url = URL(string: "audiobookphile://connect?server=https%3A%2F%2Fdemo.audiobookphile.app&username=admin&password=secret123&autoLogin=1") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.server, "https://demo.audiobookphile.app")
        XCTAssertEqual(link?.username, "admin")
        XCTAssertEqual(link?.password, "secret123")
        XCTAssertEqual(link?.autoLogin, true)
    }

    func testParseFullDeepLinkWithAutoLoginTrue() {
        guard let url = URL(string: "audiobookphile://connect?server=https%3A%2F%2Fdemo.audiobookphile.app&username=user1&password=pass&autoLogin=true") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.server, "https://demo.audiobookphile.app")
        XCTAssertEqual(link?.username, "user1")
        XCTAssertEqual(link?.password, "pass")
        XCTAssertEqual(link?.autoLogin, true)
    }

    func testParseServerOnly() {
        guard let url = URL(string: "audiobookphile://connect?server=https%3A%2F%2Fmybooks.org") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.server, "https://mybooks.org")
        XCTAssertNil(link?.username)
        XCTAssertNil(link?.password)
        XCTAssertEqual(link?.autoLogin, false)
    }

    func testParseWithSlashPath() {
        guard let url = URL(string: "audiobookphile:///connect?server=https%3A%2F%2Fmybooks.org") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.server, "https://mybooks.org")
    }

    func testRejectsInvalidScheme() {
        guard let url = URL(string: "https://connect?server=https%3A%2F%2Fdemo.audiobookphile.app") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNil(link)
    }

    func testRejectsUnknownHost() {
        guard let url = URL(string: "audiobookphile://other?server=https%3A%2F%2Fdemo.audiobookphile.app") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNil(link)
    }

    func testRejectsMissingServer() {
        guard let url = URL(string: "audiobookphile://connect?username=admin&autoLogin=1") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNil(link)
    }

    func testRejectsEmptyServer() {
        guard let url = URL(string: "audiobookphile://connect?server=&username=admin") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = ConnectDeepLink.parse(url)
        XCTAssertNil(link)
    }

    func testParseAudiobookDeepLinkWithTimestamp() {
        guard let url = URL(string: "audiobookphile://item/book-456?t=1250&play=1") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = AudiobookDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.itemId, "book-456")
        XCTAssertEqual(link?.timestamp, 1250.0)
        XCTAssertEqual(link?.autoPlay, true)
    }

    func testParseAudiobookPlayDeepLink() {
        guard let url = URL(string: "audiobookphile://play/book-789?t=360") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = AudiobookDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.itemId, "book-789")
        XCTAssertEqual(link?.timestamp, 360.0)
        XCTAssertEqual(link?.autoPlay, true)
    }

    func testParseWebShareLinkWithTimestamp() {
        guard let url = URL(string: "https://demo.audiobookphile.app/share/great-gatsby?t=4820") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = AudiobookDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.itemId, "great-gatsby")
        XCTAssertEqual(link?.timestamp, 4820.0)
        XCTAssertEqual(link?.autoPlay, false)
    }

    func testParseWebLibraryItemLink() {
        guard let url = URL(string: "https://demo.audiobookphile.app/library/default/item/item-xyz?t=150&play=true") else {
            XCTFail("Failed to construct URL")
            return
        }

        let link = AudiobookDeepLink.parse(url)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.itemId, "item-xyz")
        XCTAssertEqual(link?.timestamp, 150.0)
        XCTAssertEqual(link?.autoPlay, true)
    }
}
