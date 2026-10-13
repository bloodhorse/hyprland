import CoreGraphics
import Foundation
import IOKit.hid

let mini = "100.69.218.90"
let port: UInt16 = 4677
let profile = "hop"
let chord: Set<Int> = [0xE1, 0xE5, 0x29]
let dir = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Caches/hop"
let pidFile = dir + "/pid"
let profileFile = dir + "/profile"
let logFile = dir + "/log"
let cli = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"

let KBD: UInt8 = 0, MOUSE: UInt8 = 1, PING: UInt8 = 2, DROP: UInt8 = 3
let EV_SYN: UInt8 = 0, EV_KEY: UInt8 = 1, EV_REL: UInt8 = 2
let REL_X = 0, REL_Y = 1, REL_HWHEEL = 6, REL_WHEEL = 8
let BTN: [Int: Int] = [1: 0x110, 2: 0x111, 3: 0x112, 4: 0x113, 5: 0x114]

let keys: [Int] = [
      0,  0,  0,  0, 30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38,
     50, 49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44,  2,  3,
      4,  5,  6,  7,  8,  9, 10, 11, 28,  1, 14, 15, 57, 12, 13, 26,
     27, 43, 43, 39, 40, 41, 51, 52, 53, 58, 59, 60, 61, 62, 63, 64,
     65, 66, 67, 68, 87, 88, 99, 70,119,110,102,104,111,107,109,106,
    105,108,103, 69, 98, 55, 74, 78, 96, 79, 80, 81, 75, 76, 77, 71,
     72, 73, 82, 83, 86,127,116,117,183,184,185,186,187,188,189,190,
    191,192,193,194,134,138,130,132,128,129,131,137,133,135,136,113,
    115,114,  0,  0,  0,121,  0, 89, 93,124, 92, 94, 95,  0,  0,  0,
    122,123, 90, 91, 85,  0,  0,  0,  0,  0,  0,  0,111,  0,  0,  0,
      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
      0,  0,  0,  0,  0,  0,179,180,  0,  0,  0,  0,  0,  0,  0,  0,
      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
      0,  0,  0,  0,  0,  0,  0,  0,111,  0,  0,  0,  0,  0,  0,  0,
     29, 42, 56,125, 97, 54,100,126,164,166,165,163,161,115,114,113,
    150,158,159,128,136,177,178,176,142,152,173,140,  0,  0,  0,  0,
]

let consumer: [Int: Int] = [0xE9: 115, 0xEA: 114, 0xE2: 113, 0xCD: 164, 0xB5: 163, 0xB6: 165, 0x6F: 225, 0x70: 224]

let names: [String: Int] = {
    var n: [String: Int] = ["enter": 0x28, "esc": 0x29, "backspace": 0x2A, "tab": 0x2B, "space": 0x2C, "0": 0x27,
                            "ctrl": 0xE0, "lshift": 0xE1, "alt": 0xE2, "cmd": 0xE3, "rshift": 0xE5, "ralt": 0xE6, "rcmd": 0xE7]
    for (i, c) in "abcdefghijklmnopqrstuvwxyz".enumerated() { n[String(c)] = 0x04 + i }
    for (i, c) in "123456789".enumerated() { n[String(c)] = 0x1E + i }
    return n
}()

var sock: Int32 = -1
var held = Set<Int>()
var leaving = false
var dry = false
var counted = 0
var keyCount = 0
var mouseCount = 0
var flushing = false
var tapPort: CFMachPort?
var lastPong = Date()
let pongLock = NSLock()
var child: pid_t = 0

func now() -> Int32 { Int32(truncatingIfNeeded: Int(Date().timeIntervalSince1970 * 1_000_000) & 0x7FFF_FFFF) }

func log(_ s: String) {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
}

func dial() -> Int32 {
    let s = socket(AF_INET, SOCK_STREAM, 0)
    var a = sockaddr_in()
    a.sin_family = sa_family_t(AF_INET)
    a.sin_port = port.bigEndian
    inet_pton(AF_INET, mini, &a.sin_addr)
    var one: Int32 = 1
    setsockopt(s, IPPROTO_TCP, TCP_NODELAY, &one, 4)
    setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, &one, 4)
    var tv = timeval(tv_sec: 1, tv_usec: 0)
    setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    let flags = fcntl(s, F_GETFL)
    _ = fcntl(s, F_SETFL, flags | O_NONBLOCK)
    _ = withUnsafePointer(to: &a) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    var p = pollfd(fd: s, events: Int16(POLLOUT), revents: 0)
    var err: Int32 = 0
    var len = socklen_t(4)
    if poll(&p, 1, 1500) <= 0 || getsockopt(s, SOL_SOCKET, SO_ERROR, &err, &len) != 0 || err != 0 {
        close(s)
        return -1
    }
    _ = fcntl(s, F_SETFL, flags)
    return s
}

func put(_ dev: UInt8, _ type: UInt8, _ code: Int, _ value: Int32) {
    if dev == KBD { keyCount += 1 } else if dev == MOUSE { mouseCount += 1 }
    if dry { counted += 1; return }
    var b = [UInt8](repeating: 0, count: 8)
    b[0] = dev
    b[1] = type
    b[2] = UInt8(code & 0xFF)
    b[3] = UInt8((code >> 8) & 0xFF)
    let v = UInt32(bitPattern: value)
    b[4] = UInt8(v & 0xFF)
    b[5] = UInt8((v >> 8) & 0xFF)
    b[6] = UInt8((v >> 16) & 0xFF)
    b[7] = UInt8((v >> 24) & 0xFF)
    if write(sock, b, 8) != 8 { lost("the mini stopped taking keys") }
}

func pong(_ s: Int32) -> Int32? {
    while true {
        guard let b = record(s) else { return nil }
        if b[0] == DROP { kill(getpid(), SIGTERM); continue }
        return Int32(bitPattern: UInt32(b[4]) | UInt32(b[5]) << 8 | UInt32(b[6]) << 16 | UInt32(b[7]) << 24)
    }
}

func record(_ s: Int32) -> [UInt8]? {
    var b = [UInt8](repeating: 0, count: 8)
    var have = 0
    while have < 8 {
        let n = b.withUnsafeMutableBytes { read(s, $0.baseAddress! + have, 8 - have) }
        if n <= 0 { return nil }
        have += n
    }
    return b
}

func lost(_ why: String) -> Never {
    log(why)
    _exit(1)
}

func leave() -> Never {
    log("\(keyCount) key events, \(mouseCount) mouse events")
    if !dry {
        put(DROP, 0, 0, 0)
        close(sock)
    } else {
        log("dry: \(counted) events")
    }
    exit(0)
}

func karabiner(_ args: [String]) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: cli)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return (-1, "") }
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    p.waitUntilExit()
    return (p.terminationStatus, out.trimmingCharacters(in: .whitespacesAndNewlines))
}

func runner() -> pid_t? {
    guard let s = try? String(contentsOfFile: pidFile, encoding: .utf8), let pid = pid_t(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
    return kill(pid, 0) == 0 ? pid : nil
}

func home() {
    let (_, cur) = karabiner(["--show-current-profile-name"])
    if cur != profile { return }
    let saved = (try? String(contentsOfFile: profileFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let (_, all) = karabiner(["--list-profile-names"])
    let back = saved.isEmpty ? (all.split(separator: "\n").map(String.init).first { $0 != profile } ?? "") : saved
    if !back.isEmpty { _ = karabiner(["--select-profile", back]) }
}

func spawn(_ args: [String], detached: Bool) -> pid_t {
    var fa: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fa)
    posix_spawn_file_actions_addopen(&fa, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_addopen(&fa, 1, logFile, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    posix_spawn_file_actions_addopen(&fa, 2, logFile, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    var attr: posix_spawnattr_t?
    posix_spawnattr_init(&attr)
    if detached { posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID)) }
    let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
    var argv: [UnsafeMutablePointer<CChar>?] = ([exe] + args).map { strdup($0) } + [nil]
    var pid: pid_t = 0
    let r = posix_spawn(&pid, exe, &fa, &attr, &argv, environ)
    return r == 0 ? pid : -1
}

func guardian() -> Never {
    signal(SIGHUP, SIG_IGN)
    let (_, cur) = karabiner(["--show-current-profile-name"])
    if cur != profile { try? cur.write(toFile: profileFile, atomically: true, encoding: .utf8) }
    let probe = dial()
    if probe < 0 { log("the mini does not answer on \(mini):\(port)"); exit(1) }
    close(probe)
    let (rc, out) = karabiner(["--select-profile", profile])
    let (_, after) = karabiner(["--show-current-profile-name"])
    if rc != 0 || after != profile { log("karabiner has no profile named \(profile) \(out)"); exit(1) }
    usleep(400_000)
    child = spawn(["run"], detached: false)
    if child > 0 {
        try? String(child).write(toFile: pidFile, atomically: true, encoding: .utf8)
        signal(SIGTERM) { _ in kill(child, SIGTERM) }
        signal(SIGINT) { _ in kill(child, SIGTERM) }
        var status: Int32 = 0
        while waitpid(child, &status, 0) < 0 && errno == EINTR {}
    }
    try? FileManager.default.removeItem(atPath: pidFile)
    home()
    log("home")
    exit(0)
}

func key(_ usage: Int, _ down: Bool) {
    if down { held.insert(usage) } else { held.remove(usage) }
    if leaving {
        if held.isEmpty { leave() }
        return
    }
    if down && held == chord {
        leaving = true
        if !dry { put(DROP, 0, 0, 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { leave() }
        return
    }
    let code = keys[usage]
    if code != 0 { put(KBD, EV_KEY, code, down ? 1 : 0) }
}

func rel(_ code: Int, _ value: Int) {
    if value == 0 || leaving { return }
    put(MOUSE, EV_REL, code, Int32(value))
    if flushing { return }
    flushing = true
    DispatchQueue.main.async {
        flushing = false
        put(MOUSE, EV_SYN, 0, 0)
    }
}

func listen(vendor: Int, product: Int, seize: Bool, _ cb: @escaping IOHIDValueCallback) -> IOHIDManager {
    let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: vendor, kIOHIDProductIDKey: product] as CFDictionary)
    IOHIDManagerRegisterInputValueCallback(m, cb, nil)
    IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    let r = IOHIDManagerOpen(m, IOOptionBits(seize ? kIOHIDOptionsTypeSeizeDevice : kIOHIDOptionsTypeNone))
    if r != kIOReturnSuccess { log("hid open \(String(UInt32(bitPattern: r), radix: 16)) for \(String(vendor, radix: 16)):\(String(product, radix: 16))") }
    return m
}

func run(_ args: [String]) -> Never {
    if args.first == "dry" {
        dry = true
        let secs = Double(args.count > 1 ? args[1] : "4") ?? 4
        DispatchQueue.main.asyncAfter(deadline: .now() + secs) { leave() }
    } else {
        sock = dial()
        if sock < 0 { lost("the mini does not answer on \(mini):\(port)") }
    }
    for sig in [SIGTERM, SIGINT, SIGHUP] { signal(sig, SIG_IGN) }
    let sources = [SIGTERM, SIGINT, SIGHUP].map { sig -> DispatchSourceSignal in
        let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        s.setEventHandler { leave() }
        s.resume()
        return s
    }
    let kbd = listen(vendor: 0x5ac, product: 0x24f, seize: false) { _, _, _, value in
        let el = IOHIDValueGetElement(value)
        let page = Int(IOHIDElementGetUsagePage(el))
        let usage = Int(IOHIDElementGetUsage(el))
        let down = IOHIDValueGetIntegerValue(value) != 0
        if page == 7 && usage >= 4 && usage <= 0xE7 {
            key(usage, down)
        } else if page == 12, let code = consumer[usage], !leaving {
            put(KBD, EV_KEY, code, down ? 1 : 0)
        }
    }
    let mouse = listen(vendor: 0x16c0, product: 0x27da, seize: true) { _, _, _, value in
        let el = IOHIDValueGetElement(value)
        let page = Int(IOHIDElementGetUsagePage(el))
        let usage = Int(IOHIDElementGetUsage(el))
        let v = IOHIDValueGetIntegerValue(value)
        if page == 1 && usage == 0x30 { rel(REL_X, v) }
        else if page == 1 && usage == 0x31 { rel(REL_Y, v) }
        else if page == 1 && usage == 0x38 { rel(REL_WHEEL, v) }
        else if page == 12 && usage == 0x238 { rel(REL_HWHEEL, v) }
        else if page == 9, let code = BTN[usage], !leaving {
            put(MOUSE, EV_KEY, code, v != 0 ? 1 : 0)
            put(MOUSE, EV_SYN, 0, 0)
        }
    }
    let mask: CGEventMask = (1 << 10) | (1 << 11) | (1 << 12) | (1 << 14)
    tapPort = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tapPort { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        return nil
    }, userInfo: nil)
    guard let tap = tapPort else { lost("no event tap: the terminal needs Accessibility") }
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    if !dry {
        let s = sock
        Thread.detachNewThread {
            while pong(s) != nil {
                pongLock.lock()
                lastPong = Date()
                pongLock.unlock()
            }
            lost("the mini closed the line")
        }
        Thread.detachNewThread {
            while true {
                usleep(250_000)
                pongLock.lock()
                let age = Date().timeIntervalSince(lastPong)
                pongLock.unlock()
                if age > 2 { lost("the mini went quiet") }
            }
        }
        let beat = DispatchSource.makeTimerSource(queue: .main)
        beat.schedule(deadline: .now(), repeating: .milliseconds(500))
        beat.setEventHandler { put(PING, 0, 0, now()) }
        beat.resume()
        withExtendedLifetime(beat) { CFRunLoopRun() }
    }
    withExtendedLifetime((sources, kbd, mouse)) { CFRunLoopRun() }
    exit(0)
}

func ping() -> Never {
    let s = dial()
    if s < 0 { print("the mini does not answer on \(mini):\(port)"); exit(1) }
    sock = s
    var ms: [Double] = []
    for _ in 0..<50 {
        let t = Date()
        put(PING, 0, 0, now())
        if pong(s) == nil { break }
        ms.append(Date().timeIntervalSince(t) * 1000)
        usleep(20_000)
    }
    ms.sort()
    if ms.isEmpty { print("no answer"); exit(1) }
    print(String(format: "%d round trips, ms: min %.1f, median %.1f, worst %.1f", ms.count, ms[0], ms[ms.count / 2], ms[ms.count - 1]))
    exit(0)
}

func press(_ chords: [String]) -> Never {
    sock = dial()
    if sock < 0 { print("the mini does not answer on \(mini):\(port)"); exit(1) }
    for c in chords {
        if c.hasPrefix("wait:") { usleep(UInt32(c.dropFirst(5))! * 1000); continue }
        let us = c.split(separator: "+").map { n -> Int in
            guard let u = names[String(n)] else { print("unknown key \(n)"); exit(2) }
            return u
        }
        for u in us { put(KBD, EV_KEY, keys[u], 1); usleep(40_000) }
        for u in us.reversed() { put(KBD, EV_KEY, keys[u], 0); usleep(40_000) }
        usleep(150_000)
    }
    close(sock)
    exit(0)
}

try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
let args = Array(CommandLine.arguments.dropFirst())
switch args.first ?? "on" {
case "on":
    if runner() != nil { print("already hopped"); exit(0) }
    let (_, all) = karabiner(["--list-profile-names"])
    if !all.split(separator: "\n").map(String.init).contains(profile) { print("karabiner has no profile named \(profile)"); exit(1) }
    try? "".write(toFile: logFile, atomically: true, encoding: .utf8)
    let g = spawn(["guard"], detached: true)
    for _ in 0..<30 {
        usleep(100_000)
        if runner() != nil { print("hopped"); exit(0) }
        if kill(g, 0) != 0 { break }
    }
    print((try? String(contentsOfFile: logFile, encoding: .utf8)) ?? "did not start")
    exit(1)
case "off":
    if let pid = runner() {
        kill(pid, SIGTERM)
        for _ in 0..<30 where runner() != nil { usleep(100_000) }
    }
    usleep(300_000)
    home()
    print("home")
case "state":
    print(runner() != nil ? "hopped" : "home")
case "guard": guardian()
case "run": run(Array(args.dropFirst()))
case "ping": ping()
case "press": press(Array(args.dropFirst()))
default:
    print("hop [on|off|state|ping]")
    exit(2)
}
