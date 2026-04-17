import Foundation
import AppKit
import CoreGraphics

// MARK: - MultitouchSupport private framework types

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTContact {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var unknown1: Int32
    var unknown2: Int32
    var normalized: MTVector
    var size: Float
    var unknown3: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var unknown4: MTVector
    var unknown5: Int32
    var unknown6: Int32
    var zTotal: Float
}

typealias MTDeviceRef = OpaquePointer
typealias MTContactCallback = @convention(c) (
    OpaquePointer,
    UnsafeRawPointer,
    Int32,
    Double,
    Int32
) -> Int32

// MARK: - MT contact callback

private let mtCallback: MTContactCallback = { _, rawContacts, count, timestamp, _ in
    let contacts = rawContacts.bindMemory(to: MTContact.self, capacity: Int(count))

    var frame: [(id: Int32, state: Int32, x: Float, y: Float, timestamp: Double)] = []
    for i in 0..<Int(count) {
        let c = contacts[i]
        frame.append((id: c.identifier, state: c.state,
                      x: c.normalized.position.x, y: c.normalized.position.y,
                      timestamp: timestamp))
    }

    DispatchQueue.main.async {
        GestureMonitor.shared?.classifier.processFrame(contacts: frame)
    }

    return 0
}

// MARK: - GestureMonitor

class GestureMonitor {
    var onGesture: ((GestureType) -> Void)?
    let classifier = GestureClassifier()

    private var mtDevices: [MTDeviceRef] = []
    private var isRunning = false

    private var _MTDeviceCreateList: (@convention(c) () -> CFArray)?
    private var _MTDeviceStart: (@convention(c) (MTDeviceRef, Int32) -> Void)?
    private var _MTDeviceStop: (@convention(c) (MTDeviceRef) -> Void)?
    private var _MTRegisterContactFrameCallback: (@convention(c) (MTDeviceRef, MTContactCallback) -> Void)?

    static weak var shared: GestureMonitor?

    init() {
        classifier.onGesture = { [weak self] gesture in
            self?.fire(gesture: gesture)
        }
        loadMultitouchFramework()
    }

    deinit { stop() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        GestureMonitor.shared = self
        startMultitouchMonitor()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        classifier.reset()
        if let stopFn = _MTDeviceStop {
            for device in mtDevices { stopFn(device) }
        }
        mtDevices = []
    }

    func fire(gesture: GestureType) {
        onGesture?(gesture)
    }

    // MARK: - MultitouchSupport

    private func loadMultitouchFramework() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            fputs("[GestureMonitor] dlopen failed: \(String(cString: dlerror()))\n", stderr)
            return
        }
        _MTDeviceCreateList = unsafeBitCast(
            dlsym(handle, "MTDeviceCreateList"),
            to: (@convention(c) () -> CFArray)?.self)
        _MTDeviceStart = unsafeBitCast(
            dlsym(handle, "MTDeviceStart"),
            to: (@convention(c) (MTDeviceRef, Int32) -> Void)?.self)
        _MTDeviceStop = unsafeBitCast(
            dlsym(handle, "MTDeviceStop"),
            to: (@convention(c) (MTDeviceRef) -> Void)?.self)
        _MTRegisterContactFrameCallback = unsafeBitCast(
            dlsym(handle, "MTRegisterContactFrameCallback"),
            to: (@convention(c) (MTDeviceRef, MTContactCallback) -> Void)?.self)
    }

    private func startMultitouchMonitor() {
        guard let createList = _MTDeviceCreateList,
              let startFn = _MTDeviceStart,
              let registerFn = _MTRegisterContactFrameCallback else {
            fputs("[GestureMonitor] MultitouchSupport symbols missing\n", stderr)
            return
        }

        let cfDevices = createList()
        let count = CFArrayGetCount(cfDevices)
        guard count > 0 else {
            fputs("[GestureMonitor] No multitouch devices found\n", stderr)
            return
        }

        for i in 0..<count {
            if let raw = CFArrayGetValueAtIndex(cfDevices, i) {
                let device = OpaquePointer(raw)
                registerFn(device, mtCallback)
                startFn(device, 0)
                mtDevices.append(device)
            }
        }

        fputs("[GestureMonitor] MT registered \(mtDevices.count) device(s)\n", stderr)
    }
}
