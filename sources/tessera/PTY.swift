import Foundation
import Darwin

class PTY {
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    var slavePath: String?

    func setWindowSize(rows: Int, cols: Int) {
        guard slaveFD >= 0 else { return }

        var size = winsize()
        size.ws_row = UInt16(rows)
        size.ws_col = UInt16(cols)

        _ = ioctl(slaveFD, TIOCSWINSZ, &size)
    }

    func open() throws {
        // Open master PTY
        masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFD >= 0 else {
            throw NSError(domain: "PTY", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to open PTY master"])
        }

        // Grant access to slave
        guard grantpt(masterFD) == 0 else {
            Darwin.close(masterFD)
            throw NSError(domain: "PTY", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to grant PTY"])
        }

        // Unlock slave
        guard unlockpt(masterFD) == 0 else {
            Darwin.close(masterFD)
            throw NSError(domain: "PTY", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to unlock PTY"])
        }

        // Get slave path
        if let path = ptsname(masterFD) {
            slavePath = String(cString: path)
        }

        print("PTY: opened master=\(masterFD), slave=\(slavePath ?? "unknown")")
    }

    func getMasterFileHandle() -> FileHandle? {
        guard masterFD >= 0 else { return nil }
        return FileHandle(fileDescriptor: masterFD, closeOnDealloc: false)
    }

    func getSlaveFileHandle() throws -> FileHandle {
        guard let path = slavePath else {
            throw NSError(domain: "PTY", code: -1, userInfo: [NSLocalizedDescriptionKey: "No slave path"])
        }

        slaveFD = Darwin.open(path, O_RDWR)
        guard slaveFD >= 0 else {
            throw NSError(domain: "PTY", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to open PTY slave"])
        }

        return FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
    }

    func closeFDs() {
        if masterFD >= 0 {
            Darwin.close(masterFD)
            masterFD = -1
        }
        if slaveFD >= 0 {
            Darwin.close(slaveFD)
            slaveFD = -1
        }
    }

    deinit {
        closeFDs()
    }
}
