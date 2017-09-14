import Foundation
import UIKit
import TinyConstraints

final class PassphraseSignInViewController: UIViewController {
    
    var signInView: PassphraseSignInView? { return view as? PassphraseSignInView }
    
    override func loadView() {
        view = PassphraseSignInView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadPasswords { [weak self] in
            self?.signInView?.passwords = $0
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
}
