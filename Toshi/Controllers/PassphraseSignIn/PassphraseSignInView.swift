import Foundation
import UIKit
import TinyConstraints

final class PassphraseSignInView: UIView {
    
    private lazy var layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize
        
        return layout
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
        view.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseIdentifier)
//        view.dataSource = self
        view.backgroundColor = .white
        view.delaysContentTouches = false
        view.isPagingEnabled = true
        
        return view
    }()
    
    var passwords: [String]? = nil {
        didSet {
            collectionView.reloadData()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.viewBackgroundColor
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
