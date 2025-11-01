//
//  MudHistoryControlTests.swift
//  Mudrammer
//
//  Unit tests for MudHistoryControl to verify smart prefix filtering
//

import XCTest
@testable import Mudrammer

class MudHistoryControlTests: XCTestCase {

    var historyControl: MudHistoryControl!

    override func setUp() {
        super.setUp()
        historyControl = MudHistoryControl()
    }

    override func tearDown() {
        historyControl = nil
        super.tearDown()
    }

    // MARK: - Basic History Tests

    func testAddCommand() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")

        XCTAssertTrue(historyControl.isAtEnd, "Should be at end after adding commands")
    }

    func testIgnoreEmptyCommands() {
        historyControl.addCommand("")
        historyControl.addCommand("north")
        historyControl.addCommand("")

        XCTAssertTrue(historyControl.isAtEnd)
    }

    func testAvoidConsecutiveDuplicates() {
        historyControl.addCommand("north")
        historyControl.addCommand("north")
        historyControl.addCommand("south")

        // Should only have 2 commands: "north" and "south"
        XCTAssertTrue(historyControl.isAtEnd)
    }

    func testAllowNonConsecutiveDuplicates() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")
        historyControl.addCommand("north")

        // Should have all 3 commands
        XCTAssertTrue(historyControl.isAtEnd)
    }

    // MARK: - Navigation Tests

    func testBasicBackwardNavigation() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")
        historyControl.addCommand("look")
        historyControl.addCommand("east")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Move back once
        historyControl.moveHistory(.backwards)
        XCTAssertEqual(receivedCommands.last, "east", "Should get most recent command")

        // Move back again
        historyControl.moveHistory(.backwards)
        XCTAssertEqual(receivedCommands.last, "look", "Should get previous command")
    }

    func testBasicForwardNavigation() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Go back twice
        historyControl.moveHistory(.backwards)
        historyControl.moveHistory(.backwards)

        // Go forward once
        historyControl.moveHistory(.forwards)
        XCTAssertEqual(receivedCommands.last, "south")
    }

    func testNavigatePastEnd() {
        historyControl.addCommand("north")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Go back
        historyControl.moveHistory(.backwards)

        // Go forward past end
        historyControl.moveHistory(.forwards)
        XCTAssertEqual(receivedCommands.last, "", "Should return empty string past end")
        XCTAssertTrue(historyControl.isAtEnd)
    }

    // MARK: - Prefix Filtering Tests

    func testPrefixFilteringBasic() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")
        historyControl.addCommand("look")
        historyControl.addCommand("east")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Start prefix search with "n"
        historyControl.moveHistory(.backwards, currentInput: "n")

        // Should get "north" (the only command starting with "n")
        XCTAssertEqual(receivedCommands.last, "north",
                      "Should find 'north' when searching with prefix 'n'")
    }

    func testPrefixFilteringMultipleMatches() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")
        historyControl.addCommand("northeast")
        historyControl.addCommand("east")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Start prefix search with "n"
        historyControl.moveHistory(.backwards, currentInput: "n")

        // Should get most recent match: "northeast"
        XCTAssertEqual(receivedCommands.last, "northeast",
                      "Should find most recent command starting with 'n'")

        // Move back again within filtered results
        historyControl.moveHistory(.backwards)

        // Should get previous match: "north"
        XCTAssertEqual(receivedCommands.last, "north",
                      "Should find next oldest command starting with 'n'")
    }

    func testPrefixFilteringNoMatches() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")
        historyControl.addCommand("east")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Start prefix search with "x" (no matches)
        historyControl.moveHistory(.backwards, currentInput: "x")

        // Should get empty string when no matches found
        XCTAssertEqual(receivedCommands.last, "",
                      "Should return empty string when no commands match prefix")
    }

    func testPrefixFilteringExactMatch() {
        historyControl.addCommand("north")
        historyControl.addCommand("n")
        historyControl.addCommand("south")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Start prefix search with "n"
        historyControl.moveHistory(.backwards, currentInput: "n")

        // Should get most recent match
        XCTAssertEqual(receivedCommands.last, "n")

        // Move back to get "north"
        historyControl.moveHistory(.backwards)
        XCTAssertEqual(receivedCommands.last, "north")
    }

    func testPrefixFilteringClearsOnForwardPastEnd() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")
        historyControl.addCommand("northeast")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Start prefix search with "n"
        historyControl.moveHistory(.backwards, currentInput: "n")
        XCTAssertEqual(receivedCommands.last, "northeast")

        // Move forward past end (should clear filter)
        historyControl.moveHistory(.forwards)
        XCTAssertEqual(receivedCommands.last, "")

        // Now moving backwards without prefix should get full history
        historyControl.moveHistory(.backwards)
        // Most recent command should be "northeast" (last in full history)
        XCTAssertEqual(receivedCommands.last, "northeast")
    }

    func testPrefixFilteringCaseSensitive() {
        historyControl.addCommand("North")
        historyControl.addCommand("south")

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Start prefix search with lowercase "n"
        historyControl.moveHistory(.backwards, currentInput: "n")

        // Should not match "North" (case sensitive)
        XCTAssertEqual(receivedCommands.last, "",
                      "Prefix search should be case sensitive")
    }

    // MARK: - Boundary Tests

    func testIsAtStartWhenEmpty() {
        XCTAssertFalse(historyControl.isAtStart, "Should not be at start when history is empty")
    }

    func testIsAtEndInitially() {
        historyControl.addCommand("north")
        XCTAssertTrue(historyControl.isAtEnd, "Should be at end initially")
    }

    func testCannotGoBackPastStart() {
        historyControl.addCommand("north")

        var callCount = 0
        let delegate = MockDelegate { _, _ in
            callCount += 1
        }
        historyControl.delegate = delegate

        // Go to start
        historyControl.moveHistory(.backwards)

        // Try to go back again
        historyControl.moveHistory(.backwards)

        // Should have stayed at start (index 0), calling delegate both times
        XCTAssertEqual(callCount, 2)
        XCTAssertTrue(historyControl.isAtStart)
    }

    func testPurgeHistory() {
        historyControl.addCommand("north")
        historyControl.addCommand("south")

        historyControl.purgeCommandHistory()

        XCTAssertTrue(historyControl.isAtEnd)

        var receivedCommands: [String] = []
        let delegate = MockDelegate { _, command in
            receivedCommands.append(command)
        }
        historyControl.delegate = delegate

        // Try to navigate - should get empty string
        historyControl.moveHistory(.backwards)
        XCTAssertEqual(receivedCommands.last, "")
    }
}

// MARK: - Mock Delegate

class MockDelegate: NSObject, MudHistoryControlDelegate {
    private let callback: (MudHistoryControl, String) -> Void

    init(callback: @escaping (MudHistoryControl, String) -> Void) {
        self.callback = callback
    }

    func mudHistoryControl(_ control: MudHistoryControl, willChangeToCommand command: String) {
        callback(control, command)
    }
}
