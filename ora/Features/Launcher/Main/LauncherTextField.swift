import SwiftUI

struct LauncherTextField: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    let onTab: () -> Void
    let onSubmit: () -> Void
    let onDelete: () -> Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    var cursorColor: Color
    var placeholder: String

    class CustomTextField: NSTextField {
        var cursorColor: NSColor?

        override func becomeFirstResponder() -> Bool {
            let didBecome = super.becomeFirstResponder()
            if didBecome, let textView = currentEditor() as? NSTextView, let color = cursorColor {
                textView.insertionPointColor = color
            }
            return didBecome
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CustomTextField {
        let textField = CustomTextField()
        textField.delegate = context.coordinator
        textField.font = font
        textField.bezelStyle = .roundedBezel
        textField.isBordered = false
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.placeholderString = placeholder
        return textField
    }

    func updateNSView(_ nsView: CustomTextField, context: Context) {
        nsView.stringValue = text
        nsView.cursorColor = NSColor(cursorColor)
        nsView.placeholderString = placeholder
        if let textView = nsView.currentEditor() as? NSTextView {
            textView.insertionPointColor = nsView.cursorColor
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LauncherTextField

        init(_ parent: LauncherTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            } else if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            } else if selector == #selector(NSResponder.deleteBackward(_:)) {
                return parent.onDelete()
            } else if selector == #selector(NSResponder.moveUp(_:)) || selector ==
                #selector(NSResponder.moveToBeginningOfParagraph(_:))
            {
                parent.onMoveUp()
                return true
            } else if selector == #selector(NSResponder.moveDown(_:)) || selector ==
                #selector(NSResponder.moveToEndOfParagraph(_:))
            {
                parent.onMoveDown()
                return true
            }

            return false
        }
    }
}
