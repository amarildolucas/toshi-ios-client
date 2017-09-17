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

    lazy var textField: DeletableTextField = {
        let view = DeletableTextField()
        view.font = Theme.regular(size: 16)
        view.textColor = Theme.darkTextColor
        view.returnKeyType = .next
        view.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.viewBackgroundColor

        addSubview(collectionView)
        collectionView.edges(to: self, insets: UIEdgeInsets(top: 100, left: 15, bottom: 0, right: -15))

        addSubview(textField)
        textField.left(to: self)
        textField.bottom(to: self, offset: 0)
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
