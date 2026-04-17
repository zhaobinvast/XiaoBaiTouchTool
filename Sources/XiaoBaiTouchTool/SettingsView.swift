import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: MappingStore
    @State private var showingAddSheet = false
    @State private var editingMapping: GestureMapping?
    @State private var showSuccessBanner = false
    @State private var bannerText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("XiaoBaiTouchTool")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if store.mappings.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无手势映射")
                        .foregroundColor(.secondary)
                    Text("点击 + 添加一个手势")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(store.mappings) { mapping in
                        MappingRow(mapping: mapping, onDelete: {
                            store.remove(id: mapping.id)
                        })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingMapping = mapping
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 560, height: 440)
        .overlay(alignment: .bottom) {
            if showSuccessBanner {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(bannerText)
                        .font(.callout)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSuccessBanner)
        .sheet(isPresented: $showingAddSheet) {
            MappingWizard(mode: .add, onSave: { mapping in
                store.add(mapping)
                showingAddSheet = false
                showBanner("添加成功")
            }, onCancel: {
                showingAddSheet = false
            })
        }
        .sheet(item: $editingMapping) { mapping in
            MappingWizard(mode: .edit(mapping), onSave: { updated in
                store.update(updated)
                editingMapping = nil
                showBanner("修改成功")
            }, onCancel: {
                editingMapping = nil
            })
        }
    }

    private func showBanner(_ text: String) {
        bannerText = text
        showSuccessBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSuccessBanner = false
        }
    }
}

// MARK: - MappingRow

struct MappingRow: View {
    let mapping: GestureMapping
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if !mapping.isSystemMapping {
                if let icon = NSWorkspace.shared.icon(forFile: mapping.appPath) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app.dashed")
                        .frame(width: 32, height: 32)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mapping.appName)
                        .fontWeight(.medium)
                    Text(mapping.appBundleID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("系统操作")
                        .fontWeight(.medium)
                    Text(mapping.action.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(mapping.gesture.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(4)
                Text(mapping.action.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - MappingWizard

enum WizardMode: Identifiable {
    case add
    case edit(GestureMapping)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let m): return m.id.uuidString
        }
    }
}

struct MappingWizard: View {
    let mode: WizardMode
    let onSave: (GestureMapping) -> Void
    let onCancel: () -> Void

    @State private var step: Int = 1

    // Step 1: Gesture
    @State private var selectedCategory: GestureCategory = .twoFinger
    @State private var selectedGesture: GestureType = .twoFingerTap

    // Step 2: Action type
    enum ActionType: String { case system, app }
    @State private var actionType: ActionType = .system

    // Step 3: Specific action
    @State private var selectedAction: AppAction = .lockScreen
    @State private var appName: String = ""
    @State private var appBundleID: String = ""
    @State private var appPath: String = ""

    // For edit mode
    @State private var editingId: UUID = UUID()

    var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    var title: String {
        isEditMode ? "修改手势映射" : "添加手势映射"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Step indicator
            StepIndicator(current: step)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Divider()

            // Content
            Group {
                switch step {
                case 1: stepOneView
                case 2: stepTwoView
                case 3: stepThreeView
                default: EmptyView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Bottom buttons
            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                if step > 1 {
                    Button("上一步") {
                        step -= 1
                    }
                }

                if step < 3 {
                    Button("下一步") {
                        step += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(isEditMode ? "保存" : "添加") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 420)
        .onAppear { loadFromMode() }
    }

    // MARK: - Step 1: Choose gesture

    private var stepOneView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择手势")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("手指数量", selection: $selectedCategory) {
                ForEach(GestureCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCategory) { newCat in
                let gestures = GestureType.allCases.filter { $0.fingerCount == newCat.fingerCount }
                if !gestures.contains(selectedGesture) {
                    selectedGesture = gestures.first ?? selectedGesture
                }
            }

            let gestures = GestureType.allCases.filter { $0.fingerCount == selectedCategory.fingerCount }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 6) {
                ForEach(gestures) { g in
                    GestureChip(gesture: g, isSelected: selectedGesture == g) {
                        selectedGesture = g
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Step 2: Choose action type

    private var stepTwoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择操作类型")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ActionTypeCard(
                    icon: "gearshape.fill",
                    title: "系统操作",
                    description: "锁屏、截图、音量等",
                    isSelected: actionType == .system
                ) {
                    actionType = .system
                    selectedAction = .lockScreen
                }

                ActionTypeCard(
                    icon: "app.fill",
                    title: "应用操作",
                    description: "打开、隐藏、切换应用",
                    isSelected: actionType == .app
                ) {
                    actionType = .app
                    selectedAction = .openOrActivate
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Step 3: Configure action

    private var stepThreeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if actionType == .system {
                Text("选择系统操作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 6) {
                        ForEach(AppAction.allCases.filter { $0.isSystemAction }) { action in
                            ActionChip(action: action, isSelected: selectedAction == action) {
                                selectedAction = action
                            }
                        }
                    }
                }
            } else {
                Text("选择应用和操作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // App picker
                HStack {
                    if appName.isEmpty {
                        Text("未选择应用").foregroundColor(.secondary)
                    } else {
                        if let icon = NSWorkspace.shared.icon(forFile: appPath) as NSImage? {
                            Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                        }
                        Text(appName)
                    }
                    Spacer()
                    Button("选择...") { pickApp() }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                // App action
                Text("动作")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("动作", selection: $selectedAction) {
                    ForEach(AppAction.allCases.filter { !$0.isSystemAction }) { a in
                        Text(a.displayName).tag(a)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private var canSave: Bool {
        if actionType == .app && appBundleID.isEmpty { return false }
        return true
    }

    private func save() {
        let bid = actionType == .system ? "system" : appBundleID
        let name = actionType == .system ? "系统操作" : appName
        let path = actionType == .system ? "" : appPath
        let mapping = GestureMapping(
            id: editingId,
            gesture: selectedGesture,
            appBundleID: bid,
            appName: name,
            appPath: path,
            action: selectedAction
        )
        onSave(mapping)
    }

    private func loadFromMode() {
        if case .edit(let m) = mode {
            editingId = m.id
            selectedGesture = m.gesture
            selectedCategory = GestureCategory.allCases.first { $0.fingerCount == m.gesture.fingerCount } ?? .twoFinger
            if m.action.isSystemAction {
                actionType = .system
                selectedAction = m.action
            } else {
                actionType = .app
                selectedAction = m.action
                appName = m.appName
                appBundleID = m.appBundleID
                appPath = m.appPath
            }
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            appPath = url.path
            appName = url.deletingPathExtension().lastPathComponent
            if let bundle = Bundle(url: url), let bid = bundle.bundleIdentifier {
                appBundleID = bid
            } else {
                appBundleID = appName
            }
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let current: Int
    private let titles = ["选择手势", "操作类型", "配置操作"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                let stepNum = i + 1
                HStack(spacing: 6) {
                    Circle()
                        .fill(stepNum <= current ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Text("\(stepNum)")
                                .font(.caption2.bold())
                                .foregroundColor(stepNum <= current ? .white : .secondary)
                        )
                    Text(titles[i])
                        .font(.caption)
                        .foregroundColor(stepNum <= current ? .primary : .secondary)
                }

                if i < 2 {
                    Rectangle()
                        .fill(stepNum < current ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

// MARK: - ActionTypeCard

struct ActionTypeCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chips

struct GestureChip: View {
    let gesture: GestureType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(gesture.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? Color.accentColor : .primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ActionChip: View {
    let action: AppAction
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(action.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? Color.accentColor : .primary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch action {
        case .lockScreen:       return "lock.fill"
        case .sleep:             return "moon.fill"
        case .shutdown:          return "power"
        case .restart:           return "arrow.clockwise"
        case .eject:             return "eject.fill"
        case .showDesktop:       return "rectangle.on.rectangle"
        case .showLaunchpad:     return "square.grid.2x2"
        case .missionControl:    return "macwindow"
        case .screenshot:        return "camera.fill"
        case .screenshotArea:    return "camera.viewfinder"
        case .screenshotWindow:  return "camera.badge.ellipsis"
        case .screenBrightnessUp:   return "sun.max.fill"
        case .screenBrightnessDown: return "sun.min.fill"
        case .volumeUp:          return "speaker.wave.3.fill"
        case .volumeDown:        return "speaker.wave.1.fill"
        case .volumeMute:        return "speaker.slash.fill"
        case .mediaPlayPause:    return "playpause.fill"
        case .mediaNext:         return "forward.fill"
        case .mediaPrevious:     return "backward.fill"
        default:                  return "gearshape.fill"
        }
    }
}
