import SwiftUI

struct ContentView: View {
    @State private var consoleBuffer: String = "iSH-Lite x86 Framework initialized.\nType 'help' or 'run-binary' to trigger emulation pipeline.\n\nlocalhost:~# "
    @State private var textInput: String = ""
    
    // Core runtime instances
    let memoryInstance = VirtualMemory()
    @State private var cpuInstance: X86CPU?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Terminal Monitor Screen
            ScrollViewReader { proxy in
                ScrollView {
                    Text(consoleBuffer)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("ConsoleBottom")
                }
                .background(Color.black)
                .onChange(of: consoleBuffer) { _ in
                    proxy.scrollTo("ConsoleBottom", anchor: .bottom)
                }
            }
            
            // Console Input Bar
            HStack {
                Text("localhost:~#")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.cyan)
                    .bold()
                
                TextField("", text: $textInput)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrelation(true)
                    .onSubmit {
                        handleCommand(textInput)
                    }
            }
            .padding()
            .background(Color(white: 0.12))
        }
        .onAppear {
            let cpu = X86CPU(memory: memoryInstance)
            let syscall = LinuxSyscallHandler(output: { text in
                DispatchQueue.main.async {
                    self.consoleBuffer += text
                }
            })
            cpu.syscallHandler = syscall
            cpu.onConsoleOutput = { text in
                DispatchQueue.main.async {
                    self.consoleBuffer += text
                }
            }
            self.cpuInstance = cpu
        }
    }
    
    func handleCommand(_ input: String) {
        let cmd = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        
        consoleBuffer += "\(cmd)\n"
        textInput = ""
        
        switch cmd {
        case "help":
            consoleBuffer += "Available commands:\n  help       - Display utilities menu\n  cat [file] - View virtual file (e.g., cat /etc/issue)\n  run-binary - Execute a mock compiled x86 raw payload loop\n\nlocalhost:~# "
            
        case let x where x.hasPrefix("cat "):
            let targetFile = x.replacingOccurrences(of: "cat ", with: "")
            if let content = memoryInstance.virtualFiles[targetFile] {
                consoleBuffer += content + "\nlocalhost:~# "
            } else {
                consoleBuffer += "cat: \(targetFile): No such file or directory\n\nlocalhost:~# "
            }
            
        case "run-binary":
            consoleBuffer += "[System]: Injecting compiled structural bytecode...\n"
            
            // Inject structural string data directly into memory offset 0x500
            let messageBytes = Array("Hello from the emulated x86 sandbox runtime environment!\n".utf8) + [0]
            memoryInstance.loadPayload(bytes: messageBytes, atAddress: 0x500)
            
            // Bytecode Payload Mapping:
            // 1. 0xB8 0x04 0x00 0x00 0x00 -> MOV EAX, 4 (sys_write)
            // 2. 0xBB 0x01 0x00 0x00 0x00 -> MOV EBX, 1 (stdout handle)
            // 3. 0xB9 0x00 0x05 0x00 0x00 -> MOV ECX, 0x500 (Message RAM reference pointer)
            // 4. 0xBA [Length] 0x00 0x00 0x00 -> MOV EDX, total character byte count
            // 5. 0xCD 0x80                 -> INT 0x80 (Trigger software exception drop down to iOS system API)
            // 6. 0xB8 0x01 0x00 0x00 0x00 -> MOV EAX, 1 (sys_exit code sequence)
            // 7. 0xBB 0x00 0x00 0x00 0x00 -> MOV EBX, 0 (Success completion identifier status)
            // 8. 0xCD 0x80                 -> INT 0x80
            let lengthByte = UInt8(messageBytes.count - 1)
            let x86Payload: [UInt8] = [
                0xB8, 0x04, 0x00, 0x00, 0x00,
                0xBB, 0x01, 0x00, 0x00, 0x00,
                0xB9, 0x00, 0x05, 0x00, 0x00,
                0xBA, lengthByte, 0x00, 0x00, 0x00,
                0xCD, 0x80,
                0xB8, 0x01, 0x00, 0x00, 0x00,
                0xBB, 0x00, 0x00, 0x00, 0x00,
                0xCD, 0x80
            ]
            
            memoryInstance.loadPayload(bytes: x86Payload, atAddress: 0x0)
            cpuInstance?.regs.eip = 0 // Position execution pointer back onto execution start block
            cpuInstance?.start()
            
            // Append terminal carriage prompt safely delayed after processing completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.consoleBuffer += "localhost:~# "
            }
            
        default:
            consoleBuffer += "sh: command not found: \(cmd)\n\nlocalhost:~# "
        }
    }
}
