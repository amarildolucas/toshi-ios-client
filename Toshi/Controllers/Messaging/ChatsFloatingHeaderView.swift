// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import UIKit
import SweetUIKit

protocol ChatsFloatingHeaderViewDelegate: class {
    func messagesFloatingView(_ messagesFloatingView: ChatsFloatingHeaderView, didPressRequestButton button: UIButton)
    func messagesFloatingView(_ messagesFloatingView: ChatsFloatingHeaderView, didPressPayButton button: UIButton)
}

class ChatsFloatingHeaderView: UIView {
    weak var delegate: ChatsFloatingHeaderViewDelegate?

    static let height = CGFloat(48)

    private(set) lazy var fiatValueLabel: UILabel = {
        let label = UILabel(withAutoLayout: true)
        label.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        label.textColor = Theme.darkTextColor
        label.font = Theme.regular(size: 16)

        return label
    }()

    private(set) lazy var ethereumValueLabel: UILabel = {
        let label = UILabel(withAutoLayout: true)
        label.textColor = Theme.lightGreyTextColor
        label.font = Theme.regular(size: 16)

        return label
    }()

    static func button() -> UIButton {
        let button = UIButton(withAutoLayout: true)
        button.setTitleColor(Theme.tintColor, for: .normal)
        button.titleLabel?.font = Theme.semibold(size: 13)

        return button
    }

    fileprivate var buttonAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey(rawValue: NSAttributedStringKey.font.rawValue): Theme.medium(size: 15), NSAttributedStringKey(rawValue: NSAttributedStringKey.foregroundColor.rawValue): Theme.tintColor]

    private(set) lazy var requestButton: UIButton = {
        let button = ChatsFloatingHeaderView.button()
        button.setAttributedTitle(NSAttributedString(string: "Request", attributes: self.buttonAttributes), for: .normal)
        button.addTarget(self, action: #selector(request(button:)), for: .touchUpInside)

        return button
    }()

    private(set) lazy var payButton: UIButton = {
        let button = ChatsFloatingHeaderView.button()
        button.setAttributedTitle(NSAttributedString(string: "Pay", attributes: self.buttonAttributes), for: .normal)
        button.addTarget(self, action: #selector(pay(button:)), for: .touchUpInside)

        return button
    }()

    var balance: NSDecimalNumber? {
        didSet {
            if let balance = self.balance {
                let rate = ExchangeRateClient.exchangeRate
                fiatValueLabel.text = EthereumConverter.fiatValueStringWithCode(forWei: balance, exchangeRate: rate)
                ethereumValueLabel.text = EthereumConverter.ethereumValueString(forWei: balance)
            } else {
                fiatValueLabel.text = nil
                ethereumValueLabel.text = nil
            }
        }
    }

    private(set) lazy var separatorView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.backgroundColor = Theme.borderColor

        return view
    }()

    lazy var backgroundBlur: BlurView = {
        let view = BlurView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(backgroundBlur)
        addSubview(fiatValueLabel)
        addSubview(ethereumValueLabel)
        addSubview(requestButton)
        addSubview(payButton)
        addSubview(separatorView)

        backgroundBlur.edges(to: self)

        let margin = CGFloat(10)
        fiatValueLabel.topAnchor.constraint(equalTo: topAnchor).isActive = true
        fiatValueLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        fiatValueLabel.leftAnchor.constraint(equalTo: leftAnchor, constant: margin).isActive = true

        ethereumValueLabel.topAnchor.constraint(equalTo: topAnchor).isActive = true
        ethereumValueLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        ethereumValueLabel.leftAnchor.constraint(equalTo: fiatValueLabel.rightAnchor, constant: margin).isActive = true

        let buttonWidth = CGFloat(70)
        requestButton.topAnchor.constraint(equalTo: topAnchor).isActive = true
        requestButton.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        requestButton.leftAnchor.constraint(equalTo: ethereumValueLabel.rightAnchor).isActive = true
        requestButton.rightAnchor.constraint(equalTo: payButton.leftAnchor).isActive = true
        requestButton.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true

        payButton.topAnchor.constraint(equalTo: topAnchor).isActive = true
        payButton.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        payButton.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        payButton.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true

        separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separatorView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        separatorView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func request(button: UIButton) {
        delegate?.messagesFloatingView(self, didPressRequestButton: button)
    }

    @objc func pay(button: UIButton) {
        delegate?.messagesFloatingView(self, didPressPayButton: button)
    }
}
