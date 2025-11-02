//
//  SSClientContainer.swift
//  Mudrammer
//
//  Swift reimplementation of SSClientContainer
//  Created by Jonathan Hersh on 4/20/13.
//  Copyright (c) 2013 Jonathan Hersh. All rights reserved.
//

import UIKit
import QuartzCore
import MessageUI

@objc(SSClientContainer)
@objcMembers
class SSClientContainer: JASidePanelController, MFMailComposeViewControllerDelegate {

    // MARK: - Properties

    private var myKVOController: FBKVOController?

    // MARK: - Initialization

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupContainer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContainer()
    }

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    private func setupContainer() {
        // Setup pane
        self.pushesSidePanels = false
        self.shouldResizeRightPanel = true
        self.rightFixedWidth = kWorldDisplayWidth
        self.minimumMovePercentage = 0.2
        self.recognizesPanGesture = true
        self.panningLimitedToTopViewController = true
        self.allowRightOverpan = false
        self.allowLeftOverpan = false
        self.maximumAnimationDuration = 0.2
        self.style = JASidePanelSingleActive
        self.bounceOnCenterPanelChange = false
        self.bounceOnSidePanelClose = false
        self.bounceOnSidePanelOpen = false

        // URL tapped notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(urlTapped(_:)),
            name: NSNotification.Name(rawValue: kNotificationURLTapped),
            object: nil
        )

        // World selected notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectedWorldDidChange(_:)),
            name: NSNotification.Name(rawValue: kNotificationWorldChanged),
            object: nil
        )

        // Setup KVO controller
        myKVOController = FBKVOController(observer: self)

        myKVOController?.observe(
            self,
            keyPath: "state",
            options: .new
        ) { [weak self] (container: Any?, state: Any?, change: [AnyHashable: Any]?) in
            guard let self = self,
                  let change = change,
                  let newStateValue = change[NSKeyValueChangeKey.newKey.rawValue] as? UInt32 else {
                return
            }

            let newState = JASidePanelState(rawValue: newStateValue)

            if newState == JASidePanelRightVisible {
                if let nav = self.centerPanel as? UINavigationController,
                   let client = nav.viewControllers.first as? SSClientViewController {
                    client.setNavVisible(true)
                }
            }
        }
    }

    // MARK: - Shared Instance

    @objc(sharedClientContainer)
    static func shared() -> SSClientContainer? {
        // Try to get the root view controller from the active scene (iOS 13+)
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene,
                   windowScene.activationState == .foregroundActive ||
                   windowScene.activationState == .foregroundInactive {
                    for window in windowScene.windows {
                        if window.isKeyWindow,
                           let rootVC = window.rootViewController as? SSClientContainer {
                            return rootVC
                        }
                    }
                }
            }
        }

        // Fall back to legacy window access for older iOS versions
        // Use KVC to avoid circular dependency with SSAppDelegate
        if let appDelegate = UIApplication.shared.delegate {
            let windowSelector = NSSelectorFromString("window")
            if appDelegate.responds(to: windowSelector),
               let window = appDelegate.perform(windowSelector)?.takeUnretainedValue() as? UIWindow,
               let rootVC = window.rootViewController as? SSClientContainer {
                return rootVC
            }
        }

        return nil
    }

    @objc(worldDisplayDrawer)
    static func worldDisplayDrawer() -> SSWorldDisplayController? {
        return shared()?.rightPanel as? SSWorldDisplayController
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLog("SSClientContainer viewDidLoad")
        self.view.backgroundColor = .black

        // Add drawer and initial client
        let displayController = SSWorldDisplayController()
        displayController.parentContainer = self
        self.rightPanel = displayController

        NSLog("About to add client with world:nil")
        displayController.addClient(withWorld: nil)
        NSLog("After addClientWithWorld. centerPanel: \(String(describing: self.centerPanel)), state: \(self.state.rawValue)")

        // Hide splash if necessary
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let splashDismissal = {
                IFTTTSplashView.sharedSplash().dismissSplash(
                    with: .growFade,
                    completion: nil
                )
            }

            if !UserDefaults.standard.bool(forKey: kPrefInitialSetupComplete) {
                let welcome = SSWelcomeViewController()
                if let nav = welcome.wrappedNavigationController() {
                    nav.modalPresentationStyle = .formSheet
                    nav.modalTransitionStyle = .coverVertical

                    self.present(nav, animated: false, completion: splashDismissal)
                }
            } else {
                splashDismissal()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    deinit {
        // Remove observers in a way that's compatible with Swift concurrency
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    @objc private func urlTapped(_ notification: Notification) {
        guard let url = notification.object as? URL else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if url.scheme == "mailto" {
                if MFMailComposeViewController.canSendMail() {
                    let mailViewController = MFMailComposeViewController()
                    let emailAddress = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                    mailViewController.setToRecipients([emailAddress])

                    // Set completion handler using delegate
                    mailViewController.mailComposeDelegate = self

                    self.present(mailViewController, animated: true) {
                        // MAIL HACK
                        UIApplication.shared.statusBarStyle = .lightContent
                    }
                }
            } else {
                if let webView = SPLHandoffWebViewController(url: url) {
                    SSClientContainer.worldDisplayDrawer()?.currentVisibleClient?.hideKeyboard()

                    SSClientContainer.worldDisplayDrawer()?.currentVisibleClient?.navigationController?
                        .pushViewController(webView, animated: true)
                }
            }
        }
    }

    @objc private func selectedWorldDidChange(_ notification: Notification) {
        guard let newWorld = notification.object as? NSManagedObjectID else {
            return
        }

        DispatchQueue.main.async {
            // Use perform to call Objective-C method
            guard let context = NSManagedObjectContext.perform(NSSelectorFromString("MR_defaultContext"))?.takeUnretainedValue() as? NSManagedObjectContext,
                  let world = World.existingObject(with: newWorld, in: context) else {
                return
            }

            guard let worldDisplayDrawer = SSClientContainer.worldDisplayDrawer() else {
                return
            }

            let currentClient = worldDisplayDrawer.selectedIndex

            let worldChangeBlock: () -> Void = {
                worldDisplayDrawer.client(at: currentClient)?.updateCurrentWorld(
                    newWorld,
                    connectAfterUpdate: true
                )
            }

            let client = worldDisplayDrawer.currentVisibleClient

            if client?.isConnected == true {
                let connectingMessage = String(
                    format: NSLocalizedString("CONNECTING_TO_%@", comment: ""),
                    world.worldDescription()
                )
                let disconnectMessage = String(
                    format: NSLocalizedString("DISCONNECT_FROM_%@", comment: "Disconnect from"),
                    client?.hostname ?? ""
                )

                SPLAlerts.splShowAlertView(
                    withTitle: connectingMessage,
                    message: disconnectMessage,
                    cancelTitle: NSLocalizedString("CANCEL", comment: "Cancel"),
                    cancel: nil,
                    okTitle: NSLocalizedString("CONNECT", comment: "Connect"),
                    okBlock: worldChangeBlock
                )
            } else {
                worldChangeBlock()
            }
        }
    }

    // MARK: - JASidePanel

    override func stylePanel(_ panel: UIView) {
        // Override if needed
    }

    @objc func closeDrawerAnimated(_ animated: Bool) {
        if self.state != JASidePanelCenterVisible {
            self.showCenterPanel(animated: animated)
        }
    }

    // MARK: - MFMailComposeViewControllerDelegate

    @objc nonisolated func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        DispatchQueue.main.async {
            controller.dismiss(animated: true, completion: nil)
        }
    }
}
