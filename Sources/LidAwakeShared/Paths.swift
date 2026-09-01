import Darwin
import Foundation

public enum LidAwakePaths {
  public static func supportDirectory(homeDirectory: String) -> URL {
    URL(fileURLWithPath: homeDirectory, isDirectory: true)
      .appendingPathComponent("Library/Application Support/LidAwake", isDirectory: true)
  }

  public static func leaseFile(homeDirectory: String) -> URL {
    supportDirectory(homeDirectory: homeDirectory).appendingPathComponent("lease.json")
  }

  public static func statusFile(homeDirectory: String) -> URL {
    supportDirectory(homeDirectory: homeDirectory).appendingPathComponent("status.json")
  }
}

public enum SecureJSONFile {
  private static let maximumFileSize: off_t = 65_536

  public static func write<T: Encodable>(_ value: T, to url: URL, owner: (uid_t, gid_t)? = nil)
    throws
  {
    let data = try JSONEncoder.lidAwake.encode(value)
    let manager = FileManager.default
    let directory = url.deletingLastPathComponent()

    // A privileged caller must never create or take ownership of a path selected by an
    // unprivileged user. The GUI creates this directory before the helper publishes status.
    if owner == nil {
      try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    let directoryDescriptor = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
    guard directoryDescriptor >= 0 else { throw currentPOSIXError() }
    defer { close(directoryDescriptor) }

    var directoryMetadata = stat()
    guard fstat(directoryDescriptor, &directoryMetadata) == 0 else { throw currentPOSIXError() }
    guard (directoryMetadata.st_mode & S_IFMT) == S_IFDIR else {
      throw POSIXError(.ENOTDIR)
    }

    let expectedOwner = owner?.0 ?? geteuid()
    guard directoryMetadata.st_uid == expectedOwner else { throw POSIXError(.EPERM) }

    if owner == nil {
      guard fchmod(directoryDescriptor, 0o700) == 0 else { throw currentPOSIXError() }
    } else {
      guard (directoryMetadata.st_mode & 0o077) == 0 else { throw POSIXError(.EPERM) }
    }

    let filename = url.lastPathComponent
    guard !filename.isEmpty, filename != ".", filename != "..", !filename.contains("/") else {
      throw POSIXError(.EINVAL)
    }

    let temporaryName = ".\(filename).tmp-\(UUID().uuidString)"
    let temporaryDescriptor = openat(
      directoryDescriptor,
      temporaryName,
      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW,
      0o600
    )
    guard temporaryDescriptor >= 0 else { throw currentPOSIXError() }

    var temporaryFileExists = true
    defer {
      close(temporaryDescriptor)
      if temporaryFileExists {
        _ = unlinkat(directoryDescriptor, temporaryName, 0)
      }
    }

    guard fchmod(temporaryDescriptor, 0o600) == 0 else { throw currentPOSIXError() }
    if let owner {
      guard fchown(temporaryDescriptor, owner.0, owner.1) == 0 else { throw currentPOSIXError() }
    }

    try writeAll(data, to: temporaryDescriptor)
    guard fsync(temporaryDescriptor) == 0 else { throw currentPOSIXError() }
    guard renameat(directoryDescriptor, temporaryName, directoryDescriptor, filename) == 0 else {
      throw currentPOSIXError()
    }
    temporaryFileExists = false
    guard fsync(directoryDescriptor) == 0 else { throw currentPOSIXError() }
  }

  public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
    guard descriptor >= 0 else { throw currentPOSIXError() }
    defer { close(descriptor) }

    var metadata = stat()
    guard fstat(descriptor, &metadata) == 0 else { throw currentPOSIXError() }
    guard (metadata.st_mode & S_IFMT) == S_IFREG else { throw POSIXError(.EINVAL) }
    guard metadata.st_size >= 0, metadata.st_size <= maximumFileSize else {
      throw POSIXError(.EFBIG)
    }

    var data = Data()
    data.reserveCapacity(Int(metadata.st_size))
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while true {
      let count = Darwin.read(descriptor, &buffer, buffer.count)
      if count == 0 { break }
      if count < 0 {
        if errno == EINTR { continue }
        throw currentPOSIXError()
      }
      guard data.count + count <= Int(maximumFileSize) else { throw POSIXError(.EFBIG) }
      data.append(contentsOf: buffer.prefix(count))
    }
    return try JSONDecoder.lidAwake.decode(type, from: data)
  }

  private static func writeAll(_ data: Data, to descriptor: Int32) throws {
    try data.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { return }
      var offset = 0
      while offset < bytes.count {
        let count = Darwin.write(
          descriptor,
          baseAddress.advanced(by: offset),
          bytes.count - offset
        )
        if count < 0 {
          if errno == EINTR { continue }
          throw currentPOSIXError()
        }
        guard count > 0 else { throw POSIXError(.EIO) }
        offset += count
      }
    }
  }

  private static func currentPOSIXError() -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
  }
}

extension JSONEncoder {
  public static var lidAwake: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}

extension JSONDecoder {
  public static var lidAwake: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
