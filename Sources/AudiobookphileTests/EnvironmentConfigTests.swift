import XCTest
@testable import Audiobookphile

final class EnvironmentConfigTests: XCTestCase {

    func testServerURLResolution() {
        let server = EnvironmentConfig.serverURL
        XCTAssertFalse(server.isEmpty)
        XCTAssertFalse(server.hasSuffix("/api"))
        XCTAssertTrue(server.starts(with: "http"))
    }

    func testSupabaseURLDefault() {
        let url = EnvironmentConfig.supabaseURL
        XCTAssertFalse(url.isEmpty)
        XCTAssertTrue(url.contains("supabase.co"))
        XCTAssertFalse(url.contains("test.supabase.co"))
    }

    func testSupabaseAnonKeyResolved() {
        let key = EnvironmentConfig.supabaseAnonKey
        XCTAssertFalse(key.isEmpty)
        XCTAssertNotEqual(key, "testkey")
        XCTAssertTrue(key.starts(with: "eyJ"))
    }
}
