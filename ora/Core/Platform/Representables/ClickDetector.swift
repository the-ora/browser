//
//  ClickDetector.swift
//  ora
//
//  Created by Aryan Rogye on 3/8/26.
//

import AppKit
import SwiftUI

enum ClickConfig: String, CaseIterable {
    case none        = "None"
    case middleMouse = "Middle Mouse"
    case optionClick = "Option Click"
}

struct ClickDetector: NSViewRepresentable {
    var config: ClickConfig
    var onClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        /// uncomment to see border around the click area
//        view.wantsLayer = true
//        view.layer?.borderColor = NSColor.red.cgColor
//        view.layer?.borderWidth = 2
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        guard context.coordinator.currentConfig != config else { return }
        context.coordinator.update(config: config, onClick: onClick, view: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(config: config, onClick: onClick)
    }

    class Coordinator: NSObject {
        var monitor: Any?
        var lastFired: Date = .distantPast
        let throttleInterval: TimeInterval = 0.5
        var currentConfig: ClickConfig = .none
        weak var view: NSView?

        init(config: ClickConfig, onClick: @escaping () -> Void) {
            super.init()
            update(config: config, onClick: onClick, view: nil)
        }

        func update(config: ClickConfig, onClick: @escaping () -> Void, view: NSView?) {
            self.view = view
            currentConfig = config
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil

            switch config {
            case .none:
                break
            case .middleMouse:
                monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
                    guard event.buttonNumber == 2 else { return event }
                    guard self?.isOverView(event) == true else { return event }
                    self?.fire(onClick)
                    return nil
                }
            case .optionClick:
                monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                    guard event.modifierFlags.contains(.option) else { return event }
                    guard self?.isOverView(event) == true else { return event }
                    self?.fire(onClick)
                    return nil
                }
            }
        }

        private func isOverView(_ event: NSEvent) -> Bool {
            guard let view, let window = view.window else { return false }
            let locationInWindow = event.locationInWindow
            let locationInView = view.convert(locationInWindow, from: nil)
            return view.bounds.contains(locationInView)
        }

        private func fire(_ onClick: @escaping () -> Void) {
            let now = Date()
            guard now.timeIntervalSince(lastFired) >= throttleInterval else { return }
            lastFired = now
            onClick()
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
