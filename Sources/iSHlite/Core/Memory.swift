import Foundation

class VirtualMemory {
    var ram: [UInt8]
    let size: Int
    
    // Virtual File System Map
    var virtualFiles: [String: String] = [
        "/etc/hostname": "localhost\n",
        "/etc/issue": "Welcome to iSH-Lite (Alpine Linux Emulation Layer)\n",
        "/proc/version": "Linux version 4.19.0-ish-lite (swift@ipad)\n"
    ]
    
    init(sizeInBytes: Int = 1024 * 1024) { // 1 Megabyte Virtual RAM allocation
        self.size = sizeInBytes
        self.ram = Array(repeating: 0, count: sizeInBytes)
    }
    
    func writeByte(address: UInt32, value: UInt8) {
        let addr = Int(address)
        if addr >= 0 && addr < size {
            ram[addr] = value
        }
    }
    
    func readByte(address: UInt32) -> UInt8 {
        let addr = Int(address)
        if addr >= 0 && addr < size {
            return ram[addr]
        }
        return 0
    }
    
    func readString(address: UInt32) -> String {
        var addr = Int(address)
        var bytes = [UInt8]()
        while addr < size {
            let byte = ram[addr]
            if byte == 0 { break } // Null terminator
            bytes.append(byte)
            addr += 1
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
    
    func loadPayload(bytes: [UInt8], atAddress address: UInt32) {
        let start = Int(address)
        for (index, byte) in bytes.enumerated() {
            if start + index < size {
                ram[start + index] = byte
            }
        }
    }
}
