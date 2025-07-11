//
//  SimpleZipExtractor.swift
//  Shiori Reader
//
//  Created by Claude on 1/10/25.
//

import Foundation
import Compression

/// Simple ZIP file extractor for basic ZIP files
/// Note: This is a simplified implementation. For production use, consider ZIPFoundation or similar
class SimpleZipExtractor {
    
    enum ZipError: Error, LocalizedError {
        case invalidZipFile
        case corruptedData
        case unsupportedCompression
        case fileTooLarge
        
        var errorDescription: String? {
            switch self {
            case .invalidZipFile:
                return "Invalid ZIP file format"
            case .corruptedData:
                return "ZIP file data is corrupted"
            case .unsupportedCompression:
                return "Unsupported compression method"
            case .fileTooLarge:
                return "File is too large to extract"
            }
        }
    }
    
    /// Extract files from ZIP data
    static func extractFiles(from zipData: Data) throws -> [String: Data] {
        var extractedFiles: [String: Data] = [:]
        var offset = 0
        
        // Find central directory end record
        guard let centralDirEndOffset = findCentralDirectoryEnd(in: zipData) else {
            throw ZipError.invalidZipFile
        }
        
        // Read central directory end record
        let centralDirEnd = zipData.subdata(in: centralDirEndOffset..<zipData.count)
        guard centralDirEnd.count >= 22 else {
            throw ZipError.invalidZipFile
        }
        
        // Extract central directory info
        let centralDirOffset = centralDirEnd.readUInt32(at: 16)
        let entryCount = centralDirEnd.readUInt16(at: 10)
        
        // Read central directory entries
        var currentOffset = Int(centralDirOffset)
        
        for _ in 0..<entryCount {
            guard currentOffset + 46 <= zipData.count else {
                throw ZipError.invalidZipFile
            }
            
            let entry = zipData.subdata(in: currentOffset..<currentOffset + 46)
            
            // Verify central directory entry signature
            guard entry.readUInt32(at: 0) == 0x02014b50 else {
                throw ZipError.invalidZipFile
            }
            
            let compressionMethod = entry.readUInt16(at: 10)
            let compressedSize = entry.readUInt32(at: 20)
            let uncompressedSize = entry.readUInt32(at: 24)
            let filenameLength = entry.readUInt16(at: 28)
            let extraFieldLength = entry.readUInt16(at: 30)
            let commentLength = entry.readUInt16(at: 32)
            let localHeaderOffset = entry.readUInt32(at: 42)
            
            currentOffset += 46
            
            // Read filename
            guard currentOffset + Int(filenameLength) <= zipData.count else {
                throw ZipError.invalidZipFile
            }
            
            let filenameData = zipData.subdata(in: currentOffset..<currentOffset + Int(filenameLength))
            guard let filename = String(data: filenameData, encoding: .utf8) else {
                currentOffset += Int(filenameLength) + Int(extraFieldLength) + Int(commentLength)
                continue
            }
            
            currentOffset += Int(filenameLength) + Int(extraFieldLength) + Int(commentLength)
            
            // Skip directories
            if filename.hasSuffix("/") {
                continue
            }
            
            // Extract file data
            do {
                let fileData = try extractFileData(
                    from: zipData,
                    localHeaderOffset: Int(localHeaderOffset),
                    compressionMethod: compressionMethod,
                    compressedSize: Int(compressedSize),
                    uncompressedSize: Int(uncompressedSize)
                )
                extractedFiles[filename] = fileData
            } catch {
                // Skip files that can't be extracted but continue with others
                continue
            }
        }
        
        return extractedFiles
    }
    
    // MARK: - Private Methods
    
    private static func findCentralDirectoryEnd(in data: Data) -> Int? {
        // Look for central directory end signature from the end of the file
        let signature: UInt32 = 0x06054b50
        
        for i in stride(from: data.count - 22, through: max(0, data.count - 65536), by: -1) {
            if i + 4 <= data.count {
                let value = data.readUInt32(at: i)
                if value == signature {
                    return i
                }
            }
        }
        
        return nil
    }
    
    private static func extractFileData(
        from zipData: Data,
        localHeaderOffset: Int,
        compressionMethod: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) throws -> Data {
        
        guard localHeaderOffset + 30 <= zipData.count else {
            throw ZipError.invalidZipFile
        }
        
        let localHeader = zipData.subdata(in: localHeaderOffset..<localHeaderOffset + 30)
        
        // Verify local file header signature
        guard localHeader.readUInt32(at: 0) == 0x04034b50 else {
            throw ZipError.invalidZipFile
        }
        
        let filenameLength = localHeader.readUInt16(at: 26)
        let extraFieldLength = localHeader.readUInt16(at: 28)
        
        let dataOffset = localHeaderOffset + 30 + Int(filenameLength) + Int(extraFieldLength)
        
        guard dataOffset + compressedSize <= zipData.count else {
            throw ZipError.invalidZipFile
        }
        
        let compressedData = zipData.subdata(in: dataOffset..<dataOffset + compressedSize)
        
        switch compressionMethod {
        case 0: // No compression
            return compressedData
            
        case 8: // Deflate compression
            return try decompressDeflateData(compressedData, uncompressedSize: uncompressedSize)
            
        default:
            throw ZipError.unsupportedCompression
        }
    }
    
    private static func decompressDeflateData(_ data: Data, uncompressedSize: Int) throws -> Data {
        // Limit uncompressed size to prevent memory issues
        guard uncompressedSize < 100 * 1024 * 1024 else { // 100MB limit
            throw ZipError.fileTooLarge
        }
        
        let decompressedData = try data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, uncompressedSize,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, COMPRESSION_ZLIB
            )
            
            guard decompressedSize > 0 else {
                throw ZipError.corruptedData
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
        
        return decompressedData
    }
}

// MARK: - Data Extension for Reading Binary Data

extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return self.withUnsafeBytes { bytes in
            let pointer = bytes.baseAddress!.advanced(by: offset).assumingMemoryBound(to: UInt16.self)
            return UInt16(littleEndian: pointer.pointee)
        }
    }
    
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return self.withUnsafeBytes { bytes in
            let pointer = bytes.baseAddress!.advanced(by: offset).assumingMemoryBound(to: UInt32.self)
            return UInt32(littleEndian: pointer.pointee)
        }
    }
}
