//
//  DeveloperDiskManager.swift
//  AltServer
//
//  Created by Riley Testut on 2/19/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine
import AltSign

enum DeveloperDiskError: LocalizedError
{
    case unknownDownloadURL
    case unsupportedOperatingSystem
    case downloadedDiskNotFound
    
    var errorDescription: String? {
        switch self
        {
        case .unknownDownloadURL: return NSLocalizedString("The URL to download the Developer disk image could not be determined.", comment: "")
        case .unsupportedOperatingSystem: return NSLocalizedString("The device's operating system does not support installing Developer disk images.", comment: "")
        case .downloadedDiskNotFound: return NSLocalizedString("DeveloperDiskImage.dmg and its signature could not be found in the downloaded archive.", comment: "")
        }
    }
}

private extension URL
{
    #if STAGING
    static let developerDiskDownloadURLs = URL(string: "https://f000.backblazeb2.com/file/altstore-staging/altserver/developerdisks.json")!
    #else
    static let developerDiskDownloadURLs = URL(string: "https://cdn.altstore.io/file/altstore/altserver/developerdisks.json")!
    #endif
}

private extension DeveloperDiskManager
{
    struct FetchURLsResponse: Decodable
    {
        struct Disks: Decodable
        {
            var iOS: [String: DeveloperDiskURL]?
            var tvOS: [String: DeveloperDiskURL]?
        }
        
        var version: Int
        var disks: Disks
    }
    
    enum DeveloperDiskURL: Decodable
    {
        case archive(URL)
        case separate(diskURL: URL, signatureURL: URL)
        
        private enum CodingKeys: CodingKey
        {
            case archive
            case disk
            case signature
        }
        
        init(from decoder: Decoder) throws
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if container.contains(.archive)
            {
                let archiveURL = try container.decode(URL.self, forKey: .archive)
                self = .archive(archiveURL)
            }
            else
            {
                let diskURL = try container.decode(URL.self, forKey: .disk)
                let signatureURL = try container.decode(URL.self, forKey: .signature)
                self = .separate(diskURL: diskURL, signatureURL: signatureURL)
            }
        }
    }
}

class DeveloperDiskManager
{
    func downloadDeveloperDisk(for device: ALTDevice, completionHandler: @escaping (Result<(URL, URL), Error>) -> Void)
    {
        let osVersion = "\(device.osVersion.majorVersion).\(device.osVersion.minorVersion)"
        let osKeyPath: KeyPath<FetchURLsResponse.Disks, [String: DeveloperDiskURL]?>
        
        switch device.type {
            case .iphone, .ipad: osKeyPath = \FetchURLsResponse.Disks.iOS
            case .appletv: osKeyPath = \FetchURLsResponse.Disks.tvOS
            default: return completionHandler(.failure(DeveloperDiskError.unsupportedOperatingSystem))
        }
        
        let developerDiskDirectoryURL = FileManager.default.developerDisksDirectory.appendingPathComponent(osVersion)
        let developerDiskURL = developerDiskDirectoryURL.appendingPathComponent("DeveloperDiskImage.dmg")
        let developerDiskSignatureURL = developerDiskDirectoryURL.appendingPathComponent("DeveloperDiskImage.dmg.signature")
        
        guard !FileManager.default.fileExists(atPath: developerDiskURL.path) || !FileManager.default.fileExists(atPath: developerDiskSignatureURL.path) else {
            return completionHandler(.success((developerDiskURL, developerDiskSignatureURL)))
        }
        
        var cancellables = Set<AnyCancellable>()
        
        self.fetchDeveloperDiskURLs().tryMap { developerDiskURLs -> DeveloperDiskURL in
            guard let diskURL = developerDiskURLs[keyPath: osKeyPath]?[osVersion] else {
                throw DeveloperDiskError.unknownDownloadURL
            }
            
            return diskURL
        }.flatMap { diskURL -> AnyPublisher<(URL, URL), Error> in
            switch diskURL {
                case .archive(let archiveURL): return self.downloadDiskArchive(from: archiveURL)
                case .separate(let diskURL, let signatureURL): return self.downloadDisk(from: diskURL, signatureURL: signatureURL)
            }
        }.tryMap { (diskFileURL, signatureFileURL) -> (URL, URL) in
            let developerDiskDirectoryURL = FileManager.default.developerDisksDirectory.appendingPathComponent(osVersion)
            try FileManager.default.createDirectory(at: developerDiskDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            
            try FileManager.default.copyItem(at: diskFileURL, to: developerDiskURL)
            try FileManager.default.copyItem(at: signatureFileURL, to: developerDiskSignatureURL)
            
            return (diskFileURL, signatureFileURL)
        }.sink(receiveFailure: {
            completionHandler(.failure($0))
        }, receiveValue: { urls in
            completionHandler(.success(urls))
        }).store(in: &cancellables)
    }
}

private extension DeveloperDiskManager
{
    func fetchDeveloperDiskURLs() -> AnyPublisher<FetchURLsResponse.Disks, Error>
    {
        URLSession.shared.dataTaskPublisher(for: .developerDiskDownloadURLs).tryMap {
            try JSONDecoder().decode(FetchURLsResponse.self, from: $0.data).disks
        }.eraseToAnyPublisher()
    }
    
    func downloadDiskArchive(from url: URL) -> AnyPublisher<(URL, URL), Error>
    {
        URLSession.shared.downloadTaskPublisher(for: url).tryMap { (url, response) -> (URL, URL) in
            let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
            
            try FileManager.default.unzipArchive(at: url, toDirectory: temporaryDirectory)
            
            guard let enumerator = FileManager.default.enumerator(at: temporaryDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSURLErrorKey: temporaryDirectory])
            }
            
            let (tempDiskFileURL, tempSignatureFileURL) = enumerator.compactMap { $0 as? URL }.reduce(into: (nil, nil) as (URL?, URL?)) { pair, url in
                switch url.pathExtension.lowercased() {
                case "dmg": pair.0 = url
                case "signature": pair.1 = url
                default: break
                }
            }
            
            guard let diskFileURL = tempDiskFileURL, let signatureFileURL = tempSignatureFileURL else {
                throw DeveloperDiskError.downloadedDiskNotFound
            }
            
            return (diskFileURL, signatureFileURL)
        }.eraseToAnyPublisher()
    }
    
    func downloadDisk(from diskURL: URL, signatureURL: URL) -> AnyPublisher<(URL, URL), Error>
    {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do { try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil) }
        catch { return Fail(error: error).eraseToAnyPublisher() }
        
        func pipe(url: URL, toTemporaryName name: String) throws -> URL {
            let destinationURL = temporaryDirectory.appendingPathComponent(name)
            try FileManager.default.copyItem(at: url, to: destinationURL)
            return destinationURL
        }
        
        return Publishers.Zip(
            URLSession.shared.downloadTaskPublisher(for: diskURL),
            URLSession.shared.downloadTaskPublisher(for: signatureURL)
        ).tryMap { (disk, signature) in
            (disk: try pipe(url: disk.url, toTemporaryName: "DeveloperDiskImage.dmg"), signature: try pipe(url: signature.url, toTemporaryName: "DeveloperDiskImage.dmg.signature"))
        }.eraseToAnyPublisher()
    }
}
