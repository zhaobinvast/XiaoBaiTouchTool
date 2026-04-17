import Foundation

// MARK: - GestureType

enum GestureType: String, Codable, CaseIterable, Identifiable {
    // MARK: Two-finger
    case twoFingerTap
    case twoFingerClick
    case twoFingerSwipeUp
    case twoFingerSwipeDown
    case twoFingerSwipeLeft
    case twoFingerSwipeRight
    case twoFingerDoubleTap

    // MARK: Three-finger
    case threeFingerTap
    case threeFingerClick
    case threeFingerDoubleTap
    case threeFingerLeftTap
    case threeFingerMiddleTap
    case threeFingerRightTap

    // MARK: Four-finger
    case fourFingerTap
    case fourFingerClick
    case fourFingerDoubleTap
    case fourFingerLeftTap
    case fourFingerMiddleTap
    case fourFingerRightTap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twoFingerTap:           return "双指轻点"
        case .twoFingerClick:         return "双指点按"
        case .twoFingerSwipeUp:       return "双指上下滑动"
        case .twoFingerSwipeDown:     return "双指左右滑动"
        case .twoFingerSwipeLeft:     return "双指左滑"
        case .twoFingerSwipeRight:    return "双指右滑"
        case .twoFingerDoubleTap:     return "双指轻点两下"
        case .threeFingerTap:        return "三指轻点"
        case .threeFingerClick:      return "三指点按"
        case .threeFingerDoubleTap:   return "三指轻点两下"
        case .threeFingerLeftTap:     return "三指左指轻点"
        case .threeFingerMiddleTap:   return "三指中指轻点"
        case .threeFingerRightTap:    return "三指右指轻点"
        case .fourFingerTap:         return "四指轻点"
        case .fourFingerClick:        return "四指点按"
        case .fourFingerDoubleTap:    return "四指轻点两下"
        case .fourFingerLeftTap:      return "四指左指轻点"
        case .fourFingerMiddleTap:    return "四指中指轻点"
        case .fourFingerRightTap:     return "四指右指轻点"
        }
    }

    var fingerCount: Int {
        switch self {
        case .twoFingerTap, .twoFingerClick, .twoFingerSwipeUp,
             .twoFingerSwipeDown, .twoFingerSwipeLeft, .twoFingerSwipeRight,
             .twoFingerDoubleTap:   return 2
        case .threeFingerTap, .threeFingerClick, .threeFingerDoubleTap,
             .threeFingerLeftTap, .threeFingerMiddleTap, .threeFingerRightTap: return 3
        case .fourFingerTap, .fourFingerClick, .fourFingerDoubleTap,
             .fourFingerLeftTap, .fourFingerMiddleTap, .fourFingerRightTap: return 4
        }
    }
}

// MARK: - GestureCategory

enum GestureCategory: String, CaseIterable {
    case twoFinger = "双指"
    case threeFinger = "三指"
    case fourFinger = "四指"

    var gestures: [GestureType] {
        GestureType.allCases.filter { $0.fingerCount == fingerCount }
    }

    var fingerCount: Int {
        switch self {
        case .twoFinger:   return 2
        case .threeFinger: return 3
        case .fourFinger:  return 4
        }
    }
}

// MARK: - AppAction

enum AppAction: String, Codable, CaseIterable, Identifiable {
    // App actions
    case openOrActivate
    case hide
    case toggle

    // System actions
    case lockScreen
    case sleep
    case shutdown
    case restart
    case eject
    case showDesktop
    case showLaunchpad
    case missionControl
    case screenshot
    case screenshotArea
    case screenshotWindow
    case screenBrightnessUp
    case screenBrightnessDown
    case volumeUp
    case volumeDown
    case volumeMute
    case mediaPlayPause
    case mediaNext
    case mediaPrevious

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openOrActivate:       return "打开 / 激活应用"
        case .hide:                 return "隐藏应用"
        case .toggle:               return "切换显示/隐藏"
        case .lockScreen:           return "锁屏"
        case .sleep:                return "睡眠"
        case .shutdown:             return "关机"
        case .restart:              return "重启"
        case .eject:                return "推出所有磁盘"
        case .showDesktop:          return "显示桌面"
        case .showLaunchpad:        return "启动台"
        case .missionControl:       return "调度中心"
        case .screenshot:           return "截取全屏"
        case .screenshotArea:       return "截取区域"
        case .screenshotWindow:     return "截取窗口"
        case .screenBrightnessUp:   return "增加亮度"
        case .screenBrightnessDown: return "降低亮度"
        case .volumeUp:             return "增加音量"
        case .volumeDown:           return "降低音量"
        case .volumeMute:           return "静音"
        case .mediaPlayPause:       return "播放/暂停"
        case .mediaNext:            return "下一首"
        case .mediaPrevious:        return "上一首"
        }
    }

    var isSystemAction: Bool {
        switch self {
        case .openOrActivate, .hide, .toggle: return false
        default: return true
        }
    }
}

// MARK: - GestureMapping

struct GestureMapping: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var gesture: GestureType
    var appBundleID: String
    var appName: String
    var appPath: String
    var action: AppAction

    var isSystemMapping: Bool { action.isSystemAction }
}
