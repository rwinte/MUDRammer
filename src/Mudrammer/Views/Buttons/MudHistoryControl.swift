//
//  MudHistoryControl.swift
//  Mudrammer
//
//  Modern Swift implementation of command history with smart prefix filtering.
//  When you type a prefix and press up arrow, it searches backwards through
//  history for commands that start with that prefix.
//

import UIKit

/// Direction for navigating command history
@objc public enum HistoryNavigationDirection: Int {
    case backwards = 0
    case forwards = 1
}

/// Delegate protocol for history control callbacks
@objc public protocol MudHistoryControlDelegate: AnyObject {
    /// Called when the history control changes to a new command
    @objc optional func mudHistoryControl(_ control: MudHistoryControl, willChangeToCommand command: String)

    /// Called when the history control changes to a new command with text selection
    /// The selection range indicates which part of the text should be selected (for prefix filtering)
    @objc optional func mudHistoryControl(_ control: MudHistoryControl, willChangeToCommand command: String, withSelectionRange range: NSRange)

    /// Called when the history control needs to know the current input for smart filtering
    @objc optional func currentInputForHistoryControl(_ control: MudHistoryControl) -> String?

    /// Called when the history control needs to know the current selection range for smart filtering
    @objc optional func currentSelectionForHistoryControl(_ control: MudHistoryControl) -> NSRange
}

/// Smart command history control with prefix-based filtering
@objc public class MudHistoryControl: UISegmentedControl {

    // MARK: - Public Properties

    /// Delegate for history change callbacks
    @objc public weak var delegate: MudHistoryControlDelegate?

    /// Returns true if at the beginning of history (or filtered history)
    @objc public var isAtStart: Bool {
        return currentFilteredIndex <= 0
    }

    /// Returns true if at the end of history (not currently browsing)
    @objc public var isAtEnd: Bool {
        return currentFilteredIndex == -1 ||
               currentFilteredIndex >= filteredHistory.count
    }

    // MARK: - Private Properties

    /// Full command history (newest at end)
    private var commandHistory: [String] = []

    /// Currently filtered history based on search prefix
    private var filteredHistory: [String] = []

    /// Current index in the filtered history (-1 = at end/not browsing)
    private var currentFilteredIndex: Int = -1

    /// The prefix being used to filter history (nil = no filtering)
    private var searchPrefix: String?

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupControl()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupControl()
    }

    private func setupControl() {
        self.isMomentary = true
        self.contentMode = .center

        // Insert segments with images
        insertSegment(with: SPLImagesCatalog.historyUpImage(),
                     at: HistoryNavigationDirection.backwards.rawValue,
                     animated: false)
        insertSegment(with: SPLImagesCatalog.historyDownImage(),
                     at: HistoryNavigationDirection.forwards.rawValue,
                     animated: false)

        addTarget(self,
                 action: #selector(segmentPressed(_:)),
                 for: .valueChanged)

        sizeToFit()
        updateSegmentStates()

        // Set up accessibility
        if subviews.count >= 2 {
            subviews[0].accessibilityLabel = NSLocalizedString("HISTORY_BACK", comment: "")
            subviews[0].accessibilityHint = "Moves one step back in command history."

            subviews[1].accessibilityLabel = NSLocalizedString("HISTORY_FORWARD", comment: "")
            subviews[1].accessibilityHint = "Moves one step forward in command history."
        }
    }

    public override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.15
        }
    }

    // MARK: - Public Methods

    /// Add a command to history
    /// - Parameter command: The command to add (empty commands are ignored)
    @objc public func addCommand(_ command: String) {
        guard !command.isEmpty else { return }

        // Avoid consecutive duplicates
        if commandHistory.last != command {
            commandHistory.append(command)
            NSLog("📝 Added command to history: '\(command)' - total history count: \(commandHistory.count)")
        } else {
            NSLog("⏭️ Skipped duplicate command: '\(command)'")
        }

        // Reset to end state
        resetToEnd()
    }

    /// Navigate history in the specified direction with optional prefix filtering
    /// - Parameters:
    ///   - direction: The direction to navigate
    ///   - currentInput: The current text input (used for prefix filtering on first up press)
    @objc public func moveHistory(_ direction: HistoryNavigationDirection,
                                   currentInput: String? = nil) {
        NSLog("🔍 moveHistory called: direction=\(direction == .backwards ? "backwards" : "forwards"), currentInput='\(currentInput ?? "nil")', isAtEnd=\(isAtEnd)")
        NSLog("🔍 commandHistory: \(commandHistory)")
        NSLog("🔍 filteredHistory: \(filteredHistory)")
        NSLog("🔍 currentFilteredIndex: \(currentFilteredIndex)")
        NSLog("🔍 searchPrefix: '\(searchPrefix ?? "nil")'")

        let trimmedInput = currentInput?.trimmingCharacters(in: .whitespaces) ?? ""

        // Check if the prefix has changed
        if trimmedInput != (searchPrefix ?? "") {
            NSLog("🔄 Prefix changed from '\(searchPrefix ?? "")' to '\(trimmedInput)' - resetting index to 0")

            // Reset to index 0 when prefix changes
            currentFilteredIndex = 0

            // Update the filter
            if trimmedInput.isEmpty {
                // No prefix - show full history
                searchPrefix = nil
                filteredHistory = commandHistory
            } else {
                // New prefix - start filtering
                searchPrefix = trimmedInput
                filteredHistory = commandHistory.filter { $0.hasPrefix(trimmedInput) }
                NSLog("🔍 Filtered to \(filteredHistory.count) commands matching '\(trimmedInput)': \(filteredHistory)")
            }
        }

        // Now navigate in the specified direction
        navigateInDirection(direction)
    }

    /// Purge all command history
    @objc public func purgeCommandHistory() {
        commandHistory.removeAll()
        resetToEnd()
    }

    /// Update the enabled state of the segment buttons
    @objc public func enableSegments() {
        updateSegmentStates()
    }

    // MARK: - Private Methods

    /// Start a prefix-based search through history
    private func startPrefixSearch(prefix: String) {
        searchPrefix = prefix

        // Filter history to commands starting with the prefix
        filteredHistory = commandHistory.filter { $0.hasPrefix(prefix) }

        NSLog("🔍 Prefix search started - prefix: '\(prefix)', filtered count: \(filteredHistory.count), results: \(filteredHistory)")

        // Position at the most recent match (last item in filtered array)
        if filteredHistory.isEmpty {
            currentFilteredIndex = 0
        } else {
            currentFilteredIndex = filteredHistory.count - 1
        }
    }

    /// Reset to the end state (not browsing history)
    private func resetToEnd() {
        searchPrefix = nil
        filteredHistory = commandHistory
        currentFilteredIndex = commandHistory.count
        updateSegmentStates()
    }

    /// Clear the search filter and show full history
    private func clearFilter() {
        searchPrefix = nil
        filteredHistory = commandHistory

        // Try to maintain relative position if possible
        if currentFilteredIndex >= filteredHistory.count {
            currentFilteredIndex = filteredHistory.count
        }
    }

    /// Handle segment control press (when user taps the on-screen buttons)
    @objc private func segmentPressed(_ sender: Any?) {
        guard let direction = HistoryNavigationDirection(rawValue: selectedSegmentIndex) else {
            return
        }

        // Get current input from delegate for smart filtering
        guard let currentText = delegate?.currentInputForHistoryControl?(self) else {
            NSLog("🔘 segmentPressed: no delegate or no text")
            return
        }

        // Check if there's a selection to determine the actual prefix
        let prefixText: String
        if let selection = delegate?.currentSelectionForHistoryControl?(self),
           selection.length > 0 && selection.location < currentText.count {
            // If text is selected, only use the unselected portion as prefix
            prefixText = String(currentText.prefix(selection.location))
            NSLog("🔘 segmentPressed: direction=\(direction == .backwards ? "backwards" : "forwards"), fullText='\(currentText)', selection=(\(selection.location), \(selection.length)), prefix='\(prefixText)'")
        } else {
            // No selection, use full text as prefix
            prefixText = currentText
            NSLog("🔘 segmentPressed: direction=\(direction == .backwards ? "backwards" : "forwards"), text='\(currentText)' (no selection)")
        }

        // Use moveHistory to get smart filtering behavior
        moveHistory(direction, currentInput: prefixText)
    }

    /// Show the current command without navigating
    private func showCurrentCommand() {
        let command: String
        if currentFilteredIndex >= filteredHistory.count || filteredHistory.isEmpty {
            command = ""
        } else {
            command = filteredHistory[currentFilteredIndex]
        }

        NSLog("📍 Showing command at index \(currentFilteredIndex): '\(command)'")

        // Calculate selection range based on whether we have a prefix search
        let selectionRange = calculateSelectionRange(for: command)

        // Notify delegate - prefer new method with selection range
        if delegate?.mudHistoryControl?(self, willChangeToCommand: command, withSelectionRange: selectionRange) != nil {
            // New method was called
        } else {
            // Fall back to legacy method
            delegate?.mudHistoryControl?(self, willChangeToCommand: command)
        }

        updateSegmentStates()
    }

    /// Internal navigation helper that actually moves through history
    private func navigateInDirection(_ direction: HistoryNavigationDirection) {
        NSLog("📍 navigateInDirection: \(direction == .backwards ? "backwards" : "forwards")")

        // Update index based on direction
        switch direction {
        case .backwards:
            currentFilteredIndex -= 1
        case .forwards:
            currentFilteredIndex += 1
        }

        // Wrap around at boundaries
        if currentFilteredIndex < 0 {
            NSLog("📍 Wrapped to end of history")
            currentFilteredIndex = max(0, filteredHistory.count - 1)
        } else if currentFilteredIndex >= filteredHistory.count {
            NSLog("📍 Wrapped to beginning of history")
            currentFilteredIndex = 0
        }

        // Determine which command to show
        let command: String
        if filteredHistory.isEmpty || currentFilteredIndex >= filteredHistory.count {
            command = ""
        } else {
            command = filteredHistory[currentFilteredIndex]
        }

        NSLog("📍 Navigated to index \(currentFilteredIndex), command: '\(command)'")

        // Calculate selection range based on whether we have a prefix search
        let selectionRange = calculateSelectionRange(for: command)

        // Notify delegate - prefer new method with selection range
        if delegate?.mudHistoryControl?(self, willChangeToCommand: command, withSelectionRange: selectionRange) != nil {
            // New method was called
        } else {
            // Fall back to legacy method
            delegate?.mudHistoryControl?(self, willChangeToCommand: command)
        }

        updateSegmentStates()
    }

    /// Update the enabled state of navigation buttons
    private func updateSegmentStates() {
        // Always keep both buttons enabled
        setEnabled(true,
                  forSegmentAt: HistoryNavigationDirection.backwards.rawValue)
        setEnabled(true,
                  forSegmentAt: HistoryNavigationDirection.forwards.rawValue)
    }

    /// Calculate the selection range for a command
    /// - Parameter command: The command to calculate selection for
    /// - Returns: NSRange indicating which part should be selected
    /// - Note: If there's a prefix search, selects everything after the prefix.
    ///         If there's no prefix (empty input or no search), selects the entire command.
    private func calculateSelectionRange(for command: String) -> NSRange {
        guard !command.isEmpty else {
            return NSRange(location: 0, length: 0)
        }

        // If we have a prefix search active, select the part after the prefix
        if let prefix = searchPrefix, !prefix.isEmpty, command.hasPrefix(prefix) {
            let prefixLength = prefix.count
            let remainingLength = command.count - prefixLength
            NSLog("🎯 Prefix '\(prefix)' found, selecting range (\(prefixLength), \(remainingLength))")
            return NSRange(location: prefixLength, length: remainingLength)
        }

        // No prefix search - select the entire command (Mudlet behavior)
        NSLog("🎯 No prefix, selecting entire command (0, \(command.count))")
        return NSRange(location: 0, length: command.count)
    }
}

// MARK: - Objective-C Compatibility Extensions

extension MudHistoryControl {

    /// Legacy method for compatibility - moves history without considering current input
    @objc public func moveHistoryLegacy(_ direction: HistoryNavigationDirection) {
        moveHistory(direction, currentInput: nil)
    }
}
