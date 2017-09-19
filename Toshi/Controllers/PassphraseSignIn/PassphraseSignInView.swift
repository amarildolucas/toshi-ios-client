import Foundation
import UIKit
import TinyConstraints

final class PassphraseSignInView: UIView {

    private lazy var layout: PassphraseSignInLayout = {
        let layout = PassphraseSignInLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        layout.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize
        layout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        return layout
    }()

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
        view.backgroundColor = nil
        view.delaysContentTouches = false
        view.isScrollEnabled = false
        
        view.register(PassphraseSignInCell.self, forCellWithReuseIdentifier: PassphraseSignInCell.reuseIdentifier)
        
        return view
    }()

    lazy var textField: DeletableTextField = {
        let view = DeletableTextField()
        view.font = Theme.regular(size: 16)
        view.textColor = Theme.darkTextColor
        view.returnKeyType = .next
        view.alpha = 0
        
        view.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        view.becomeFirstResponder()

        return view
    }()
    
    private var collectionViewHeightConstraint: NSLayoutConstraint?
    
    private lazy var headerView: PassphraseSignInHeaderView = PassphraseSignInHeaderView()
    private lazy var footerView: PassphraseSignInFooterView = PassphraseSignInFooterView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.viewBackgroundColor

        addSubview(collectionView)
        addSubview(textField)
        addSubview(headerView)
        addSubview(footerView)
        
        headerView.top(to: self, offset: 20)
        headerView.left(to: self)
        headerView.right(to: self)
        headerView.height(PassphraseSignInHeaderView.height)
        
        collectionView.topToBottom(of: headerView, offset: 10)
        collectionView.left(to: self)
        collectionView.right(to: self)
        collectionViewHeightConstraint = collectionView.height(36)
        
        footerView.topToBottom(of: collectionView, offset: 10)
        footerView.left(to: self)
        footerView.right(to: self)
        
        textField.left(to: self)
        textField.bottom(to: self, offset: 0)
        textField.right(to: self)
        textField.height(44)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textFieldDidChange(_ textField: UITextField) {
        textField.text = textField.text?.lowercased()
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        collectionViewHeightConstraint?.constant = collectionView.contentSize.height
    }
}
