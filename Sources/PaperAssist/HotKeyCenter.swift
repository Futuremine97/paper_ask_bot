import Carbon
import AppKit

/// 전역 단축키(글로벌 핫키)를 등록/해제합니다.
/// Carbon 의 RegisterEventHotKey 를 사용하므로 접근성 권한이 필요 없습니다.
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private init() {}

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var installed = false
    private let signature: OSType = 0x50415353 // 'PASS'

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        // 비캡처 클로저(전역 싱글톤만 참조)
        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, _) -> OSStatus in
            guard let event = eventRef else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            DispatchQueue.main.async {
                HotKeyCenter.shared.handlers[hkID.id]?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }

    /// 단축키를 등록합니다. keyCode 는 Carbon 가상 키코드, modifiers 는 cmdKey/shiftKey 등의 OR 값입니다.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> UInt32 {
        installIfNeeded()
        let id = nextID
        nextID += 1
        handlers[id] = action

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            refs[id] = ref
        }
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs[id] {
            UnregisterEventHotKey(ref)
        }
        refs[id] = nil
        handlers[id] = nil
    }
}
