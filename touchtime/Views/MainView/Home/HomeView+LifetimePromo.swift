//
//  HomeView+LifetimePromo.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    // Show the Unlock All Features sheet to non-owners: not in their first
    // days with the app, then at most once a week, and only a few times in all
    func showLifetimePromoIfDue() {
        guard !hasLifetimeAccess else { return }

        let day: TimeInterval = 24 * 60 * 60
        let now = Date.now.timeIntervalSince1970
        // The first check starts the clock
        if lifetimePromoStartTime == 0 {
            lifetimePromoStartTime = now
        }

        guard now - lifetimePromoStartTime >= 3 * day,
              now - lifetimePromoLastShownTime >= 7 * day,
              lifetimePromoShownCount < 4,
              // Not while the user is scrolling through time or in a sheet
              timeOffset == 0,
              !isPresentingAnything else { return }

        lifetimePromoLastShownTime = now
        lifetimePromoShownCount += 1
        showLifetimePromo = true
    }

    // Whether a sheet, cover or alert is up, from Home or anywhere else in the
    // window, which the promo sheet would fail to present over. Any view
    // controller in the tree may be the presenter, such as the tab bar's.
    private var isPresentingAnything: Bool {
        func isPresenting(_ viewController: UIViewController) -> Bool {
            viewController.presentedViewController != nil
                || viewController.children.contains(where: isPresenting)
        }

        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let rootViewController = windowScene?.keyWindow?.rootViewController else {
            return false
        }
        return isPresenting(rootViewController)
    }
}
