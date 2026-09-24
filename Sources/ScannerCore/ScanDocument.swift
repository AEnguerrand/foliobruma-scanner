import Foundation

public struct ScanDocument: Codable {
  public var title: String
  public var metadata: ItemMetadata?
  public var automation: SessionAutomation?
  public var pages: [ScanPage]
  public var rejected: [RejectedScan]?
  public var resolvedRejections: [String]?

  public init(title: String, metadata: ItemMetadata? = nil, automation: SessionAutomation? = nil,
              pages: [ScanPage] = [], rejected: [RejectedScan]? = [], resolvedRejections: [String]? = []) {
    self.title = title
    self.metadata = metadata
    self.automation = automation
    self.pages = pages
    self.rejected = rejected
    self.resolvedRejections = resolvedRejections
  }
}

// Optional on old sessions. New sessions keep automation off until configured.
public struct SessionAutomation: Codable, Equatable {
  public var upload: Bool
  public var printLabel: Bool
  public var printerName: String

  public init(upload: Bool = false, printLabel: Bool = false, printerName: String = "") {
    self.upload = upload
    self.printLabel = printLabel
    self.printerName = printerName
  }
}
