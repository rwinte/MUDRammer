//
//  SPLMoveControlEditor.swift
//  MudMobile
//
//  Editor for the move control.
//

import UIKit

enum SPLMoveControlEditorSection: Int {
    case enable = 0
    case commands

    static var count: Int { return 2 }
}

@objc(SPLMoveControlEditor)
@objcMembers
class SPLMoveControlEditor: UITableViewController {

    // MARK: - Constants

    private let kMaxMoveCommands = 8

    // MARK: - Properties

    private var dataSource: SSSectionedDataSource!
    private var insertButton: UIBarButtonItem!

    // MARK: - Initialization

    override init(style: UITableView.Style) {
        super.init(style: style)
        setupDataSource()
    }

    convenience init() {
        self.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDataSource()
    }

    // MARK: - Setup

    private func setupDataSource() {
        insertButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addCommandRow(_:))
        )

        dataSource = SSSectionedDataSource(
            section: SSSection(
                numberOfItems: 1,
                header: nil as String?,
                footer: NSLocalizedString("MOVE_ENABLE_HELP", comment: "") as String?,
                identifier: nil as String?
            )
        )

        dataSource.rowAnimation = UITableView.RowAnimation.fade
        dataSource.shouldRemoveEmptySections = false

        // Cell creation block
        dataSource.cellCreationBlock = { (value: Any?, tableView: Any?, indexPath: IndexPath?) -> Any? in
            guard let indexPath = indexPath,
                  let tableView = tableView as? UITableView,
                  let section = SPLMoveControlEditorSection(rawValue: indexPath.section) else {
                return nil
            }

            switch section {
            case .enable:
                return SSSegmentCell(for: tableView)
            case .commands:
                return SSTextEntryCell(for: tableView)
            }
        }

        // Cell configuration block
        dataSource.cellConfigureBlock = { [weak self] (cell: Any?, value: Any?, tableView: Any?, indexPath: IndexPath?) in
            guard let self = self,
                  let indexPath = indexPath,
                  let section = SPLMoveControlEditorSection(rawValue: indexPath.section) else {
                return
            }

            switch section {
            case .enable:
                if let segmentCell = cell as? SSSegmentCell {
                    SSThemes.configureCell(segmentCell)

                    let selectedIndex = UserDefaults.standard.integer(forKey: kPrefMoveControl)

                    segmentCell.configure(
                        withLabel: NSLocalizedString("MOVE_CONTROL", comment: ""),
                        segments: [
                            NSLocalizedString("LEFT", comment: ""),
                            NSLocalizedString("OFF", comment: ""),
                            NSLocalizedString("RIGHT", comment: "")
                        ],
                        selectedIndex: selectedIndex
                    ) { [weak self] (index: Int) in
                        self?.changeMoveControlPref(to: index)
                    }
                }

            case .commands:
                if let textCell = cell as? SSTextEntryCell,
                   let text = value as? String {
                    textCell.textField.text = text

                    textCell.changeHandler = { [weak self] (textField: UITextField?) in
                        guard let self = self, let textField = textField else { return }

                        if textField.isFirstResponder {
                            textField.resignFirstResponder()
                        }

                        let text = textField.text ?? ""

                        if text.isEmpty {
                            if indexPath.row < self.dataSource.numberOfItems(inSection: indexPath.section) {
                                self.dataSource.removeItem(at: indexPath)
                            }
                        } else {
                            if let section = self.dataSource.section(at: SPLMoveControlEditorSection.commands.rawValue),
                               indexPath.row < section.items.count {
                                section.items[indexPath.row] = text
                            }
                        }

                        self.saveChangesToDefaults()
                    }
                }
            }
        }

        // Table action block (for editing)
        dataSource.tableActionBlock = { (action: SSCellActionType, tableView: UITableView?, indexPath: IndexPath?) -> Bool in
            guard let indexPath = indexPath,
                  let section = SPLMoveControlEditorSection(rawValue: indexPath.section) else {
                return false
            }

            switch section {
            case .enable:
                return false
            case .commands:
                return true
            }
        }

        // Table deletion block
        dataSource.tableDeletionBlock = { [weak self] (dataSource: Any?, tableView: UITableView?, indexPath: IndexPath?) in
            guard let self = self,
                  let dataSource = dataSource as? SSSectionedDataSource,
                  let indexPath = indexPath else { return }
            dataSource.removeItem(at: indexPath)
            self.saveChangesToDefaults()
        }

        // Observe preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    // MARK: - View Lifecycle

    override var preferredContentSize: CGSize {
        get { return CGSize(width: 320, height: 500) }
        set { super.preferredContentSize = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = 44.0
        SSThemes.configureTable(tableView)

        let isEnabled = SSRadialControl.radialControlIsEnabled(kPrefMoveControl)
        setCommandSection(visible: isEnabled)

        dataSource.tableView = tableView

        if isEnabled {
            navigationItem.rightBarButtonItems = [
                insertButton,
                UIBarButtonItem(
                    barButtonSystemItem: .edit,
                    target: self,
                    action: #selector(toggleEditing(_:))
                )
            ]
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveChangesToDefaults()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

    @objc private func toggleEditing(_ sender: Any?) {
        let isEditing = !tableView.isEditing

        tableView.setEditing(isEditing, animated: true)

        var rightItems: [UIBarButtonItem] = []

        if !isEditing {
            rightItems.append(insertButton)
        }

        rightItems.append(
            UIBarButtonItem(
                barButtonSystemItem: isEditing ? .done : .edit,
                target: self,
                action: #selector(toggleEditing(_:))
            )
        )

        navigationItem.rightBarButtonItems = rightItems
    }

    private func setCommandSection(visible: Bool) {
        if visible && dataSource.numberOfSections() == SPLMoveControlEditorSection.count {
            return
        }

        if !visible && dataSource.numberOfSections() == SPLMoveControlEditorSection.count - 1 {
            return
        }

        if visible {
            let commands = UserDefaults.standard.array(forKey: kPrefMoveCommands) as? [String] ?? []
            dataSource.appendSection(
                SSSection(
                    items: commands as [Any],
                    header: NSLocalizedString("MOVE_COMMANDS", comment: "") as String?,
                    footer: NSLocalizedString("MOVE_EXTRA_HELP", comment: "") as String?,
                    identifier: nil as String?
                )
            )
        } else if dataSource.numberOfSections() > 1 {
            dataSource.removeSection(at: SPLMoveControlEditorSection.commands.rawValue)
        }
    }

    @objc private func addCommandRow(_ sender: UIBarButtonItem) {
        if dataSource.numberOfItems(inSection: SPLMoveControlEditorSection.commands.rawValue) >= kMaxMoveCommands {
            return
        }

        if let section = dataSource.section(at: SPLMoveControlEditorSection.commands.rawValue),
           section.items.contains(where: { ($0 as? String) == "" }) {
            return
        }

        let newIndex = IndexPath(row: 0, section: SPLMoveControlEditorSection.commands.rawValue)

        dataSource.insertItem("", at: newIndex)

        for cell in tableView.visibleCells {
            if let indexPath = tableView.indexPath(for: cell),
               indexPath == newIndex,
               let textCell = cell as? SSTextEntryCell {
                textCell.textField.becomeFirstResponder()
                break
            }
        }
    }

    private func changeMoveControlPref(to index: Int) {
        if tableView.isEditing {
            toggleEditing(nil)
        }

        if index == SSRadialControlPosition.off.rawValue {
            navigationItem.rightBarButtonItems = nil
        } else {
            navigationItem.rightBarButtonItems = [
                insertButton,
                UIBarButtonItem(
                    barButtonSystemItem: .edit,
                    target: self,
                    action: #selector(toggleEditing(_:))
                )
            ]
        }

        NotificationCenter.default.removeObserver(
            self,
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        SSRadialControl.updateRadialPreference(
            kPrefMoveControl,
            to: SSRadialControlPosition(rawValue: index) ?? .right
        )

        setCommandSection(visible: index != SSRadialControlPosition.off.rawValue)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    // MARK: - User Defaults

    @objc private func userDefaultsDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.endEditing(true)
            self?.tableView.reloadData()
        }
    }

    private func saveChangesToDefaults() {
        if dataSource.numberOfSections() == 1 {
            return
        }

        NotificationCenter.default.removeObserver(
            self,
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        if let commandSection = dataSource.section(at: SPLMoveControlEditorSection.commands.rawValue) {
            UserDefaults.standard.set(commandSection.items, forKey: kPrefMoveCommands)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        insertButton.isEnabled = !(dataSource.numberOfItems(inSection: SPLMoveControlEditorSection.commands.rawValue) >= kMaxMoveCommands)
    }

    // MARK: - UITableViewDelegate

    override func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        if proposedDestinationIndexPath.section != SPLMoveControlEditorSection.commands.rawValue {
            return IndexPath(row: 0, section: SPLMoveControlEditorSection.commands.rawValue)
        }

        return proposedDestinationIndexPath
    }
}

