import Foundation

/// 数据导出服务
actor DataExportService {
    
    // MARK: - Properties
    
    private let storage: LocalStorageAdapter
    
    // MARK: - Initialization
    
    init(storage: LocalStorageAdapter = .shared) {
        self.storage = storage
    }
    
    // MARK: - Public Methods
    
    /// 导出所有用户数据
    /// - Returns: JSON 数据
    func exportAllData() async throws -> Data {
        let jsonString = try await storage.exportAll()
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "DataExportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert to data"])
        }
        return data
    }
    
    /// 导出数据到文件 URL
    /// - Returns: 临时文件 URL
    func exportToFile() async throws -> URL {
        let data = try await exportAllData()
        
        let fileName = "smart_arrival_export_\(formatDate(Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    // MARK: - Private Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

// MARK: - Shared Instance

extension DataExportService {
    static let shared = DataExportService()
}
