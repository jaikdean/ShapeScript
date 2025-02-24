//
//  TextView.swift
//  Subtext
//
//  Created by Nick Lockwood on 22/01/2022.
//

import UIKit

class TextView: UIScrollView {
    private let layoutManager: LayoutManager
    private let gutterView = LineNumberView()
    private var lineCount = 0
    let textView: UITextView

    private var _contentInset: UIEdgeInsets = .zero
    override var contentInset: UIEdgeInsets {
        get { _contentInset }
        set {
            _contentInset = newValue
            setNeedsLayout()
        }
    }

    override var undoManager: UndoManager? {
        textView.undoManager
    }

    var showLineNumbers: Bool = false {
        didSet {
            guard showLineNumbers != oldValue else {
                return
            }
            updateLineCount()
            setNeedsLayout()
        }
    }

    var wrapLines: Bool = false {
        didSet { setNeedsLayout() }
    }

    var spellCheckingType: UITextSpellCheckingType = .no {
        didSet {
            textView.spellCheckingType = spellCheckingType
            // Workaround for spellcheck mode not updating
            textView.reloadInputViews()
        }
    }

    var text: String? {
        get { textView.text }
        set {
            guard newValue != textView.text else {
                return
            }
            textView.text = newValue
            updateLineCount()
            previousSize = .zero
            setNeedsLayout()
        }
    }

    var font: UIFont = .monospacedSystemFont(ofSize: 15, weight: .regular) {
        didSet { updateFont() }
    }

    var isEditable: Bool = true {
        didSet { textView.isEditable = isEditable }
    }

    override var isFirstResponder: Bool {
        textView.isFirstResponder
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        textView.becomeFirstResponder()
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        textView.resignFirstResponder()
    }

    override init(frame: CGRect) {
        layoutManager = LayoutManager()
        textView = TextView.textView(with: layoutManager)
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        layoutManager = LayoutManager()
        textView = TextView.textView(with: layoutManager)
        super.init(coder: coder)
        setUp()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setUp() {
        layoutManager.delegate = self
        contentInsetAdjustmentBehavior = .never
        super.contentInset = .zero
        isDirectionalLockEnabled = true
        showsHorizontalScrollIndicator = true
        textView.font = UIFontMetrics.default.scaledFont(for: font)
        textView.adjustsFontForContentSizeCategory = true
        textView.contentInsetAdjustmentBehavior = .never
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = true
        textView.alwaysBounceHorizontal = false
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .no
        textView.spellCheckingType = spellCheckingType
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.isEditable = isEditable
        textView.frame = bounds
        textView.delegate = self
        textView.textDragDelegate = self
        textView.textDropDelegate = self
        addSubview(textView)
        gutterView.font = UIFontMetrics.default.scaledFont(for: font)
        gutterView.backgroundColor = .secondarySystemBackground
        gutterView.contentMode = .right
        gutterView.isHidden = true
        addSubview(gutterView)
        avoidKeyboard()
        updateLineCount()
        updateInsets()
    }

    private var previousSize: CGSize = .zero
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLineNumbers()
        updateInsets()
        let size = frame.size
        let width = wrapLines ? size.width : .greatestFiniteMagnitude
        if width != previousSize.width || size.height != previousSize.height {
            previousSize.width = width
            previousSize.height = size.height
            textView.sizeToFitWidth(width, in: size)
            if contentSize != textView.frame.size {
                contentSize = textView.frame.size
            }
        }
        showsHorizontalScrollIndicator = !wrapLines
        textView.verticalScrollIndicatorInsets.bottom = max(
            _contentInset.bottom,
            safeAreaInsets.bottom
        )
        textView.verticalScrollIndicatorInsets.right = textView.frame.width
            - frame.width - contentOffset.x - safeAreaInsets.left
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        gutterView.font = UIFontMetrics.default.scaledFont(for: font)
        setNeedsLayout()
    }
}

private extension TextView {
    static func textView(with layoutManager: LayoutManager) -> UITextView {
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        return UITextView(frame: .zero, textContainer: textContainer)
    }

    func updateFont() {
        textView.font = UIFontMetrics.default.scaledFont(for: font)
        gutterView.font = UIFontMetrics.default.scaledFont(for: font)
        setNeedsLayout()
    }

    func updateInsets() {
        var inset = UIEdgeInsets(
            top: _contentInset.top + safeAreaInsets.top,
            left: _contentInset.left + safeAreaInsets.left,
            bottom: _contentInset.bottom + safeAreaInsets.bottom,
            right: _contentInset.right + safeAreaInsets.right
        )
        if showLineNumbers {
            layoutManager.gutterWidth = ceil(String(lineCount).size(withAttributes: [
                .font: UIFontMetrics.default.scaledFont(for: font),
            ]).width + 8)
            inset.left = max(inset.left, layoutManager.gutterWidth)
            gutterView.isHidden = false
            gutterView.frame.origin.x = contentOffset.x
            gutterView.frame.size = CGSize(
                width: inset.left,
                height: frame.height
            )
        } else {
            gutterView.isHidden = true
            gutterView.frame.size.width = 0
        }
        if inset != textView.contentInset {
            textView.contentInset = inset
            if textView.contentOffset.y == 0 {
                textView.contentOffset.y = -inset.top
            }
        }
    }

    func updateLineCount() {
        guard showLineNumbers else {
            return
        }
        let lineCount = (text ?? "").lineCount
        if lineCount != self.lineCount {
            self.lineCount = lineCount
            setNeedsLayout()
        }
    }

    func updateLineNumbers() {
        guard showLineNumbers else {
            return
        }
        gutterView.gutterWidth = layoutManager.gutterWidth
        gutterView.indexRects = layoutManager.indexRects
        gutterView.scrollOffset = textView.contentOffset.y
        gutterView.font = UIFontMetrics.default.scaledFont(for: font)
        gutterView.setNeedsLayout()
    }
}

private extension String {
    var lineCount: Int {
        reduce(0) { $0 + ("\r\n\n\r".contains($1) ? 1 : 0) }
    }
}

extension UITextView {
    func textRange(from range: NSRange) -> UITextRange? {
        guard let start = position(
            from: beginningOfDocument,
            offset: range.location
        ), let end = position(
            from: start,
            offset: range.length
        ) else {
            return nil
        }
        return textRange(from: start, to: end)
    }
}

private extension UITextView {
    func sizeToFitWidth(_ width: CGFloat, in bounds: CGSize) {
        let newWidth = sizeThatFits(CGSize(
            width: width - contentInset.left - contentInset.right,
            height: CGFloat.greatestFiniteMagnitude
        )).width + contentInset.left + contentInset.right
        let newSize = CGSize(
            width: max(newWidth, bounds.width),
            height: bounds.height
        )
        if newSize != frame.size {
            isScrollEnabled = false
            frame.size = newSize
            isScrollEnabled = true
        }
    }
}

extension TextView: UITextViewDelegate, UIScrollViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        (delegate as? UITextViewDelegate)?.textViewDidChange?(textView)
        if !wrapLines {
            previousSize = .zero
            setNeedsLayout()
        }
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard (delegate as? UITextViewDelegate)?.textView?(
            textView,
            shouldChangeTextIn: range,
            replacementText: text
        ) ?? true else {
            return false
        }
        if showLineNumbers {
            var count = 0
            if let oldRange = textView.textRange(from: range),
               let oldText = textView.text(in: oldRange)
            {
                count -= oldText.lineCount
            }
            count += text.lineCount
            if count != 0 {
                lineCount += count
                setNeedsLayout()
            }
        }
        return true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.scrollViewDidScroll?(scrollView)
        updateLineNumbers()
    }
}

extension TextView: UITextDragDelegate, UITextDropDelegate {
    private func setText(_ text: String?) {
        textView.undoManager?.beginUndoGrouping()
        let oldText = textView.text ?? ""
        textView.undoManager?.registerUndo(withTarget: self) {
            $0.setText(oldText)
        }
        textView.undoManager?.setActionName("Drag Text")
        if let text = text {
            textView.text = text
        }
        textView.undoManager?.endUndoGrouping()
    }

    func textDroppableView(_: UIView & UITextDroppable,
                           willPerformDrop _: UITextDropRequest)
    {
        setText(nil)
    }

    func textDroppableView(_: UIView & UITextDroppable,
                           dropSessionDidEnd _: UIDropSession)
    {
        textViewDidChange(textView)
    }
}

extension TextView: NSLayoutManagerDelegate {
    func layoutManager(_: NSLayoutManager, didCompleteLayoutFor _: NSTextContainer?,
                       atEnd _: Bool)
    {
        layoutManager.indexRects.removeAll()
    }

    func didLayoutNumbers() {
        updateLineNumbers()
    }
}

private extension TextView {
    func avoidKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let rect = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        {
            _contentInset.bottom = rect.size.height - safeAreaInsets.bottom
            setNeedsLayout()
        }
    }

    @objc func keyboardWillHide(_: Notification) {
        _contentInset.bottom = .zero
        setNeedsLayout()
    }
}

private class LayoutManager: NSLayoutManager {
    private var lastParaLocation: Int = 0
    private var lastParaNumber: Int = 0

    var gutterWidth: CGFloat = 0
    var indexRects: [Int: CGRect] = [:]

    override func processEditing(
        for textStorage: NSTextStorage,
        edited editMask: NSTextStorage.EditActions,
        range newCharRange: NSRange,
        changeInLength delta: Int,
        invalidatedRange invalidatedCharRange: NSRange
    ) {
        super.processEditing(
            for: textStorage,
            edited: editMask,
            range: newCharRange,
            changeInLength: delta,
            invalidatedRange: invalidatedCharRange
        )

        if invalidatedCharRange.location < lastParaLocation {
            lastParaLocation = 0
            lastParaNumber = 0
        }
    }

    override func drawBackground(
        forGlyphRange glyphsToShow: NSRange,
        at origin: CGPoint
    ) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        var gutterRect: CGRect = .zero
        var paraNumber = 0

        enumerateLineFragments(
            forGlyphRange: glyphsToShow
        ) { rect, _, _, glyphRange, _ in
            let charRange = self.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            let paraRange = ((self.textStorage?.string ?? "") as NSString)
                .paragraphRange(for: charRange)

            if charRange.location == paraRange.location {
                paraNumber = self.paraNumber(for: charRange)
                gutterRect = CGRect(
                    x: origin.x,
                    y: rect.origin.y + origin.y,
                    width: self.gutterWidth,
                    height: rect.size.height
                )
                self.indexRects[paraNumber + 1] = gutterRect
            }
        }

        if NSMaxRange(glyphsToShow) > numberOfGlyphs {
            indexRects[paraNumber + 2] = gutterRect.offsetBy(
                dx: 0,
                dy: gutterRect.height
            )
        }

        (delegate as? TextView)?.didLayoutNumbers()
    }

    func paraNumber(for charRange: NSRange) -> Int {
        if charRange.location == lastParaLocation {
            return lastParaNumber
        }

        let string = (textStorage?.string ?? "") as NSString
        var paraNumber = lastParaNumber

        if charRange.location < lastParaLocation {
            string.enumerateSubstrings(
                in: NSRange(
                    location: charRange.location,
                    length: lastParaLocation - charRange.location
                ),
                options: [.byParagraphs, .substringNotRequired, .reverse]
            ) { _, _, enclosingRange, stop in
                if enclosingRange.location <= charRange.location {
                    stop.pointee = true
                }
                paraNumber -= 1
            }

            lastParaLocation = charRange.location
            lastParaNumber = paraNumber
            return paraNumber
        }

        string.enumerateSubstrings(
            in: NSRange(
                location: lastParaLocation,
                length: charRange.location - lastParaLocation
            ),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, _, enclosingRange, stop in
            if enclosingRange.location >= charRange.location {
                stop.pointee = true
            }
            paraNumber += 1
        }

        lastParaLocation = charRange.location
        lastParaNumber = paraNumber
        return paraNumber
    }
}

private class LineNumberView: UIView {
    private var numberViews: [UILabel] = []

    var gutterWidth: CGFloat = 0
    var scrollOffset: CGFloat = 0
    var indexRects: [Int: CGRect] = [:]
    var font: UIFont?

    override func layoutSubviews() {
        let atts: [NSAttributedString.Key: Any] = [
            .font: font ?? .preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.secondaryLabel,
        ]

        var numberViews = self.numberViews
        for (i, rect) in indexRects {
            let rect = rect.offsetBy(dx: 0, dy: -scrollOffset)
            if rect.maxY < 0 || rect.minY > bounds.height {
                continue
            }
            let text = String(i)
            let size = text.size(withAttributes: atts)

            let view = numberViews.popLast() ?? {
                let view = UILabel()
                self.numberViews.append(view)
                addSubview(view)
                return view
            }()

            UIView.performWithoutAnimation {
                view.attributedText = NSAttributedString(
                    string: text,
                    attributes: atts
                )
                view.frame = rect.offsetBy(
                    dx: bounds.width - size.width - 4,
                    dy: 0
                )
            }
        }
        while let view = numberViews.popLast() {
            view.removeFromSuperview()
            self.numberViews.removeFirst()
        }
    }
}
