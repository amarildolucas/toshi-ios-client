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

import Foundation
import UIKit
import SweetUIKit

protocol OfflineAlertDisplaying: class {
    var offlineAlertView: OfflineAlertView { get }
    var offlineAlertViewConstraints: [NSLayoutConstraint] { get }

    func setupOfflineAlertView(hidden: Bool)
    func defaultOfflineAlertView() -> OfflineAlertView
    func showOfflineAlertView()
    func hideOfflineAlertView()

    func requestLayoutUpdate()
}

extension OfflineAlertDisplaying where Self: UINavigationController {
    func setupOfflineAlertView(hidden: Bool = false) {
        guard let offlineAlertView = self.offlineAlertView as OfflineAlertView? else { return }

        view.addSubview(offlineAlertView)
        NSLayoutConstraint.activate(offlineAlertViewConstraints)

        if !hidden {
            showOfflineAlertView()
        }
    }

    func defaultOfflineAlertView() -> OfflineAlertView {
        let offlineAlertView = OfflineAlertView(withAutoLayout: true)

        return offlineAlertView
    }

    func showOfflineAlertView() {

        DispatchQueue.main.async {
            self.offlineAlertView.heightConstraint?.constant = ActiveNetworkView.height
            self.requestLayoutUpdate()
        }
    }

    func hideOfflineAlertView() {
        DispatchQueue.main.async {
            self.offlineAlertView.heightConstraint?.constant = 0
            self.requestLayoutUpdate()
        }
    }

    func requestLayoutUpdate() {

        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
}
