//
//  File: SnudownParser.swift
//  Project: SnudownParser
//
//  Created by Andres Cruz on 2/9/23.
//  Copyright © 2022 Andres Cruz (mail AT acio DOT dev)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Cocoa

// MARK: - Actions depending on the tag or entity

public class SnudownParser {
    let actions: [String: TagAction] = [
        "<p>": [.newBuilder, .allowAppend],
        "</p>": [.popBuilder, .disallowAppend],
        "<span class=\\\"md-spoiler-text\\\">": [.markIndex],
        "</span>": [.markIndexAsSpoiler],
        "</a>": [.markIndexAsLink],
        "<pre>": [.markCodeBlock],
        "<h1>": [.newBuilder, .allowAppend],
        "<h2>": [.newBuilder, .allowAppend],
        "<h3>": [.newBuilder, .allowAppend],
        "<h4>": [.newBuilder, .allowAppend],
        "<h5>": [.newBuilder, .allowAppend],
        "<h6>": [.newBuilder, .allowAppend],
        "</h1>": [.closeHeader, .disallowAppend],
        "</h2>": [.closeHeader, .disallowAppend],
        "</h3>": [.closeHeader, .disallowAppend],
        "</h4>": [.closeHeader, .disallowAppend],
        "</h5>": [.closeHeader, .disallowAppend],
        "</h6>": [.closeHeader, .disallowAppend],
        "<th>": [.newBuilder, .allowAppend],
        "<th align=\\\"left\\\">": [.newBuilder, .allowAppend],
        "<th align=\\\"right\\\">": [.newBuilder, .allowAppend],
        "</th>": [.closeTableHeader, .disallowAppend],
        "<td>": [.newBuilder, .allowAppend],
        "<td align=\\\"left\\\">": [.newBuilder, .allowAppend],
        "<td align=\\\"right\\\">": [.newBuilder, .allowAppend],
        "</td>": [.closeTableRow, .disallowAppend],
        "<table>": [.newTable],
        "</table>": [.closeTable],
        "<ul>": [.newUnorderedList, .disallowAppend],
        "<ol>": [.newOrderedList, .disallowAppend],
        "</ul>": [.closeList],
        "</ol>": [.closeList],
        "<li>": [.newBuilder, .allowAppend],
        "</li>": [.closeListElement, .disallowAppend],
        "<blockquote>": [.openBlockQuote],
        "</blockquote>": [.closeBlockQuote]
    ]

    let styles: [String: TagStyle] = [
        "<strong>": [.bold],
        "</strong>": [.bold],
        "<em>": [.italic],
        "</em>": [.italic],
        "<del>": [.strikethrough],
        "</del>": [.strikethrough],
        "<sup>": [.superscript],
        "</sup>": [.superscript],
        "<code>": [.inlineCode],
        "</code>": [.inlineCode]
    ]

    let replacements: [String: String] = [
        "&#39;": "'",
        "&#039;": "'",
        "&amp;": "&",
        "&quot;": "\"",
        "&#32;": " ",
        "&lt;": "<",
        "&gt;": ">",
        "&#x200B;": ""
    ]

    let config: MarkdownConfig

    init(config: MarkdownConfig) {
        self.config = config
    }
}

// MARK: - Core parser

extension SnudownParser {
    /// Parse html
    func parse(html: String) -> ParseResult {
        let chars = Array<Character>(html)
        var i = 0
        let len = chars.count

        var parseTemp = ParseTemp()

        while i < len {
            switch chars[i] {
            case "&":
                handleHtmlEntity(at: &i, len: len, chars: chars, parseTemp: &parseTemp)
            case "<":
                // Special case, handle links and inline images
                if chars[i + 1] == "a" {
                    handleLinkOrInlineImage(at: &i, len: len, chars: chars, parseTemp: &parseTemp)
                    continue
                }

                let htmlTag = extractTag(at: &i, len: len, chars: chars)

                if let tagActions = actions[htmlTag] {
                    handleTag(actions: tagActions, at: &i, len: len, chars: chars, parseTemp: &parseTemp)
                } else if let styleFlag = styles[htmlTag] {
                    handleStyle(at: &i, len: len, chars: chars, styleFlag: styleFlag, parseTemp: &parseTemp)
                }
            default:
                handleAppend(at: &i, len: len, chars: chars, parseTemp: &parseTemp)
            }
        }

        return parseTemp.result
    }

    private func handleHtmlEntity(at: inout Int, len: Int, chars: Array<Character>, parseTemp: inout ParseTemp) {
        let htmlEntity = findHtmlEntity(at: &at, len: len, chars: chars)
        let substitution = replacements[htmlEntity] ?? htmlEntity
        parseTemp.builder.append(substitution)
        parseTemp.builderLen += substitution.count
    }

    private func handleLinkOrInlineImage(at: inout Int, len: Int, chars: Array<Character>, parseTemp: inout ParseTemp) {
        let linkProperties = extractProps(at: &at, len: len, chars: chars)
        parseTemp.markedIndex = parseTemp.builderLen
        parseTemp.lastLink = linkProperties["href"] ?? "https://google.com"

        if parseTemp.result.uniqueLinks.insert(parseTemp.lastLink).inserted {
            parseTemp.result.linkOrder.append(parseTemp.lastLink)
        }

        if chars[at] == "<" && chars[at + 1] == "i" {
            // Special case of in-line image
            let inlineImageProperties = extractProps(at: &at, len: len, chars: chars)

            if let src = inlineImageProperties["src"],
               let url = URL(string: src),
               let widthStr = inlineImageProperties["width"], let width = Double(widthStr),
               let heightStr = inlineImageProperties["height"], let height = Double(heightStr) {
                parseTemp.result.components.append(.image(url, .init(width: width, height: height)))
            }

            // Skip closing </a> tag
            skip(numTags: 1, at: &at, len: len, chars: chars)
        }
    }

    private func handleCodeBlock(at: inout Int, len: Int, chars: Array<Character>, parseTemp: inout ParseTemp) {
        // Skip <code>
        skip(numTags: 1, at: &at, len: len, chars: chars)

        var codeString = ""
        while at < len && chars[at] != "<" {
            if chars[at] == "\\" {
                if chars[at + 1] == "n" {
                    codeString.append("\n")
                    at += 2 // skip next '\n'
                } else {
                    codeString.append("\\")
                    at += 2 // skip next '\'
                }
            } else if chars[at] == "&" {
                let htmlEntity = findHtmlEntity(at: &at, len: len, chars: chars)
                let substitution = replacements[htmlEntity] ?? htmlEntity
                codeString.append(substitution)
            } else {
                codeString.append(chars[at])
                at += 1
            }
        }

        // Skip </code></pre>
        skip(numTags: 2, at: &at, len: len, chars: chars)
        parseTemp.result.components.append(.code(codeString))
    }

    private func handleTag(actions: TagAction, at: inout Int, len: Int, chars: Array<Character>, parseTemp: inout ParseTemp) {
        if actions.contains(.allowAppend) {
            parseTemp.allowAppend = true
        } else if actions.contains(.disallowAppend) {
            parseTemp.allowAppend = false
        }

        if actions.contains(.markIndex) {
            parseTemp.markedIndex = parseTemp.builderLen
        } else if actions.contains(.markIndexAsSpoiler) {
            parseTemp.spoilerRanges.append(.init(location: parseTemp.markedIndex, length: parseTemp.builderLen - parseTemp.markedIndex))
        } else if actions.contains(.markIndexAsLink) {
            parseTemp.linkRanges.append(.init(link: parseTemp.lastLink, range: .init(location: parseTemp.markedIndex, length: parseTemp.builderLen - parseTemp.markedIndex)))
        }

        if actions.contains(.markCodeBlock) {
            handleCodeBlock(at: &at, len: len, chars: chars, parseTemp: &parseTemp)
        }

        if actions.contains(.popBuilder) {
            popCurrentBuilder(parseTemp: &parseTemp, font: config.fontDefault)
        }

        if actions.contains(.closeHeader) {
            let font = getFontFor(headerChar: chars[at - 2])
            popCurrentBuilder(parseTemp: &parseTemp, font: font)
        }

        if actions.contains(.newUnorderedList) || actions.contains(.newOrderedList) {
            popCurrentAsListElement(parseTemp: &parseTemp)

            let type: MarkdownList.Kind = actions.contains(.newUnorderedList) ? .unordered : .ordered
            parseTemp.tempLists.append(.init(kind: type, children: []))
        } else if actions.contains(.closeList) {
            let list = parseTemp.tempLists.removeLast()
            let count = parseTemp.tempLists.count
            if count == 0 {
                parseTemp.result.components.append(.list(list))
            } else {
                let childrenCount = parseTemp.tempLists[count - 1].children.count
                parseTemp.tempLists[count - 1].children[childrenCount - 1].list = list
            }
        } else if actions.contains(.closeListElement) {
            popCurrentAsListElement(parseTemp: &parseTemp)
        }

        if actions.contains(.newTable) {
            parseTemp.tempTable = .init()
        } else if actions.contains(.closeTable) {
            parseTemp.result.components.append(.table(parseTemp.tempTable))
        } else if actions.contains(.closeTableHeader) {
            let attributed = asNSAttributedString(parseTemp: &parseTemp, font: config.fontDefault)
            clearBuilder(parseTemp: &parseTemp)
            parseTemp.tempTable.headers.append(attributed)
        } else if actions.contains(.closeTableRow) {
            let attributed = asNSAttributedString(parseTemp: &parseTemp, font: config.fontDefault)
            clearBuilder(parseTemp: &parseTemp)
            let rows = parseTemp.tempTable.rows

            if rows.isEmpty {
                parseTemp.tempTable.rows.append([attributed])
            } else {
                let lastRow = rows[rows.count - 1]
                if lastRow.count % parseTemp.tempTable.headers.count == 0 {
                    parseTemp.tempTable.rows.append([])
                }

                parseTemp.tempTable.rows[rows.count - 1].append(attributed)
            }
        }

        if actions.contains(.openBlockQuote) {
            if parseTemp.blockQuoteDepth > 0 {
                popCurrentAsBlockQuoteElement(parseTemp: &parseTemp)
            }

            parseTemp.blockQuoteDepth += 1
        } else if actions.contains(.closeBlockQuote) {
            popCurrentAsBlockQuoteElement(parseTemp: &parseTemp)
            parseTemp.blockQuoteDepth -= 1
        }
    }

    private func popCurrentAsBlockQuoteElement(parseTemp: inout ParseTemp) {
        guard parseTemp.blockQuoteFragments.count > 0 else {
            return
        }

        parseTemp.result.components.append(.blockquote(parseTemp.blockQuoteFragments, parseTemp.blockQuoteDepth))
    }

    private func popCurrentAsListElement(parseTemp: inout ParseTemp) {
        if parseTemp.builderLen == 0 {
            return // no string to append
        }
        let count = parseTemp.tempLists.count
        let attributed = asNSAttributedString(parseTemp: &parseTemp, font: config.fontDefault)
        clearBuilder(parseTemp: &parseTemp)
        parseTemp.tempLists[count - 1].children.append(.init(attributed: attributed))
    }

    private func handleStyle(at: inout Int, len: Int, chars: Array<Character>, styleFlag: TagStyle, parseTemp: inout ParseTemp) {
        if parseTemp.currentStyling.contains(styleFlag) {
            let range = NSRange(location: parseTemp.currentStyleStart, length: parseTemp.builderLen - parseTemp.currentStyleStart)
            parseTemp.styleRanges.append(.init(style: parseTemp.currentStyling, range: range))
            skip(numTags: parseTemp.activeStyles - 1, at: &at, len: len, chars: chars)
            parseTemp.activeStyles = 0
            parseTemp.currentStyling = []
        } else {
            if parseTemp.currentStyling.isEmpty {
                parseTemp.currentStyleStart = parseTemp.builderLen
            }

            parseTemp.currentStyling.insert(styleFlag)
            parseTemp.activeStyles += 1
        }
    }

    private func handleAppend(at: inout Int, len: Int, chars: Array<Character>, parseTemp: inout ParseTemp) {
        // If outside of tag range, try to build a string
        if parseTemp.allowAppend {
            parseTemp.builder.append(chars[at])
            parseTemp.builderLen += 1
        }

        at += 1
    }

    private func popCurrentBuilder(parseTemp: inout ParseTemp, font: NSFont) {
        let attributed = asNSAttributedString(parseTemp: &parseTemp, font: font)
        clearBuilder(parseTemp: &parseTemp)

        if parseTemp.blockQuoteDepth > 0 {
            parseTemp.blockQuoteFragments.append(attributed)
        } else {
            parseTemp.result.components.append(.text(attributed))
        }
    }

    private func clearBuilder(parseTemp: inout ParseTemp) {
        parseTemp.builder = ""
        parseTemp.builderLen = 0
        parseTemp.styleRanges.removeAll()
        parseTemp.spoilerRanges.removeAll()
        parseTemp.linkRanges.removeAll()
    }

    /// Turn a component into an NSMutableAttributedString
    private func asNSAttributedString(parseTemp: inout ParseTemp, font: NSFont) -> NSMutableAttributedString {
        let mutable = NSMutableAttributedString(string: parseTemp.builder, attributes: [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ])

        for info in parseTemp.styleRanges {
            let range = info.range
            if info.style.contains([.bold, .italic]) {
                mutable.addAttribute(.font, value: config.fontBoldItalic, range: range)
            } else if info.style.contains(.bold) {
                mutable.addAttribute(.font, value: config.fontBold, range: range)
            } else if info.style.contains(.italic) {
                mutable.addAttribute(.font, value: config.fontItalic, range: range)
            }

            if info.style.contains(.strikethrough) {
                mutable.addAttribute(.strikethroughColor, value: NSColor.systemRed, range: range)
                mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }

            if info.style.contains(.inlineCode) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: range)
                mutable.addAttribute(.font, value: config.fontCode, range: range)
            }

            if info.style.contains(.superscript) {
                mutable.addAttribute(.font, value: config.fontSuperscript, range: range)
                mutable.addAttribute(.baselineOffset, value: 5, range: range)
            }
        }

        for i in 0..<parseTemp.spoilerRanges.count {
            let spoilerRange = parseTemp.spoilerRanges[i]
            mutable.addAttribute(.spoiler, value: i, range: spoilerRange)
            mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: spoilerRange)
        }

        for linkRange in parseTemp.linkRanges {
            mutable.addAttribute(.link, value: linkRange.link, range: linkRange.range)
        }

        return mutable
    }
}

// MARK: - HTML helpers
extension SnudownParser {
    /// Extract &nbsp; and other html entities
    private func findHtmlEntity(at: inout Int, len: Int, chars: Array<Character>) -> String {
        var htmlEntity = ""
        while at < len {
            let c = chars[at]
            htmlEntity.append(c)
            at += 1
            if (c == ";") {
                break
            }
        }
        return htmlEntity
    }

    /// Used to skip html tags
    private func skip(numTags: Int, at: inout Int, len: Int, chars: Array<Character>) {
        if numTags == 0 {
            return
        }
        var count = 0
        while at < len {
            if chars[at] == ">" {
                at += 1
                count += 1
                if count == numTags {
                    return
                }
            }
            at += 1
        }
    }

    /// Extract an HTML tag
    private func extractTag(at: inout Int, len: Int, chars: Array<Character>) -> String {
        var htmlTag = ""
        while at < len {
            let c = chars[at]
            htmlTag.append(c)
            at += 1
            if c == ">" {
                break
            }
        }
        return htmlTag
    }

    /// Extract href=\"val\" and other properties
    private func extractProps(at: inout Int, len: Int, chars: Array<Character>) -> [String: String] {
        var props: [String: String] = [:]

        while at < len && chars[at] != " " {
            at += 1 // Skip until first space
        }

        while chars[at] != ">" {
            // Clear leading spaces
            while at < len && chars[at] == " " {
                at += 1
            }

            var title = ""
            while at < len && chars[at] != "=" {
                title.append(chars[at])
                at += 1
            }

            at += 1 // Skip the =

            // Build the property
            var prop = ""
            while at < len {
                let c = chars[at]
                if c == ">" || c == " " {
                    break
                }
                prop.append(c)
                at += 1
            }

            let startIndex = prop.index(prop.startIndex, offsetBy: 2)
            let endIndex = prop.index(prop.endIndex, offsetBy: -2)
            let range = startIndex..<endIndex
            props[title] = String(prop[range])
        }

        at += 1 // Consume trailing >
        return props
    }

    private func getFontFor(headerChar: Character) -> NSFont {
        switch headerChar {
        case "1":
            return config.fontH1
        case "2":
            return config.fontH2
        case "3":
            return config.fontH3
        case "4":
            return config.fontH4
        case "5":
            return config.fontH5
        case "6":
            return config.fontH6
        default:
            return config.fontH1
        }
    }
}
