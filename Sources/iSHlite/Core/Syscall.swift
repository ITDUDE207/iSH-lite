import Foundation

class LinuxSyscallHandler {
    var outputClosure: (String) -> Void
    
    // Map tracking open files: FileDescriptor Int -> Safe Write Handles
    var fileDescriptorTable: [Int: (url: URL, handle: FileHandle?)] = [:]
    private var nextFD = 3 // Standard input/output/error consume 0, 1, 2
    
    init(output: @escaping (String) -> Void) {
        self.outputClosure = output
    }
    
    func handle(cpu: X86CPU, mem: VirtualMemory) {
        let syscallID = cpu.regs.eax
        
        switch syscallID {
        case 1: // sys_exit
            let status = cpu.regs.ebx
            outputClosure("\n[Process exited with code \(status)]\n")
            cpu.isRunning = false
            
        case 4: // sys_write
            let fd = Int(cpu.regs.ebx)
            let bufferAddress = cpu.regs.ecx
            let count = Int(cpu.regs.edx)
            
            var bytes = [UInt8]()
            for i in 0..<count {
                bytes.append(mem.readByte(address: bufferAddress + UInt32(i)))
            }
            
            if fd == 1 || fd == 2 { // Pipeline straight into terminal screen monitor UI
                if let decodedString = String(bytes: bytes, encoding: .utf8) {
                    outputClosure(decodedString)
                }
                cpu.regs.eax = UInt32(count)
            } else if let tracking = fileDescriptorTable[fd] { // Write permanently to iPad flash storage
                let data = Data(bytes)
                do {
                    if let handle = tracking.handle {
                        try handle.write(contentsOf: data)
                    } else {
                        // Safe fallback write layer if handle wasn't pre-locked
                        let existingData = (try? Data(contentsOf: tracking.url)) ?? Data()
                        try (existingData + data).write(to: tracking.url, options: .atomic)
                    }
                    cpu.regs.eax = UInt32(count)
                } catch {
                    cpu.regs.eax = UInt32(bitPattern: -5) // EIO (Input/output error)
                }
            } else {
                cpu.regs.eax = UInt32(bitPattern: -9) // EBADF (Bad file descriptor)
            }
            
        case 5: // sys_open
            let pathAddress = cpu.regs.ebx
            let rawPath = mem.readString(address: pathAddress)
            let fileURL = mem.rootFSURL.appendingPathComponent(rawPath)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let currentFD = nextFD
                nextFD += 1
                let handle = try? FileHandle(forWritingTo: fileURL)
                handle?.seekToEndOfFile() // Mimic append adjustments
                fileDescriptorTable[currentFD] = (fileURL, handle)
                cpu.regs.eax = UInt32(currentFD)
            } else {
                cpu.regs.eax = UInt32(bitPattern: -2) // ENOENT (No such file)
            }
            
        case 6: // sys_close
            let fd = Int(cpu.regs.ebx)
            if let tracking = fileDescriptorTable[fd] {
                try? tracking.handle?.close()
                fileDescriptorTable.removeValue(forKey: fd)
                cpu.regs.eax = 0 // Success code
            } else {
                cpu.regs.eax = UInt32(bitPattern: -9)
            }
            
        case 8: // sys_creat (Creates or truncates a file)
            let pathAddress = cpu.regs.ebx
            let rawPath = mem.readString(address: pathAddress)
            let fileURL = mem.rootFSURL.appendingPathComponent(rawPath)
            
            // Wipe clean or generate standard empty text containers physically on iOS filesystem
            FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
            
            let currentFD = nextFD
            nextFD += 1
            let handle = try? FileHandle(forWritingTo: fileURL)
            fileDescriptorTable[currentFD] = (fileURL, handle)
            cpu.regs.eax = UInt32(currentFD)
            
        default:
            outputClosure("\n[Syscall Error]: Unimplemented Syscall #\(syscallID)\n")
            cpu.isRunning = false
        }
    }
}

