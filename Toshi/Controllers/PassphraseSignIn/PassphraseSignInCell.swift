import Foundation
import UIKit
import TinyConstraints

class PassphraseSignInCell: UICollectionViewCell {

    static let reuseIdentifier: String = "PassphraseSignInCell"
    private lazy var passwordLabel = UILabel()
    private(set) var text: String = ""
    private(set) var match: String?
    private(set) var isFirstAndOnly: Bool = false
    private var caretViewLeftConstraint: NSLayoutConstraint?
    private let caretKerning: CGFloat = 1
    
    private lazy var backgroundImageView: UIImageView = {
        let image = UIImage(named: "sign-in-cell-background")?.stretchableImage(withLeftCapWidth: 18, topCapHeight: 18)
        
        let view = UIImageView()
        view.image = image
        
        return view
    }()
    
    private var caretView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.tintColor
        view.layer.cornerRadius = 1
        view.clipsToBounds = true
        
        return view
    }()

    override var isSelected: Bool {
        didSet {
            caretView.alpha = isSelected ? 1 : 0
            backgroundImageView.isHidden = isSelected

            if let match = match, !isSelected {
                updateAttributedText(match, with: match)
                bounce()
            } else {
                updateAttributedText(text, with: match)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = nil
        contentView.isOpaque = false
        
        contentView.addSubview(backgroundImageView)
        contentView.addSubview(passwordLabel)
        passwordLabel.addSubview(caretView)
        
        backgroundImageView.edges(to: contentView)
        backgroundImageView.height(36, relation: .equalOrGreater)
        backgroundImageView.width(36, relation: .equalOrGreater)
        
        passwordLabel.edges(to: contentView, insets: UIEdgeInsets(top: 2, left: 13 + caretKerning, bottom: -4, right: -13))
        
        caretViewLeftConstraint = caretView.left(to: passwordLabel)
        caretView.centerY(to: passwordLabel)
        caretView.width(2)
        caretView.height(21)
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.caretView.isHidden = !self.caretView.isHidden
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ text: String, with match: String? = nil, isFirstAndOnly: Bool = false) {
        self.text = text
        self.match = match
        self.isFirstAndOnly = isFirstAndOnly

        updateAttributedText(text, with: match)
    }

    private func updateAttributedText(_ text: String, with match: String? = nil) {
        let emptyString = isFirstAndOnly ? Localized("passphrase_sign_in_placeholder") : Localized("passphrase_sign_in_ellipsis")
        let string = text.isEmpty ? emptyString : match ?? text

        let attributes: [String: Any] = [
            NSFontAttributeName: Theme.regular(size: 17),
            NSForegroundColorAttributeName: Theme.greyTextColor
            ]

        let matchingAttributes: [String: Any] = [
            NSFontAttributeName: Theme.regular(size: 17),
            NSForegroundColorAttributeName: Theme.darkTextColor
            ]

        let attributedText = NSMutableAttributedString(string: string, attributes: attributes)

        if let match = match, let matchingRange = (match as NSString?)?.range(of: text, options: [.caseInsensitive, .anchored]) {
            attributedText.addAttributes(matchingAttributes, range: matchingRange)
            attributedText.addAttribute(NSKernAttributeName, value: caretKerning, range: NSRange(location: matchingRange.length - 1, length: 1))
            
            let offset = matchingFrame(for: matchingRange, in: attributedText).width - caretKerning
            caretViewLeftConstraint?.constant = offset
        } else {
            caretViewLeftConstraint?.constant = 0
        }

        passwordLabel.attributedText = attributedText
    }
    
    func matchingFrame(for range: NSRange, in attributedText: NSAttributedString) -> CGRect {
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(size: passwordLabel.bounds.size)
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        
        var glyphRange = NSRange()
        
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    }
}
