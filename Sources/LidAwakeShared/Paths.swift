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
  public static func write<T: Encodable>(_ value: T, to url: URL, owner: (uid_t, gid_t)? = nil)
    throws
  {
    let manager = FileManager.default
    let directory = url.deletingLastPathComponent()
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    if let owner, chown(directory.path, owner.0, owner.1) != 0 {
      let code = errno
      throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
    let data = try JSONEncoder.lidAwake.encode(value)
    let temporary = url.appendingPathExtension("tmp-\(UUID().uuidString)")
    try data.write(to: temporary, options: [.atomic])
    try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
    if let owner {
      guard chown(temporary.path, owner.0, owner.1) == 0 else {
        let code = errno
        try? manager.removeItem(at: temporary)
        throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
      }
    }
    guard rename(temporary.path, url.path) == 0 else {
      let code = errno
      try? manager.removeItem(at: temporary)
      throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
  }

  public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    let data = try Data(contentsOf: url)
    return try JSONDecoder.lidAwake.decode(type, from: data)
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
