import Foundation
import UIKit
import TinyConstraints

final class PassphraseSignInView: UIView {
    
    private lazy var layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize
        
        return layout
    }()
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
        view.register(PassphraseSignInCell.self, forCellWithReuseIdentifier: PassphraseSignInCell.reuseIdentifier)
        view.backgroundColor = .white
        view.delaysContentTouches = false
        view.isScrollEnabled = false
        
        return view
    }()
    
    lazy var textField: UITextField = {
        let view = UITextField()
        view.font = Theme.regular(size: 16)
        view.textColor = Theme.darkTextColor
        view.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.viewBackgroundColor
        
        addSubview(collectionView)
        collectionView.edges(to: self)
        
        addSubview(textField)
        textField.left(to: self)
        textField.bottom(to: self, offset: -300)
        textField.right(to: self)
        textField.height(44)
        
        textField.becomeFirstResponder()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func textFieldDidChange(_ textField: UITextField) {
        textField.text = textField.text?.lowercased()
    }
}
