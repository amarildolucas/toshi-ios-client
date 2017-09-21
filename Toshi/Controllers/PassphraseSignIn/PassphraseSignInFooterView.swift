import Foundation
import UIKit
import TinyConstraints

class PassphraseSignInFooterView: UIView {

    private lazy var divider: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.borderColor

        return view
    }()

    private(set) lazy var signInButton: ActionButton = {
        let view = ActionButton(margin: 0)
        view.setButtonStyle(.primary)

        return view
    }()

    private lazy var explanationButton: UIButton = {
        let view = UIButton()
        view.setTitle(Localized("passphrase_sign_in_explanation_title"), for: .normal)
        view.setTitleColor(Theme.greyTextColor, for: .normal)

        return view
    }()
    
    var numberOfMatches: Int = 0 {
        didSet {
            if numberOfMatches == PassphraseSignInViewController.maxItemCount {
                signInButton.title = Localized("passphrase_sign_in_button")
                signInButton.isEnabled = true
            } else {
                signInButton.title = String(format: Localized(numberOfMatches == (PassphraseSignInViewController.maxItemCount - 1) ? "passphrase_sign_in_button_placeholder_singular" : "passphrase_sign_in_button_placeholder"), PassphraseSignInViewController.maxItemCount - numberOfMatches)
                signInButton.isEnabled = false
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(divider)
        addSubview(signInButton)
        addSubview(explanationButton)

        divider.top(to: self)
        divider.left(to: self, offset: 30)
        divider.right(to: self, offset: -30)
        divider.height(1)

        signInButton.topToBottom(of: divider, offset: 30)
        signInButton.left(to: self, offset: 30)
        signInButton.right(to: self, offset: -30)
        signInButton.heightConstraint.constant = 50

        explanationButton.topToBottom(of: signInButton, offset: 5)
        explanationButton.left(to: self, offset: 30)
        explanationButton.right(to: self, offset: -30)
        explanationButton.bottom(to: self)
        explanationButton.height(50)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
