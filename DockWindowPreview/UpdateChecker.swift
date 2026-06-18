import AppKit
import Foundation

final class UpdateChecker {
    static let shared = UpdateChecker()

    struct ReleaseInfo {
        let version: String
        let tagName: String
        let name: String
        let htmlURL: URL
        let downloadURL: URL?

        var displayVersion: String {
            tagName.hasPrefix("v") ? tagName : "v\(version)"
        }
    }

    enum CheckResult {
        case updateAvailable(currentVersion: String, latest: ReleaseInfo)
        case upToDate(currentVersion: String, latest: ReleaseInfo)
        case failure(Error)
    }

    private enum UpdateError: LocalizedError {
        case invalidResponse
        case invalidStatusCode(Int)
        case missingReleaseURL

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "更新服务器返回了无法识别的数据。"
            case .invalidStatusCode(let statusCode):
                return "更新检查失败，HTTP 状态码：\(statusCode)。"
            case .missingReleaseURL:
                return "最新版本没有可打开的 Release 页面。"
            }
        }
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: URL?
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
            case assets
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadURL: URL?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/Rainchen537/DockWindowPreview/releases/latest")!
    private let decoder = JSONDecoder()

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func checkForUpdates(completion: @escaping (CheckResult) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("DockWindowPreview/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(UpdateError.invalidResponse))
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                completion(.failure(UpdateError.invalidStatusCode(httpResponse.statusCode)))
                return
            }

            guard let data else {
                completion(.failure(UpdateError.invalidResponse))
                return
            }

            do {
                let release = try decoder.decode(GitHubRelease.self, from: data)
                guard let htmlURL = release.htmlURL else {
                    completion(.failure(UpdateError.missingReleaseURL))
                    return
                }

                let latest = ReleaseInfo(
                    version: normalizedVersionString(release.tagName),
                    tagName: release.tagName,
                    name: release.name ?? release.tagName,
                    htmlURL: htmlURL,
                    downloadURL: release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })?.browserDownloadURL
                )

                if compareVersion(latest.version, to: currentVersion) == .orderedDescending {
                    completion(.updateAvailable(currentVersion: currentVersion, latest: latest))
                } else {
                    completion(.upToDate(currentVersion: currentVersion, latest: latest))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func openReleasePage(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(release.htmlURL)
    }

    func openDownloadOrReleasePage(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(release.downloadURL ?? release.htmlURL)
    }

    private func normalizedVersionString(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func compareVersion(_ lhs: String, to rhs: String) -> ComparisonResult {
        let lhsParts = numericParts(from: lhs)
        let rhsParts = numericParts(from: rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0

            if left > right { return .orderedDescending }
            if left < right { return .orderedAscending }
        }

        return .orderedSame
    }

    private func numericParts(from string: String) -> [Int] {
        let normalized = normalizedVersionString(string)
        let regex = try? NSRegularExpression(pattern: "\\d+")
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = regex?.matches(in: normalized, range: range) ?? []

        return matches.compactMap { match in
            guard let range = Range(match.range, in: normalized) else { return nil }
            return Int(normalized[range])
        }
    }
}
