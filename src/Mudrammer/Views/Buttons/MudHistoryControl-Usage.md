# MudHistoryControl - Swift Implementation

## Overview

This is a modern Swift reimplementation of `SSMudHistoryControl` with **smart prefix filtering**. When you type a prefix and press the up arrow, it searches backwards through history for commands that start with that prefix.

## Example: How It Works

Given this command history:
```
north
south
look
east
```

### Old Behavior (SSMudHistoryControl)
1. Type: `n`
2. Press Up Arrow
3. Result: Shows `east` (last command, ignoring what you typed)

### New Behavior (MudHistoryControl)
1. Type: `n`
2. Press Up Arrow
3. Result: Shows `north` (last command starting with "n")

## Usage

### Basic Setup

```swift
let historyControl = MudHistoryControl()
historyControl.delegate = self

// Add commands to history
historyControl.addCommand("north")
historyControl.addCommand("south")
historyControl.addCommand("look")
```

### Navigation Without Prefix (Traditional Mode)

```swift
// Move backwards (up arrow)
historyControl.moveHistory(.backwards)

// Move forwards (down arrow)
historyControl.moveHistory(.forwards)
```

### Navigation With Smart Prefix Filtering

```swift
// User has typed "n" in the text field
let currentInput = textField.text ?? ""

// Pass current input when moving backwards from end position
historyControl.moveHistory(.backwards, currentInput: currentInput)
// Result: Finds and shows "north"

// Continue navigating within filtered results
historyControl.moveHistory(.backwards)
// Result: Shows "northeast" (if it exists in history)

// Moving forward past the end clears the filter
historyControl.moveHistory(.forwards) // Shows empty string
historyControl.moveHistory(.backwards) // Now shows full history again
```

### Delegate Protocol

```swift
class MyViewController: UIViewController, MudHistoryControlDelegate {

    func mudHistoryControl(_ control: MudHistoryControl,
                          willChangeToCommand command: String) {
        // Update text field with the selected command
        textField.text = command
    }
}
```

## Integration with SSMUDToolbar

To integrate with the existing toolbar, you would update `SSMUDToolbar` to:

1. Replace `SSMudHistoryControl` with `MudHistoryControl`
2. Update the `growingTextViewPressedKeyCommand:` method:

```swift
// In SSMUDToolbar (converted to Swift, or via bridging header)
func growingTextViewPressedKeyCommand(_ direction: String) {
    let currentText = textView.text ?? ""

    if direction == UIKeyInputUpArrow {
        if historyControl.isAtStart {
            return
        }

        // Pass current input for smart filtering
        historyControl.moveHistory(.backwards, currentInput: currentText)

    } else if !historyControl.isAtEnd {
        historyControl.moveHistory(.forwards)
    }
}
```

## Key Features

### 1. Smart Prefix Filtering
- Automatically filters history based on what's typed
- Only activates when pressing up from the end position with text
- Filters cleared when navigating forward past the end

### 2. Case-Sensitive Matching
- `n` matches `north` but not `North`
- Maintains consistency with command systems

### 3. Duplicate Handling
- Avoids consecutive duplicates (like original)
- Allows non-consecutive duplicates

### 4. Boundary Protection
- Can't navigate before start
- Returns empty string when past end
- Proper state management

## Migration from SSMudHistoryControl

### Objective-C Compatibility

The Swift implementation is fully Objective-C compatible:

```objc
// Create instance
MudHistoryControl *historyControl = [[MudHistoryControl alloc] init];
historyControl.delegate = self;

// Add commands
[historyControl addCommand:@"north"];

// Navigate (without prefix)
[historyControl moveHistoryLegacy:HistoryNavigationDirectionBackwards];

// Navigate (with prefix) - requires bridging
NSString *currentInput = self.textView.text;
[historyControl moveHistory:HistoryNavigationDirectionBackwards
               currentInput:currentInput];
```

### Property Mapping

| Old (Objective-C) | New (Swift) |
|------------------|-------------|
| `isAtStart` | `isAtStart` |
| `isAtEnd` | `isAtEnd` |
| `addCommand:` | `addCommand(_:)` |
| `moveHistory:` | `moveHistory(_:currentInput:)` |
| `purgeCommandHistory` | `purgeCommandHistory()` |
| `enableSegments` | `enableSegments()` |

## Testing

The implementation includes comprehensive unit tests in `MudHistoryControlTests.swift`:

- Basic history addition and navigation
- Prefix filtering with various scenarios
- Boundary conditions
- Empty history handling
- Duplicate detection

To run tests:
```bash
xcodebuild test -workspace Mudrammer.xcworkspace \
  -scheme "MUDRammer Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Implementation Details

### State Management

- `commandHistory: [String]` - Full command list
- `filteredHistory: [String]` - Currently filtered results
- `currentFilteredIndex: Int` - Position in filtered list (-1 = at end)
- `searchPrefix: String?` - Active filter prefix (nil = no filter)

### Filter Lifecycle

1. **Activation**: Press up from end with non-empty input
2. **Active**: Navigate within filtered results
3. **Deactivation**: Navigate forward past end

### Algorithm

```swift
// On first up arrow with input "n":
filteredHistory = commandHistory.filter { $0.hasPrefix("n") }
// ["north", "northeast"]

currentFilteredIndex = filteredHistory.count
// Start at end of filtered list

// On moveHistory(.backwards):
currentFilteredIndex -= 1
// Show filteredHistory[index]
```

## Future Enhancements

Possible improvements:
- Case-insensitive option
- Fuzzy matching
- Substring search (not just prefix)
- History persistence
- Maximum history size
- Search highlighting in UI
