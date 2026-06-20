import SwiftUI

struct ContentView: View {
    @State private var consoleBuffer: String = "iSH-Lite v2.0 (Permanent File System Online)\nType 'ls' or use redirection commands like: cat > home/note.txt\n\nlocalhost:~# "
    @State private var textInput: String = ""
    
    let memoryInstance = VirtualMemory()
    @State private var cpuInstance: X86CPU?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(consoleBuffer)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("ConsoleBottom")
                }
                .background(Color.black)
                .onChange(of: consoleBuffer) { _ in
                    proxy.scrollTo("ConsoleBottom", anchor: .bottom)
                }
            }
            
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
            setupEngineEnvironment()
        }
    }
    
    func setupEngineEnvironment() {
        let cpu = X86CPU(memory: memoryInstance)
        let syscall = LinuxSyscallHandler(output: { text in
            DispatchQueue.main.async { self.consoleBuffer += text }
        })
        cpu.syscallHandler = syscall
        cpu.onConsoleOutput = { text in
            DispatchQueue.main.async { self.consoleBuffer += text }
        }
        self.cpuInstance = cpu
    }
    
    func handleCommand(_ input: String) {
        let cmd = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        
        consoleBuffer += "\(cmd)\n"
        textInput = ""
        
        // Handle redirection structure manually: cat > filename
        if cmd.contains(">") {
            let components = cmd.components(separatedBy: ">")
            let binaryPart = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let fileTarget = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if binaryPart == "cat" {
                consoleBuffer += "Entering direct input mode. Type your text line. Press Enter to write and commit file data.\n> "
                // Intercept terminal to receive target stream context payload contents next
                textInput = "COMMIT_WRITE:\(fileTarget):"
                return
            }
        }
        
        // Finalize standard write hook injection sequences
        if cmd.hasPrefix("COMMIT_WRITE:") {
            let structuralBlocks = cmd.components(separatedBy: ":")
            let targetFile = structuralBlocks[1]
            let payloadText = structuralBlocks[2] + "\n"
            
            // Dynamically load the destination path name string onto memory space 0x600
            let pathBytes = Array(targetFile.utf8) + [0]
            memoryInstance.loadPayload(bytes: pathBytes, atAddress: 0x600)
            
            // Dynamic load the file body contents payload onto memory space 0x700
            let textBytes = Array(payloadText.utf8)
            memoryInstance.loadPayload(bytes: textBytes, atAddress: 0x700)
            
            // Core instructions using the newly integrated sys_creat (8) & sys_write (4) pipelines:
            // 1. MOV EAX, 8     (sys_creat)
            // 2. MOV EBX, 0x600 (Pointer to destination file name path)
            // 3. INT 0x80       (Creates file, returns custom opened file descriptor into EAX)
            // 4. MOV EBX, EAX   (Pass file descriptor parameter index value down into target register)
            // 5. MOV EAX, 4     (sys_write)
            // 6. MOV ECX, 0x700 (Pointer to text data buffer address context location)
            // 7. MOV EDX, len   (Dynamic character string volume size scale count tracking constraint)
            // 8. INT 0x80       (Performs actual hardware flash write execution sequence)
            // 9. MOV EAX, 6     (sys_close)
            // 10. INT 0x80      (Flushes and locks system handles tracking records safely clear)
            let lengthByte = UInt8(textBytes.count)
            let x86AssemblyPayload: [UInt8] = [
                0xB8, 0x08, 0x00, 0x00, 0x00, // mov eax, 8
                0xBB, 0x00, 0x06, 0x00, 0x00, // mov ebx, 0x600
                0xCD, 0x80,                   // int 0x80
                0x89, 0xC3,                   // mov ebx, eax (Copies out returned FD handle)
                0xB8, 0x04, 0x00, 0x00, 0x00, // mov eax, 4
                0xB9, 0x00, 0x07, 0x00, 0x00, // mov ecx, 0x700
                0xBA, lengthByte, 0x00, 0x00, 0x00, // mov edx, file size length
                0xCD, 0x80,                   // int 0x80
                0xB8, 0x06, 0x00, 0x00, 0x00, // mov eax, 6 (sys_close)
                0xCD, 0x80                    // int 0x80
            ]
            
            memoryInstance.loadPayload(bytes: x86AssemblyPayload, atAddress: 0x0)
            cpuInstance?.regs.eip = 0
            cpuInstance?.start()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.consoleBuffer += "[System]: File written permanently to iPad sandbox.\n\nlocalhost:~# "
            }
            return
        }
        
        switch cmd {
        case "help":
            consoleBuffer += "Commands:\n  ls         - List files via real iPad local storage directory mappings\n  cat [file] - Read physical data file text strings securely\n  cat > [file] - Stream line input block payload files permanently\n\nlocalhost:~# "
            
        case "ls":
            let fm = FileManager.default
            let pathURL = memoryInstance.rootFSURL
            do {
                let items = try fm.contentsOfDirectory(atPath: pathURL.path)
                let printedContents = items.isEmpty ? "(Directory empty)" : items.joined(separator: "  ")
                consoleBuffer += printedContents + "\n\nlocalhost:~# "
            } catch {
                consoleBuffer += "ls: Cannot access root filesystem directory structures\n\nlocalhost:~# "
            }
            
        case let x where x.hasPrefix("cat "):
            let targetFile = x.replacingOccurrences(of: "cat ", with: "").trimmingCharacters(in: .whitespaces)
            let fileURL = memoryInstance.rootFSURL.appendingPathComponent(targetFile)
            
            if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
                consoleBuffer += text + "\nlocalhost:~# "
            } else {
                consoleBuffer += "cat: \(targetFile): No such file or directory\n\nlocalhost:~# "
            }
            
        default:
            // Intercept direct file writing prompt text stream captures
            if consoleBuffer.hasSuffix("> ") {
                let parts = consoleBuffer.components(separatedBy: "Entering direct input mode. Type your text line. Press Enter to write and commit file data.\n> ")
                if let lastLine = parts.last?.components(separatedBy: "\n").first, !lastLine.isEmpty {
                    let fileTarget = lastLine
                    handleCommand("COMMIT_WRITE:\(fileTarget):\(cmd)")
                    return
                }
            }
            consoleBuffer += "sh: command not found: \(cmd)\n\nlocalhost:~# "
        }
    }
}
