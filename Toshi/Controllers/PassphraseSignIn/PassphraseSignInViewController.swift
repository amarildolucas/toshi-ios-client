import Foundation
import UIKit
import TinyConstraints

final class PassphraseSignInViewController: UIViewController {

    var signInView: PassphraseSignInView? { return view as? PassphraseSignInView }
    var typed: [String] = [""]
    var itemCount: Int = 1

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
        automaticallyAdjustsScrollViewInsets = false

        signInView?.collectionView.delegate = self
        signInView?.collectionView.dataSource = self
        signInView?.textField.delegate = self
        signInView?.textField.deleteDelegate = self

        loadPasswords {
            self.passwords = $0
            self.signInView?.collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
        }
    }

    private func loadPasswords(_  completion: @escaping ([String]?) -> Void) {

        if let path = Bundle.main.path(forResource: "passwords-library", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                completion(data.components(separatedBy: .newlines))
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

    fileprivate func addItem(at indexPath: IndexPath, completion: ((Bool) -> Swift.Void)? = nil) {

        UIView.animate(withDuration: 0) {
            self.signInView?.collectionView.performBatchUpdates({
                self.signInView?.collectionView.insertItems(at: [indexPath])
                self.itemCount += 1
                self.typed.append("")
            }, completion: { finished in
                self.signInView?.layoutIfNeeded()
                completion?(finished)
            })
        }
    }

    fileprivate func cleanUp(after indexPath: IndexPath, completion: ((Bool) -> Swift.Void)? = nil) {

        UIView.animate(withDuration: 0) {
            self.signInView?.collectionView.performBatchUpdates({
                self.signInView?.collectionView.indexPathsForVisibleItems.forEach {

                    if $0 != indexPath, self.typed[$0.item].isEmpty {
                        self.typed.remove(at: $0.item)
                        self.signInView?.collectionView.deleteItems(at: [$0])
                        self.itemCount -= 1
                    }
                }
            }, completion: { finished in
                self.signInView?.layoutIfNeeded()
                completion?(finished)
            })
        }
    }
}

extension PassphraseSignInViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if let cell = activeCell {
            signInView?.textField.text = cell.text
        }

        cleanUp(after: indexPath)
    }
}

extension PassphraseSignInViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PassphraseSignInCell.reuseIdentifier, for: indexPath)

        if let cell = cell as? PassphraseSignInCell {
            cell.setText(typed[indexPath.item], isFirstAndOnly: itemCount == 1)
        }

        return cell
    }
}

extension PassphraseSignInViewController: UITextFieldDelegate {

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let indexPath = activeIndexPath else { return false }

        if string == " " || string == "\n" {
            signInView?.textField.text = nil

            let newIndexPath = IndexPath(item: itemCount, section: 0)
            UIView.performWithoutAnimation {
            addItem(at: newIndexPath, completion: { [weak self] _ in
                UIView.performWithoutAnimation {
                self?.cleanUp(after: newIndexPath, completion: { [weak self] _ in
                    guard let itemCount = self?.itemCount else { return }
                    let newIndexPath = IndexPath(item: itemCount - 1, section: 0)
                    self?.signInView?.collectionView.selectItem(at: newIndexPath, animated: false, scrollPosition: .top)
                    UIView.performWithoutAnimation {
                    self?.cleanUp(after: newIndexPath)
                    }
                })
                }
            })
            }

            return false
        }

        if let text = (textField.text as NSString?)?.replacingCharacters(in: range, with: string), let cell = activeCell {
            typed[indexPath.item] = text

            if let match = passwordMatch(for: text) {
                cell.setText(text, with: match)
            } else {
                cell.setText(text, isFirstAndOnly: itemCount == 1)
            }

            signInView?.collectionView.collectionViewLayout.invalidateLayout()
        }

        signInView?.layoutIfNeeded()

        return true
    }
}

extension PassphraseSignInViewController: TextFieldDeleteDelegate {

    func backspacedOnEmptyField() {
        guard let indexPath = activeIndexPath, indexPath.item != 0 else { return }

        let newIndexPath = IndexPath(item: indexPath.item - 1, section: 0)
        signInView?.collectionView.selectItem(at: newIndexPath, animated: false, scrollPosition: .top)

        if let cell = activeCell {
            signInView?.textField.text = cell.text
        }

        cleanUp(after: newIndexPath)
    }
}
