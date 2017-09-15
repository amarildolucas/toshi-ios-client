import Foundation
import UIKit
import TinyConstraints

final class PassphraseSignInViewController: UIViewController {

    var signInView: PassphraseSignInView? { return view as? PassphraseSignInView }

    var activeIndexPath: IndexPath? = nil {
        didSet {
            print("activeIndexPath:\(activeIndexPath)")
            if let cell = activeCell, activeIndexPath != oldValue {
                signInView?.textField.text = nil
            }
        }
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

        signInView?.collectionView.delegate = self
        signInView?.collectionView.dataSource = self

        signInView?.textField.delegate = self

        loadPasswords { [weak self] in
            self?.passwords = $0
            self?.activeIndexPath = IndexPath(item: 0, section: 0)
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

    func match(for text: String) -> String? {
        guard !text.isEmpty else { return nil }

        let filtered = passwords?.filter {
            $0.range(of: text, options: [.caseInsensitive, .literal, .anchored]) != nil
        }

        return filtered?.first
    }
}

extension PassphraseSignInViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        activeIndexPath = indexPath
    }
}

extension PassphraseSignInViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 12
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PassphraseSignInCell.reuseIdentifier, for: indexPath)

        return cell
    }
}

extension PassphraseSignInViewController: UITextFieldDelegate {

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let nsString = textField.text as NSString?

        if let text = nsString?.replacingCharacters(in: range, with: string) {

            print("text:\(text)")

            if let match = match(for: text), let cell = activeCell {
                cell.label.text = match

                if let indexPath = activeIndexPath {
                    UIView.performWithoutAnimation {
                        signInView?.collectionView.reloadItems(at: [indexPath])
                    }
                }
            }
        }

        return true
    }
}
