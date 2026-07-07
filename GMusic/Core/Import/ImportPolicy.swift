import Foundation

struct ImportPolicy: Codable {
    var deleteSourceAfterSuccessfulImport: Bool = true
    var skipExactDuplicates: Bool = true
    var scanDownloadsOnLaunch: Bool = false
}
