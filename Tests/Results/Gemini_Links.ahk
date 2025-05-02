/* 
Gemini_Links.ahk | Gemini | 2.5 Pro | 04/06/2025
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
*/