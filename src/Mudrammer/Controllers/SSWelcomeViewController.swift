//
//  SSWelcomeViewController.swift
//  MudMobile
//
//  Swift reimplementation of the welcome screen
//

import UIKit

@objc(SSWelcomeViewController)
@objcMembers
class SSWelcomeViewController: UIViewController {

    // MARK: - Properties

    private var label: UILabel!
    private var imageView: UIImageView!

    // MARK: - Initialization

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.title = NSLocalizedString("WELCOME", comment: "Welcome to MUDRammer")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.title = NSLocalizedString("WELCOME", comment: "Welcome to MUDRammer")
    }

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set background color from theme
        self.view.backgroundColor = SSThemes.sharedThemer().theme(at: 0)[kThemeBackgroundColor] as? UIColor

        // Configure navigation bar
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(tappedButton(_:))
        )

        // Set up image view
        imageView = UIImageView(image: SPLImagesCatalog.shieldImage())
        imageView.alpha = 0.2

        self.view.addSubview(imageView)
        imageView.mas_makeConstraints { make in
            make?.center.equalTo()(self.view)
        }

        // Set up welcome label
        label = UILabel()
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.numberOfLines = 0

        // Create shadow
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.darkGray
        shadow.shadowOffset = CGSize(width: 0, height: 1)

        // Set attributed text
        label.attributedText = NSAttributedString(
            string: NSLocalizedString("WELCOME_TEXT", comment: ""),
            attributes: [
                .foregroundColor: UIColor.white,
                .font: UIFont(name: kDefaultFontName, size: 20.0) ?? UIFont.systemFont(ofSize: 20.0),
                .shadow: shadow
            ]
        )

        self.view.addSubview(label)
        label.mas_makeConstraints { make in
            make?.center.equalTo()(self.view)
            make?.size.equalTo()(self.view)?.sizeOffset()(CGSize(width: -40, height: -20))
        }
    }

    // MARK: - Actions

    @objc private func tappedButton(_ sender: Any?) {
        // Save initial setup completion flag
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: kPrefInitialSetupComplete)
        defaults.synchronize() // Ensure the preference is saved immediately

        guard let container = SSClientContainer.shared() else {
            NSLog("ERROR: Unable to find SSClientContainer - welcome screen cannot be dismissed properly")
            return
        }

        container.dismiss(animated: true) {
            NSLog("Welcome screen dismissed. Center panel: \(String(describing: container.centerPanel))")
            NSLog("Container state: \(container.state.rawValue)")

            // Ensure the center panel is visible after dismissal
            // Force the center panel's view to load if it hasn't already
            if let centerPanel = container.centerPanel {
                NSLog("Center panel exists, forcing view load")
                centerPanel.view.setNeedsLayout()
                centerPanel.view.layoutIfNeeded()
            } else {
                NSLog("ERROR: Center panel is nil!")
            }

            NSLog("Calling showCenterPanelAnimated")
            container.showCenterPanel(animated: false)

            if let firstClient = SSClientContainer.worldDisplayDrawer()?.client(at: 0) {
                NSLog("First client: \(firstClient)")
                firstClient.connect()
            }
        }
    }
}
