import Foundation
import UIKit
import TinyConstraints

class PassphraseSignInFooterView: UIView {
    
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
        divider.left(to: self, offset: 30)
        divider.right(to: self, offset: -30)
        divider.height(1)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
