import Foundation
import UIKit
import TinyConstraints

class PassphraseSignInCell: UICollectionViewCell {
    
    static let reuseIdentifier: String = "PassphraseSignInCell"
    
    lazy var label: UILabel = {
        let view = UILabel()
        view.text = "test"
        view.backgroundColor = .yellow
        view.font = Theme.regular(size: 16)
        view.textColor = Theme.darkTextColor
        
        return view
    }()
    
    private var contentLayoutGuideTopConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.backgroundColor = .red
        
        contentView.addSubview(label)
        label.edges(to: contentView, insets: UIEdgeInsets(top: 10, left: 10, bottom: -10, right: -10))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
