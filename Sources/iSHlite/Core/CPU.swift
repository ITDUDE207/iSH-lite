import Foundation

struct X86Registers {
    var eax: UInt32 = 0 // Accumulator (Syscall IDs, returns)
    var ebx: UInt32 = 0 // Base register (Syscall Arg 1)
    var ecx: UInt32 = 0 // Counter register (Syscall Arg 2 / Buffer ptr)
    var edx: UInt32 = 0 // Data register (Syscall Arg 3 / Buffer len)
    var esp: UInt32 = 1024 * 1024 - 4 // Stack Pointer (Starts at top of RAM)
    var eip: UInt32 = 0 // Instruction Pointer
}

struct CPUFlags {
    var zero: Bool = false
    var sign: Bool = false
}

class X86CPU {
    var regs = X86Registers()
    var flags = CPUFlags()
    var mem: VirtualMemory
    var isRunning = false
    
    var syscallHandler: LinuxSyscallHandler?
    var onConsoleOutput: ((String) -> Void)?
    
    init(memory: VirtualMemory) {
        self.mem = memory
    }
    
    func start() {
        isRunning = true
        DispatchQueue.global(qos: .userInteractive).async {
            while self.isRunning {
                self.step()
            }
        }
    }
    
    func step() {
        let currentPC = regs.eip
        let opcode = mem.readByte(address: currentPC)
        regs.eip += 1
        
        switch opcode {
        case 0x90: // NOP (No Operation)
            break
            
        case 0xB8: // MOV EAX, Imm32 (Load 32-bit value into EAX)
            regs.eax = readImm32()
            
        case 0xBB: // MOV EBX, Imm32 (Load 32-bit value into EBX)
            regs.ebx = readImm32()
            
        case 0xB9: // MOV ECX, Imm32 (Load 32-bit value into ECX)
            regs.ecx = readImm32()
            
        case 0xBA: // MOV EDX, Imm32 (Load 32-bit value into EDX)
            regs.edx = readImm32()
            
        case 0x3D: // CMP EAX, Imm32 (Compare EAX against immediate value)
            let val = readImm32()
            flags.zero = (regs.eax == val)
            flags.sign = (Int32(regs.eax) - Int32(val) < 0)
            
        case 0x74: // JZ Imm8 (Jump if Zero flag is true)
            let offset = Int8(mem.readByte(address: regs.eip))
            regs.eip += 1
            if flags.zero {
                regs.eip = UInt32(Int32(regs.eip) + Int32(offset))
            }
            
        case 0xEB: // JMP Imm8 (Unconditional Short Jump)
            let offset = Int8(mem.readByte(address: regs.eip))
            regs.eip += 1
            regs.eip = UInt32(Int32(regs.eip) + Int32(offset))
            
        case 0xCD: // INT Imm8 (Software Interrupt)
            let vector = mem.readByte(address: regs.eip)
            regs.eip += 1
            if vector == 0x80 { // Linux Syscall Vector
                syscallHandler?.handle(cpu: self, mem: mem)
            }
            
        default:
            onConsoleOutput?("\n[Kernel Panic]: Invalid x86 Opcode 0x\(String(opcode, radix: 16).uppercased()) at EIP 0x\(String(currentPC, radix: 16))\n")
            isRunning = false
        }
    }
    
    private func readImm32() -> UInt32 {
        let b1 = UInt32(mem.readByte(address: regs.eip))
        let b2 = UInt32(mem.readByte(address: regs.eip + 1)) << 8
        let b3 = UInt32(mem.readByte(address: regs.eip + 2)) << 16
        let b4 = UInt32(mem.readByte(address: regs.eip + 3)) << 24
        regs.eip += 4
        return b1 | b2 | b3 | b4
    }
}
