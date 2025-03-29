Below is a markdown document where each test is in its own markdown block. You can easily copy and paste each block as needed:

---

# AutoHotkey v2 Test Suite

This document contains a collection of test specifications for various AutoHotkey v2 projects. Each test is provided in its own markdown code block for ease of copying and pasting.

---

## Test 1: Clipboard Text Editor

```
Create a clipboard text editor that:
- Opens the GUI when the script starts
- Shows the clipboard contents when the GUI opens in an edit box without the text selected
- Create three buttons to change the case of the text 
- Save the newly edited version to the users clipboard
```

---

## Test 2: Snippet Manager Tool

```
Create an AutoHotkey v2 script for a Snippet Manager tool with the following features:
- Store a collection of predefined text snippets (like greetings, closings, reminders)
- Display them in a listbox GUI
- Allow copying the selected snippet to clipboard
- Option to send the snippet directly to the previous active window
- Show temporary tooltips for user feedback

Additional Requirements:
- Store snippets in a static Map
- Track the previously active window
- Have a clean, resizable GUI
- Display tooltips that automatically disappear

Include these specific snippets: "Greeting", "Closing", "Reminder", and "Follow-up" with appropriate text content for each.
Make sure to follow AutoHotkey v2 best practices with proper event binding, control management, and variable scoping.
```

---

## Test 3: Invoice Manager GUI

```
Create invoice manager GUI that:
- Has a list view with 5 columns: invoice number, date, tax, without tax, with tax
- Add 3 random buttons to the side of that list view
- Make 2 text labels for the complete amount of tax paid and everything paid together
```

---

## Test 4: GUI-Based Hotkey Assignment Tool

```
Create a GUI based hotkey assignment tool:
- Has 3 hotkey controls for selecting a hotkey
- Has 5 options in a drop down to assign functions to the hotkeys
- Show the results of the button actions in a msgbox

Hotkey Options:
- Upper case selected text
- Lower case selected text
- Proper Case selected text
- Surround selected text in "({"" Text "})"
- Surround selected text in ""
```

---

## Test 5: Store Timers GUI App

```
Create a GUI app that can create and store timers:
- Multiple countdown timers selectable from a dropdown
- Start/Pause/Reset buttons per timer
- Timer name and notes field
- Visual progress circle
- Sound notification options
- System tray minimize option
```

---

## Test 6: To-Do List Manager GUI

```
Create a GUI To-Do List Manager:
- A list view with two columns: "Task" and "Due Date"
- An edit control to type a new task
- A date picker or second edit control for the due date
- Include a button "Add Task" to insert the new task into the list view
- Include a button "Remove Selected Task" to remove the currently selected task from the list
- Display a message box when a task is added or removed confirming the action
```

---

## Test 7: Simple Note Manager GUI

```
Create a GUI that is a simple note manager:
- Has a large edit control for entering text notes
- A "Load File" button to select a text file and load its contents into the edit control
- A "Save File" button to save the edit control’s contents back into a selected file
- A search box plus a "Search" button that highlights the matching text in the edit control or displays a message box if none is found
```

---

## Test 8: Settings Manager GUI

```
Create a settings manager GUI that:
- Uses a TabControl for different setting categories
- Shows settings in a hierarchical TreeView
- Has different control types based on setting type (checkbox/dropdown/edit)
```

---

## Test 9: Link Manager GUI

```
Create a link manager GUI with the following features:

Link Storage and Management:
- Allow users to maintain a list of web links
- Provide functionality to scroll through the list, with active highlighting of the currently selected link

Open Links in Browser:
- When the user presses the Enter key, the selected link should be sent to the most recent instance of Microsoft Edge, opening the link in a new browser tab

Editing Links:
- Include an "Edit" button in the GUI that, when clicked, opens an .ini configuration file containing the list of links
- Ensure any updates to this .ini file are automatically reflected in the application upon save and reload

Interface Requirements:
- Use a user-friendly, minimalistic design
- Ensure smooth scrolling and intuitive keyboard/mouse interactions

Technical Details:
- Use AHK v2 (or a language like AHK v2 with appropriate libraries) for the GUI
- Write modular, well-commented code for readability and future enhancements
- Provide error handling for invalid URLs, inaccessible .ini files, and browser interaction issues
- Ensure the application is platform-independent, with special handling for Windows for Microsoft Edge integration
```

---

## Test 10: Popup Button List GUI

```
Create a popup button list GUI that:
- Toggles on keypress
- Contains 5 buttons
- Each button has an event that runs a function:
  - 3 functions can change the highlighted/selected text
  - 1 button makes a list of all 7-digit numbers in the text on the clipboard, separated by commas and a carriage return, and puts it back on the clipboard
  - 1 button finds the first 7-digit number on the clipboard, strips out all white space and other characters, and places it back on the clipboard
```

---

## Test 11: Refactor GuiFormat Function (OOP Approach)

```
Refactor the following GuiFormat function to follow an object-oriented approach for building GUIs in AHK v2. The goal is to encapsulate GUI parameters—such as position (x, y), dimensions (w, h), background color, and text color—into a class or a structured object. This should allow for easier, cleaner variable passing and more maintainable code. In addition, the refactored code should support adding extra parameters when needed.

Current Implementation:

GuiFormat(x, y, w, h, extraParams := "") {
  params := Format("x{} y{} w{} h{} Background{:X} c{:X}",
    x, y, w, h, Theme.Colors.Controls, Theme.Colors.Text)
  return extraParams ? params " " extraParams : params
}

Requirements for the new version:
- Object-Oriented Design: Create a GUI builder class (or similar structure) that holds GUI properties as object members.
- Cleaner Variable Passing: Instead of passing multiple parameters to a function, allow setting properties via object initialization or a fluent interface.
- Maintainability: Ensure that the code is clear and modular, making it easier to extend with additional GUI properties if needed.
- Flexibility: Continue to support extra parameters dynamically.
```

---

## Test 12: Key Test Questions for AHK v2 Coding Agent

```
Core Competency Tests:
- Create a class that manages window positions using WinMove and stores window coordinates in a Map. Include error handling for invalid window handles.
- Design a hotkey system that can toggle between different sets of hotkeys and display their current state in a tooltip.
- Build a file monitoring system using FileRead/FileWrite that tracks changes to multiple files and logs modifications.

Advanced Tests:
- Create a class implementing custom __Get/__Set methods to validate property assignments. Store validated data in a Map.
- Design a GUI-based timer class using SetTimer that supports multiple concurrent timers with pause/resume functionality.

Error Handling Tests:
- Implement proper error handling for file operations using try/catch blocks and custom error messages stored in a static Map.

Integration Tests:
- Create a system that combines GUI controls, file operations, and clipboard monitoring while maintaining proper object scope.
- Multi-Timer Manager (see Test 13 for detailed requirements)
```

---

## Test 13: Multi-Timer Manager GUI

```
AHK v2 GUI Script: Multi-Timer Manager

Objective:
Create a script that generates a GUI application for managing multiple countdown timers. The application should support adding new timers, setting countdown durations, starting, pausing, and resetting individual timers. Additionally, it should allow users to add notes for each timer and minimize the application to the system tray.

Requirements:
GUI Elements:
- A main window displaying a list of active timers.
- Buttons for adding a new timer, starting, pausing, and resetting each timer.
- Input fields for entering a countdown duration and a custom note per timer.
- A label to show remaining time.
- System tray integration with restore and exit options.

Timer Functionality:
- Each timer should run independently.
- Timers should support pausing and resuming.
- Timers should trigger a notification when they reach zero.
- A reset option should restart the timer to the original set time.

System Tray Integration:
- Minimize the GUI to the system tray.
- Restore the GUI when clicking on the tray icon.
- Right-click tray menu with Restore and Exit options.

Performance & Optimization:
- Efficient use of timers to minimize CPU usage.
- Compact and user-friendly interface.
- AutoHotkey v2 syntax compliance.
```

---

## Test 14: Text Manager

```
Text Manager

Write an AutoHotkey v2 script that creates a simple and user-friendly GUI window for managing and inserting predefined comment snippets. The script should meet the following requirements:

GUI Layout & Components:
- A listbox to display snippet names, sourced from an associative array (Map) where keys are snippet names and values are the corresponding comment texts.
- A button labeled ‘Insert Snippet’ that, when clicked, copies the selected snippet’s text to the clipboard.
- A checkbox option (‘Send to Active Window’), allowing users to automatically send the snippet text to the currently focused application.

Functionality:
- Selecting an item from the listbox and clicking ‘Insert Snippet’ should copy the corresponding comment text to the clipboard.
- If the checkbox is enabled, the script should send the copied text directly into the active window.
- Display a tooltip notification or similar feedback when the snippet is copied.
- The GUI should be resizable and easily extensible, allowing for additional snippets to be added in the future.

Performance Considerations:
- Ensure that the script runs efficiently and does not introduce unnecessary delays.
- Implement error handling for cases where no snippet is selected.
- Use well-structured and commented code to make future modifications easy.
- Utilize AutoHotkey v2 best practices to ensure compatibility and efficiency.
```

---

## Test 15: AutoHotkey Clipboard Analyzer

```
AutoHotkey Clipboard Analyzer Prompt

Create an OOP-based AutoHotkey v2 script that:
- Monitors clipboard changes in real-time
- Analyzes clipboard content and identifies if it's one of:
  - Email address
  - URL
  - File path
  - Phone number
  - 7-digit number
- Displays a tooltip showing the detected type
- Includes a test GUI with 5 single-line edit boxes containing examples of each type

Requirements:
- Use proper AHK v2 OOP patterns with classes
- Implement a reliable clipboard monitoring system
- Use regex for accurate content type detection
- Include a clean test GUI for copying example content
- Follow AHK v2 coding standards (no object literals for data storage)

Class Structure:
- Main ClipboardAnalyzer class to handle clipboard monitoring
- Content detector methods for each content type
- Tooltip display functionality
- Test GUI implementation with examples

For clipboard monitoring, consider using the OnClipboardChange event handler.
```

---

## Test 16: Clipboard Manager Tool

```
Clipboard Manager Tool

Create a clipboard manager script using AutoHotkey v2 that allows you to collect and monitor clipboard content.

Core Functionality:
- Create a clipboard monitoring tool that captures clipboard changes
- Display collected clipboard entries in a simple GUI
- Allow toggling the collection on/off with a hotkey (F6)
- Save collected content back to clipboard when closing

GUI Requirements:
- Use a minimalist dark theme with dark background and light text
- Make the window resizable and always on top
- Position the window near the cursor when opened
- Use a regular Edit control with multi-line capabilities
- Include proper dark mode styling for Windows 10+

Specific Features:
- Show the window at cursor position when F6 is pressed
- Hide and save content when Escape or Ctrl+Enter is pressed
- Monitor clipboard changes at a reasonable interval (100ms)
- Keep track of previous clipboard content to avoid duplicates
- Append new clipboard content with newlines between entries
- Auto-scroll to show the latest content

Implementation Details:
- Use proper OOP with class-based design
- Store configuration in static Maps
- Handle proper cleanup in __Delete method
- Implement keyboard shortcuts that work both globally and when the window is active
- Add visual feedback when saving back to clipboard (like a brief tooltip)

Technical Requirements:
- Use a regular Edit control for the main text display (not RichEdit)
- Make the script work on Windows 10 with proper dark mode support
- Include proper error handling for clipboard operations
```

---

Each block above represents a separate test specification. You can now copy and paste each section independently into your AutoHotkey v2 projects.