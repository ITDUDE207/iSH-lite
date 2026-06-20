import Foundation

class LinuxSyscallHandler {
    var outputClosure: (String) -> Void
    
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
            let fd = cpu.regs.ebx
            let bufferAddress = cpu.regs.ecx
            let count = cpu.regs.edx
            
            if fd == 1 || fd == 2 { // stdout / stderr
                var bytes = [UInt8]()
                for i in 0..<count {
                    bytes.append(mem.readByte(address: bufferAddress + i))
                }
                if let decodedString = String(bytes: bytes, encoding: .utf8) {
                    outputClosure(decodedString)
                }
                cpu.regs.eax = count // Return bytes written
            } else {
                cpu.regs.eax = UInt32(bitPattern: -9) // EBADF (Bad file descriptor)
            }
            
        case 5: // sys_open
            let pathAddress = cpu.regs.ebx
            let path = mem.readString(address: pathAddress)
            
            if let fileContents = mem.virtualFiles[path] {
                // Return a mock File Descriptor safely out of lower range bounds
                cpu.regs.eax = 10 
                outputClosure("[Kernel Log: Opened virtual path \(path)]\n")
            } else {
                cpu.regs.eax = UInt32(bitPattern: -2) // ENOENT (No such file or directory)
            }
            
        default:
            outputClosure("\n[Syscall Error]: Unimplemented Linux System Call #\(syscallID)\n")
            cpu.isRunning = false
        }
    }
}
