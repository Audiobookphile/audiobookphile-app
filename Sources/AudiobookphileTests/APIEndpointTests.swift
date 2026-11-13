import XCTest
@testable import Audiobookphile

final class APIEndpointTests: XCTestCase {

    func testCustomDomainRoutesToApiLogin() {
        let url = APIEndpoint.login.urlString(baseURL: "https://mybooks.customdomain.org")
        XCTAssertEqual(url, "https://mybooks.customdomain.org/api/login")
    }

    func testCanonicalWebOriginRoutesToApiLogin() {
        let url = APIEndpoint.login.urlString(baseURL: "https://audiobookphile.app")
        XCTAssertEqual(url, "https://audiobookphile.app/api/login")
    }

    func testDirectSupabaseRoutesToFunctionsApiLogin() {
        let url = APIEndpoint.login.urlString(baseURL: "https://trbxxtanyichimxlbmhy.supabase.co")
        XCTAssertEqual(url, "https://trbxxtanyichimxlbmhy.supabase.co/functions/v1/api/login")
    }

    func testLibrariesPathDoesNotDuplicateApi() {
        let url = APIEndpoint.getLibraries.urlString(baseURL: "https://mybooks.customdomain.org")
        XCTAssertEqual(url, "https://mybooks.customdomain.org/api/libraries")
    }

    func testBaseUrlWithTrailingSlashTrimmed() {
        let url = APIEndpoint.login.urlString(baseURL: "https://books.example.com/")
        XCTAssertEqual(url, "https://books.example.com/api/login")
    }

    func testBaseUrlWithExistingApiSuffix() {
        let url = APIEndpoint.login.urlString(baseURL: "https://books.example.com/api")
        XCTAssertEqual(url, "https://books.example.com/api/login")
    }

    func testAuthRefreshEndpoint() {
        let url = APIEndpoint.authRefresh.urlString(baseURL: "https://books.example.com")
        XCTAssertEqual(url, "https://books.example.com/api/auth/refresh")
    }

    func testSearchSemanticEndpoint() {
        let url = APIEndpoint.searchSemantic.urlString(baseURL: "https://books.example.com")
        XCTAssertEqual(url, "https://books.example.com/api/search-semantic")
    }
}
