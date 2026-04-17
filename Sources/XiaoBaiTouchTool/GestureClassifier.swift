import Foundation

class GestureClassifier {
    var onGesture: ((GestureType) -> Void)?

    // MARK: - Finger tracking

    private struct Finger {
        let id: Int32
        var x: Float
        var y: Float
        let startX: Float
        let startY: Float
        let downTime: Double
    }

    private var fingers: [Int32: Finger] = [:]
    private var peakFingers: Int = 0
    private var peakSnapshot: [Int32: Finger] = [:]
    private var gestureStartTime: Double = 0
    private var prevActiveCount: Int = 0

    // Chord state
    private var baseIds: Set<Int32> = []
    private var chordId: Int32?
    private var chordDownTime: Double = 0
    private var chordX: Float = 0
    private var chordEmitted: Bool = false

    // Double-tap buffer
    private struct PendingTap {
        let gesture: GestureType
        let time: Date
    }
    private var pendingTap: PendingTap?
    private var doubleTapTimer: Timer?

    // MARK: - Tunables

    private let tapMaxDuration: Double = 0.18
    private let pressMinDuration: Double = 0.18
    private let pressMaxDuration: Double = 0.6
    private let doubleTapWindow: TimeInterval = 0.30
    private let maxTapDisplacement: Float = 0.04
    private let chordLateThreshold: Double = 0.06
    private let leftBoundary: Float = 0.38
    private let rightBoundary: Float = 0.62

    // MARK: - Process frame

    func processFrame(contacts: [(id: Int32, state: Int32, x: Float, y: Float, timestamp: Double)]) {
        var gestureToEmit: GestureType?

        for c in contacts {
            switch c.state {
            case 1, 2, 3:
                // Finger down / touching
                if fingers[c.id] == nil {
                    fingers[c.id] = Finger(id: c.id, x: c.x, y: c.y,
                                           startX: c.x, startY: c.y,
                                           downTime: c.timestamp)
                    let activeCount = activeFingerCount()
                    if activeCount > peakFingers {
                        peakFingers = activeCount
                        peakSnapshot = fingers.filter { isFingerActive($0.value, in: contacts) }
                    }
                } else {
                    fingers[c.id]!.x = c.x
                    fingers[c.id]!.y = c.y
                }
            case 5, 6, 7:
                // Finger lifting
                fingers[c.id]?.x = c.x
                fingers[c.id]?.y = c.y
            case 0:
                // Fully gone — don't remove yet, handle below
                break
            default:
                // State 4 = hovering
                if fingers[c.id] != nil {
                    fingers[c.id]!.x = c.x
                    fingers[c.id]!.y = c.y
                }
            }
        }

        let activeCount = countActive(in: contacts)

        // Track gesture start and peak
        if prevActiveCount == 0 && activeCount > 0 {
            fingers = fingers.filter { isFingerActive($0.value, in: contacts) }
            gestureStartTime = contacts.first?.timestamp ?? 0
            peakFingers = activeCount
            peakSnapshot = fingers
            baseIds = []
            chordId = nil
            chordDownTime = 0
            chordX = 0
            chordEmitted = false
        } else if activeCount > peakFingers {
            peakFingers = activeCount
            peakSnapshot = fingers.filter { isFingerActive($0.value, in: contacts) }
        }

        // Capture base IDs when first reaching 2+ fingers
        if prevActiveCount < 2 && activeCount >= 2 && chordId == nil {
            baseIds = Set(fingers.filter { isFingerActive($0.value, in: contacts) }.keys)
        }

        // Detect chord: new finger arrives while 2+ base fingers held
        if activeCount > prevActiveCount && prevActiveCount >= 2 && chordId == nil {
            let newFingers = fingers.filter { isFingerActive($0.value, in: contacts) && !baseIds.contains($0.key) }
            if newFingers.count == 1, let chord = newFingers.first {
                let msSinceStart = chord.value.downTime - gestureStartTime
                if msSinceStart > chordLateThreshold {
                    chordId = chord.key
                    chordDownTime = chord.value.downTime
                    chordX = chord.value.x
                    chordEmitted = false
                }
            }
        }

        // Chord finger lifted while base fingers still held
        if let cid = chordId, !chordEmitted {
            let chordStillDown = contacts.contains { $0.id == cid && ($0.state == 1 || $0.state == 2 || $0.state == 3 || $0.state == 4) }
            if !chordStillDown, fingers[cid] != nil {
                let timestamp = contacts.first?.timestamp ?? 0
                let duration = timestamp - chordDownTime
                let isTap = duration < tapMaxDuration
                let role = fingerRole(x: chordX)
                chordEmitted = true
                chordId = nil

                if isTap {
                    let gesture = chordTapGesture(role: role, peak: peakFingers)
                    if let g = gesture { gestureToEmit = g }
                } else if duration < pressMaxDuration {
                    let gesture = chordPressGesture(role: role, peak: peakFingers)
                    if let g = gesture { emit(g) }
                }
            }
        }

        // All fingers lifted — emit simple gesture
        if activeCount == 0 && prevActiveCount > 0 {
            if !chordEmitted {
                let timestamp = contacts.first?.timestamp ?? 0
                let duration = timestamp - gestureStartTime
                let peak = peakFingers

                // Check displacement of all peak fingers
                let maxDisplacement = peakSnapshot.values.map { f -> Float in
                    let dx = f.x - f.startX
                    let dy = f.y - f.startY
                    return sqrtf(dx * dx + dy * dy)
                }.max() ?? 0

                if maxDisplacement < maxTapDisplacement {
                    let isTap = duration < tapMaxDuration
                    let isPress = duration >= pressMinDuration && duration < pressMaxDuration

                    if isTap, let g = simpleTapGesture(count: peak) {
                        gestureToEmit = g
                    } else if isPress, let g = simplePressGesture(count: peak) {
                        emit(g)
                    }
                }
            }

            // Reset state
            fingers.removeAll()
            peakFingers = 0
            peakSnapshot = [:]
            gestureStartTime = 0
            baseIds = []
            chordId = nil
            chordDownTime = 0
            chordX = 0
            chordEmitted = false
        }

        // Remove fully-gone fingers
        for c in contacts where c.state == 0 {
            fingers.removeValue(forKey: c.id)
        }

        prevActiveCount = activeCount

        // Emit or buffer for double-tap
        if let g = gestureToEmit {
            emitOrBuffer(g)
        }
    }

    // MARK: - Double-tap buffering

    private func emitOrBuffer(_ gesture: GestureType) {
        if let pending = pendingTap {
            let elapsed = Date().timeIntervalSince(pending.time)
            if elapsed < doubleTapWindow && pending.gesture == gesture {
                // Double-tap confirmed
                doubleTapTimer?.invalidate()
                doubleTapTimer = nil
                pendingTap = nil
                if let dt = doubleTapVariant(of: gesture) {
                    emit(dt)
                } else {
                    emit(gesture)
                }
                return
            } else {
                // Different gesture or too slow — flush pending
                doubleTapTimer?.invalidate()
                doubleTapTimer = nil
                let flushed = pending.gesture
                pendingTap = nil
                emit(flushed)
            }
        }

        // Buffer this tap
        pendingTap = PendingTap(gesture: gesture, time: Date())
        doubleTapTimer = Timer.scheduledTimer(withTimeInterval: doubleTapWindow, repeats: false) { [weak self] _ in
            guard let self = self, let pending = self.pendingTap else { return }
            self.pendingTap = nil
            self.doubleTapTimer = nil
            self.emit(pending.gesture)
        }
    }

    private func emit(_ gesture: GestureType) {
        onGesture?(gesture)
    }

    // MARK: - Gesture mapping helpers

    private func simpleTapGesture(count: Int) -> GestureType? {
        switch count {
        case 2: return .twoFingerTap
        case 3: return .threeFingerTap
        case 4: return .fourFingerTap
        default: return nil
        }
    }

    private func simplePressGesture(count: Int) -> GestureType? {
        switch count {
        case 2: return .twoFingerClick
        case 3: return .threeFingerClick
        case 4: return .fourFingerClick
        default: return nil
        }
    }

    private enum FingerRole { case left, middle, right }

    private func chordTapGesture(role: FingerRole, peak: Int) -> GestureType? {
        switch (peak, role) {
        case (3, .left):   return .threeFingerLeftTap
        case (3, .middle): return .threeFingerMiddleTap
        case (3, .right):  return .threeFingerRightTap
        case (4, .left):   return .fourFingerLeftTap
        case (4, .middle): return .fourFingerMiddleTap
        case (4, .right):  return .fourFingerRightTap
        default: return nil
        }
    }

    private func chordPressGesture(role: FingerRole, peak: Int) -> GestureType? {
        // No press variants for chord gestures in current GestureType enum
        // Fall back to simple press
        return simplePressGesture(count: peak)
    }

    private func doubleTapVariant(of gesture: GestureType) -> GestureType? {
        switch gesture {
        case .twoFingerTap:   return .twoFingerDoubleTap
        case .threeFingerTap: return .threeFingerDoubleTap
        case .fourFingerTap:  return .fourFingerDoubleTap
        default: return nil
        }
    }

    private func fingerRole(x: Float) -> FingerRole {
        if x < leftBoundary  { return .left }
        if x > rightBoundary { return .right }
        return .middle
    }

    // MARK: - Helpers

    private func activeFingerCount() -> Int {
        // Count fingers that haven't been marked as gone
        return fingers.count
    }

    private func countActive(in contacts: [(id: Int32, state: Int32, x: Float, y: Float, timestamp: Double)]) -> Int {
        return contacts.filter { $0.state == 1 || $0.state == 2 || $0.state == 3 || $0.state == 4 }.count
    }

    private func isFingerActive(_ finger: Finger, in contacts: [(id: Int32, state: Int32, x: Float, y: Float, timestamp: Double)]) -> Bool {
        guard let c = contacts.first(where: { $0.id == finger.id }) else { return false }
        return c.state == 1 || c.state == 2 || c.state == 3 || c.state == 4
    }

    func reset() {
        fingers.removeAll()
        peakFingers = 0
        peakSnapshot = [:]
        gestureStartTime = 0
        prevActiveCount = 0
        baseIds = []
        chordId = nil
        chordDownTime = 0
        chordX = 0
        chordEmitted = false
        doubleTapTimer?.invalidate()
        doubleTapTimer = nil
        pendingTap = nil
    }
}
