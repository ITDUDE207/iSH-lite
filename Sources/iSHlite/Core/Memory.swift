import Foundation

class VirtualMemory {
    var ram: [UInt8]
    let size: Int
    
    // Physical root path inside iPad app sandbox
    var rootFSURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("rootfs", isDirectory: true)
    }
    
    init(sizeInBytes: Int = 1024 * 1024) {
        self.size = sizeInBytes
        self.ram = Array(repeating: 0, count: sizeInBytes)
        setupPermanentRootFS()
    }
    
    // Ensures a local Linux directory layout exists on the iPad file storage
    private func setupPermanentRootFS() {
        let fm = FileManager.default
        let folders = ["bin", "etc", "home", "root", "tmp"]
        
        for folder in folders {
            let targetDir = rootFSURL.appendingPathComponent(folder, isDirectory: true)
            if !fm.fileExists(atPath: targetDir.path) {
                try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        // Write default system assets if missing
        writeSystemAsset(path: "etc/issue", content: "Welcome to iSH-Lite (A lighter version of iSH. We have no accoisation with thebaselab.)\n")
        writeSystemAsset(path: "etc/hostname", content: "ipad-emulator\n")
    }
    
    private func writeSystemAsset(path: String, content: String) {
        let fileURL = rootFSURL.appendingPathComponent(path)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    // Core memory functions
    func writeByte(address: UInt32, value: UInt8) {
        let addr = Int(address)
        if addr >= 0 && addr < size { ram[addr] = value }
    }
    
    func readByte(address: UInt32) -> UInt8 {
        let addr = Int(address)
        return (addr >= 0 && addr < size) ? ram[addr] : 0
    }
    
    func readString(address: UInt32) -> String {
        var addr = Int(address)
        var bytes = [UInt8]()
        while addr < size {
            let byte = ram[addr]
            if byte == 0 { break }
            bytes.append(byte)
            addr += 1
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
    
    func loadPayload(bytes: [UInt8], atAddress address: UInt32) {
        let start = Int(address)
        for (index, byte) in bytes.enumerated() {
            if start + index < size { ram[start + index] = byte }
        }
    }
}
