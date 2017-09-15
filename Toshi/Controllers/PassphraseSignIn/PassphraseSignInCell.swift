import Foundation
import UIKit
import TinyConstraints

class PassphraseSignInCell: UICollectionViewCell {
    
    static let reuseIdentifier: String = "PassphraseSignInCell"
    private lazy var passwordLabel = UILabel()
    private(set) var text: String = ""
    private(set) var match: String?
    
    override var isSelected: Bool {
        didSet {
            contentView.backgroundColor = isSelected ? UIColor.lightGray.withAlphaComponent(0.5) : nil
            
            if isSelected {
                updateAttributedText(text, with: match)
            } else {
                updateAttributedText(match ?? "", with: match)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.isOpaque = false
        contentView.addSubview(passwordLabel)
        passwordLabel.edges(to: contentView, insets: UIEdgeInsets(top: 10, left: 10, bottom: -10, right: -10))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setText(_ text: String, with match: String? = nil) {
        self.text = text
        self.match = match
        
        updateAttributedText(text, with: match)
    }
    
    private func updateAttributedText(_ text: String, with match: String? = nil) {
    
        let string = text.isEmpty ? "..." : match ?? text
        
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
        }
        
        passwordLabel.attributedText = attributedText
    }
}
