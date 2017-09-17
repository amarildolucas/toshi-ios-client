import Foundation
import UIKit
import TinyConstraints

class PassphraseSignInHeader: UICollectionReusableView {
    
    static let reuseIdentifier: String = "PassphraseSignInHeader"
    
    private lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = "Sign in with your Passphrase"
        view.textAlignment = .center
        view.textColor = Theme.darkTextColor
        view.font = Theme.regular(size: 34)
        view.numberOfLines = 0
        
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(titleLabel)
        titleLabel.edges(to: self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
