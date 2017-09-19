import Foundation
import UIKit
import TinyConstraints

class PassphraseSignInFooter: UICollectionReusableView {
    
    static let reuseIdentifier: String = "PassphraseSignInFooter"
    
    private lazy var divider: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.borderColor
        
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = Theme.borderColor
        
        addSubview(divider)
        divider.top(to: self)
        divider.left(to: self, offset: 15)
        divider.right(to: self, offset: -15)
        divider.height(180)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
