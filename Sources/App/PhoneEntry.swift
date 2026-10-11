import SwiftUI
import UIKit

/// The phone-number field of the contact form and the keypad (QA ISSUE-002).
///
/// iPadOS 26 presents numeric keyboards as a floating number-pad popover. In Easy Call's
/// contact sheet, digits typed on that popover, and on the full keyboard iPadOS offers after
/// it is dismissed, did not show in the field until it lost focus, so contacts could not be
/// added reliably. The SwiftUI field was also made left-to-right only through the environment,
/// which left a Hebrew keyboard in charge of its alignment while editing.
///
/// This field asks for a docked keyboard instead, keeps the number left-to-right by itself,
/// inserts each character where it is typed and never rewrites what was typed. Digits from
/// other scripts and separators are normalized only when the number is saved or dialed
/// (`PhoneNumber.normalized`).
final class PhoneEntryField: UITextField {
    /// Receives the field's text after every edit, exactly as typed.
    var onTextChange: ((String) -> Void)?

    /// iPad: the current language's keyboard, opened on its digits page and keeping its number
    /// row, instead of the floating number pad. iPhone: the familiar phone keypad.
    static func keyboardType(for idiom: UIUserInterfaceIdiom) -> UIKeyboardType {
        idiom == .pad ? .numbersAndPunctuation : .phonePad
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    // A phone number reads left to right in every language; neither the right-to-left layout
    // around the field nor SwiftUI's environment may flip it.
    override var semanticContentAttribute: UISemanticContentAttribute {
        get { .forceLeftToRight }
        set { super.semanticContentAttribute = .forceLeftToRight }
    }

    // Hebrew and Arabic keyboards ask for right-to-left paragraphs, which would show a leading
    // "+" after the digits.
    override func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
        super.setBaseWritingDirection(.leftToRight, for: range)
    }

    /// Shows a number that changed elsewhere, such as one chosen from Contacts. Text that is
    /// already shown is left alone, so the caret stays where the person is typing.
    func show(_ value: String) {
        guard text != value, markedTextRange == nil else { return }
        text = value
    }

    /// Left alignment and a left-to-right paragraph, whatever keyboard is active.
    func keepLeftToRight() {
        textAlignment = .left
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.baseWritingDirection = .leftToRight
        defaultTextAttributes[.paragraphStyle] = paragraph
    }

    private func configure() {
        super.semanticContentAttribute = .forceLeftToRight
        keyboardType = Self.keyboardType(for: UIDevice.current.userInterfaceIdiom)
        if #available(iOS 26.0, *) {
            if responds(to: #selector(setter: UITextInputTraits.allowsNumberPadPopover)) {
                allowsNumberPadPopover = false
            }
        }
        textContentType = .telephoneNumber
        returnKeyType = .done
        autocapitalizationType = .none
        autocorrectionType = .no
        spellCheckingType = .no
        smartDashesType = .no
        smartQuotesType = .no
        smartInsertDeleteType = .no
        inlinePredictionType = .no
        keepLeftToRight()
        inputAccessoryView = doneBar()
        addTarget(self, action: #selector(reportText), for: [.editingChanged, .editingDidEnd])
        addTarget(self, action: #selector(finishEditing), for: .editingDidEndOnExit)
        // The clear button and the keyboard's undo key may change the text without .editingChanged;
        // this notification covers them, so Save never stores a number the field no longer shows.
        NotificationCenter.default.addObserver(self, selector: #selector(phoneTextDidChange(_:)), name: UITextField.textDidChangeNotification, object: self)
    }

    /// Phone keypads have no Return key, so a Done control sits above every keyboard.
    private func doneBar() -> UIToolbar {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        bar.tintColor = UIColor(Palette.teal)
        let done = UIBarButtonItem(title: L("Done"), style: .plain, target: self, action: #selector(finishEditing))
        let size = UIFont.preferredFont(forTextStyle: .title3).pointSize
        done.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: size, weight: .semibold)], for: .normal)
        bar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
        bar.sizeToFit()
        return bar
    }

    @objc private func reportText() { onTextChange?(text ?? "") }
    @objc private func phoneTextDidChange(_ notification: Notification) { reportText() }
    @objc private func finishEditing() { resignFirstResponder() }
}

/// SwiftUI host for `PhoneEntryField`. The binding receives the text exactly as typed.
struct PhoneNumberField: UIViewRepresentable {
    var title: String
    @Binding var text: String
    var textStyle: UIFont.TextStyle = .title2
    var monospacedDigits = false
    var clearButton = true
    var identifier: String?
    var minHeight: CGFloat = 0
    var textColor: UIColor?

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    /// Ends system-keyboard typing in any phone field, so a number changed by on-screen buttons
    /// is shown (while the keyboard types, the field alone owns its number; see updateUIView).
    @MainActor static func endTyping() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func makeUIView(context: Context) -> PhoneEntryField {
        let field = PhoneEntryField(frame: .zero)
        field.font = scaledFont
        field.adjustsFontForContentSizeCategory = true
        field.tintColor = UIColor(Palette.teal)
        if let textColor { field.textColor = textColor }
        // After the font and color, which share the field's default text attributes.
        field.keepLeftToRight()
        field.clearButtonMode = clearButton ? .whileEditing : .never
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let coordinator = context.coordinator
        field.onTextChange = { coordinator.received($0) }
        field.text = text
        applyLabels(to: field)
        return field
    }

    func updateUIView(_ field: PhoneEntryField, context: Context) {
        context.coordinator.text = $text
        applyLabels(to: field)
        // While the person is typing, the field alone owns the number. SwiftUI can call this with
        // a value that is a keystroke or two behind (fast typing on an iPad keyboard), and writing
        // it back erased newer digits (the iPad UI test lost "36" of "636"). Changes made
        // elsewhere, such as a number picked from Contacts, are shown once editing has ended.
        guard !field.isFirstResponder else { return }
        field.show(text)
    }

    // Fills the offered width; at least `minHeight` tall, so the whole row takes the tap.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView field: PhoneEntryField, context: Context) -> CGSize? {
        let natural = field.intrinsicContentSize
        return CGSize(width: proposal.width ?? natural.width, height: max(natural.height, minHeight))
    }

    private func applyLabels(to field: PhoneEntryField) {
        if field.placeholder != title { field.placeholder = title }
        field.accessibilityLabel = title
        field.accessibilityIdentifier = identifier
    }

    private var scaledFont: UIFont {
        guard monospacedDigits else { return UIFont.preferredFont(forTextStyle: textStyle) }
        let standard = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: standard.pointSize, weight: .regular))
    }

    final class Coordinator {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        /// Stores what was typed, unchanged.
        func received(_ value: String) {
            if text.wrappedValue != value { text.wrappedValue = value }
        }
    }
}
