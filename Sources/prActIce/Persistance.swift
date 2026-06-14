// Persistance.swift

import Foundation

class Persistance<T: Codable>: @unchecked Sendable {
    private let fileURL: URL

    init(filename: String){
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("prActIce")
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent(filename)
    }

    func read() -> T? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    func save(_ value: T) {
        let data = try? JSONEncoder().encode(value)
        try? data?.write(to: fileURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}