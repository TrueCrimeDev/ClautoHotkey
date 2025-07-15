#Requires Autohotkey v2.1-alpha.14
#SingleInstance Force

#include winrt.ahk-main\winrt.ahk
#include winrt.ahk-main\windows.ahk

/** A class for managing Windows Clipboard History with integration to WinRT API. */
class ClipboardHistory
{
	;; === Static Properties ===

	/** @prop {Object} Clipboard `Windows.ApplicationModel.DataTransfer.Clipboard` */
	static Clipboard => this.DataTransfer.Clipboard

	/** @prop {Integer} Gets the count of clipboard history items */
	static Count => this.__GetHistoryItemsAsync().Size

	/** @prop {Object} DataTransfer `Windows.ApplicationModel.DataTransfer` */
	static DataTransfer => Windows.ApplicationModel.DataTransfer

	/** @prop {Boolean} Indicates if clipboard history is enabled */
	static IsEnabled => this.Clipboard.IsHistoryEnabled()

	/** @prop {Object} StandardDataFormats `Windows.ApplicationModel.DataTransfer.StandardDataFormats` */
	static StandardDataFormats => this.DataTransfer.StandardDataFormats

	;; === Static Methods ===

	/**
	 * Returns the available formats for the given index or content.
	 * @param {Integer|Object} indexOrContent - The history item index or content object.
	 * @returns {String} A pipe-separated list of available formats.
	 */
	static AvailableFormats(indexOrContent)
	{
		message := ""
		content := IsNumber(indexOrContent) ? this[indexOrContent].Content : indexOrContent
		formats := content.AvailableFormats

		Loop formats.Size
			message .= formats.GetAt(A_Index - 1) "|"

		return RTrim(message, "|")
	}

	/** Clears the clipboard history. */
	static Clear() => this.Clipboard.ClearHistory()

	/**
	 * Deletes a clipboard history item by index or item object.
	 * @param {Integer|Object} ItemOrIndex - The history item index or item object.
	 * @returns {Boolean} `true` on success, `false` on failure.
	 */
	static DeleteItem(ItemOrIndex) => this.Clipboard.DeleteItemFromHistory(IsNumber(ItemOrIndex) ?
		this[ItemOrIndex] : ItemOrIndex)

	/**
	 * Gets the clipboard history items asynchronously.
	 * @returns {Array|Boolean} An array of history items or `false` on failure.
	 */
	static __GetHistoryItemsAsync()
	{
		result := this.Clipboard.GetHistoryItemsAsync().Await()

		if result.Status.n
			return (TrayTip("GetHistoryItemsAsync failed: " String(result.Status)), false)

		return result.Items
	}

	/**
	 * Gets the HTML content of a clipboard history item.
	 * @param {Integer} [index=1] - The index of the item (1-based).
	 * @param {Boolean} [convertToText=true] - Whether to convert HTML to plain text.
	 * @param {String} [&source] - Variable to store the source URL.
	 * @returns {String|Boolean} The HTML content or plain text, or `false` on failure.
	 */
	static GetHtml(index := 1, convertToText := true, &source?)
	{
		content := this[index].Content

		if !content.Contains(this.StandardDataFormats.Html)
			return (TrayTip("Html Format Not Found."), "")

		fragment := content.GetHtmlFormatAsync().Await()

		if !convertToText
			return fragment

		if !RegExMatch(fragment, 'mS)^SourceURL:(.*)\R\K(?s:.*)', &match)
			return (TrayTip("Error parsing HTML fragment."), "")

		source := match.1
		return WinRT('Windows.Data.Html.HtmlUtilities').ConvertToText(match.0)
	}

	/**
	 * Gets a specific clipboard history item by index.
	 * @param {Integer} [index=1] - The index of the item (1-based).
	 * @returns {Object} The clipboard history item.
	 */
	static __Item[index := 1] => this.__GetHistoryItemsAsync().GetAt(index - 1)

	/**
	 * Gets the text content of a clipboard history item.
	 * @param {Integer} index - The index of the item (1-based).
	 * @returns {String} The text content of the item.
	 */
	static GetText(index)
	{
		content := this[index].Content

		if !content.Contains(this.StandardDataFormats.Text)
			return (TrayTip("Clipboard Format Not Supported"), "")

		return content.GetTextAsync().Await()
	}

	/** Initializes the class by enabling clipboard history if not already enabled. */
	static __New()
	{
		this.Prototype.DeleteProp("__New")

		if !this.IsEnabled
			this.DataTransfer.ClipboardContentOptions().IsAllowedInHistory := true
	}

	/**
	 * Sets a clipboard history item as the current clipboard content.
	 * @param {Integer} [index=1] - The index of the item (1-based).
	 * @returns {Boolean} `true` on success, `false` on failure.
	 */
	static SetItemAsContent(index := 1)
	{
		static SetHistoryItemAsContentStatus := [
			'Success',
			'AccessDenied',
			'ItemDeleted'
		]

		if !(item := this[index])
			return false

		status := this.Clipboard.SetHistoryItemAsContent(item)

		try if ((result := SetHistoryItemAsContentStatus[Number(status) + 1]) != "Success")
			return (TrayTip(result), false)

		return true
	}
}

;; Example

/* if (!A_IsCompiled && A_LineFile = A_ScriptFullPath)
	Loop count := ClipboardHistory.Count
		if texts := ClipboardHistory.GetText(A_Index)
			MsgBox(texts, "Clipboard History Item Index: " A_Index " of " count)
 */
