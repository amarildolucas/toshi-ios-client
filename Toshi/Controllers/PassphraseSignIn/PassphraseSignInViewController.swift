import Foundation
import UIKit
import TinyConstraints

final class PassphraseSignInViewController: UIViewController {

    var signInView: PassphraseSignInView? { return view as? PassphraseSignInView }
    
    var previousIndexPath: IndexPath?
        
    var activeIndexPath: IndexPath? {
        if let selectedCell = signInView?.collectionView.visibleCells.first(where: { $0.isSelected }) {
            return signInView?.collectionView.indexPath(for: selectedCell)
        }
        
        return nil
    }

    var activeCell: PassphraseSignInCell? {
        guard let activeIndexPath = activeIndexPath else { return nil }
        return signInView?.collectionView.cellForItem(at: activeIndexPath) as? PassphraseSignInCell
    }
    
    var typed: [IndexPath: String] = [IndexPath(item: 0, section: 0): ""]
    
    var passwords: [String]? = nil {
        didSet {
            signInView?.collectionView.reloadData()
        }
    }

    override func loadView() {
        view = PassphraseSignInView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        signInView?.collectionView.delegate = self
        signInView?.collectionView.dataSource = self

        signInView?.textField.delegate = self

        loadPasswords { [weak self] in
            self?.passwords = $0
            self?.signInView?.collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
        }
    }

    private func loadPasswords(_  completion: @escaping ([String]?) -> Void) {

        if let path = Bundle.main.path(forResource: "passwords-library", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let passwords = data.components(separatedBy: .newlines)
                completion(passwords)
            } catch {
                completion(nil)
            }
        }
    }

    func passwordMatch(for text: String) -> String? {
        guard !text.isEmpty else { return nil }

        let filtered = passwords?.filter {
            $0.range(of: text, options: [.caseInsensitive, .anchored]) != nil
        }

        return filtered?.first
    }
    
    fileprivate func addItem(at indexPath: IndexPath) {
        typed[indexPath] = ""
        signInView?.collectionView.insertItems(at: [indexPath])
        signInView?.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
    }
    
    fileprivate func cleanUp(after indexPath: IndexPath) {
        
        typed.keys.filter { self.typed[$0]!.isEmpty }.forEach {
            if $0 != indexPath {
                typed.removeValue(forKey: $0)
                signInView?.collectionView.deleteItems(at: [$0])
            }
        }
    }
}

extension PassphraseSignInViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        previousIndexPath = activeIndexPath
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if let cell = activeCell {
            signInView?.textField.text = cell.text
        }
        
        cleanUp(after: indexPath)
    }
}

extension PassphraseSignInViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return typed.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PassphraseSignInCell.reuseIdentifier, for: indexPath)
        
        if let cell = cell as? PassphraseSignInCell, let text = typed[indexPath] {
            cell.setText(text)
        }
        
        return cell
    }
}

extension PassphraseSignInViewController: UITextFieldDelegate {

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let indexPath = activeIndexPath else { return false }
        
        if string == " " || string == "\n" {
            signInView?.textField.text = nil
            previousIndexPath = activeIndexPath
            
            let newIndexPath = IndexPath(item: typed.count, section: 0)
            addItem(at: newIndexPath)
            cleanUp(after: newIndexPath)
            
            return false
        }
        
        if let text = (textField.text as NSString?)?.replacingCharacters(in: range, with: string), let cell = activeCell {
            typed[indexPath] = text
            
            if let match = passwordMatch(for: text) {
                cell.setText(text, with: match)
            } else {
                cell.setText(text)
            }
            
            signInView?.collectionView.collectionViewLayout.invalidateLayout()
        }

        return true
    }
}
