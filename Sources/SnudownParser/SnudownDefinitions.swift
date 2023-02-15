//
//  File: SnudownDefinitions.swift
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

// MARK: - Externally visible properties

public extension NSAttributedString.Key {
    static var spoiler: NSAttributedString.Key {
        NSAttributedString.Key("SDSpoiler") // Stores an integer (id)
    }

    static var quote: NSAttributedString.Key {
        NSAttributedString.Key("SDQuote") // Stores in integer (depth)
    }
}

public struct ParseResult {
    var components = [MarkdownComponent]()
    var uniqueLinks = Set<String>()
    var linkOrder = [String]()
    
    public init() {
        
    }
}

public struct MarkdownConfig {
    let fontBoldItalic: NSFont
    let fontBold: NSFont
    let fontItalic: NSFont
    let fontCode: NSFont
    let fontSuperscript: NSFont
    let fontDefault: NSFont
    let fontH1: NSFont
    let fontH2: NSFont
    let fontH3: NSFont
    let fontH4: NSFont
    let fontH5: NSFont
    let fontH6: NSFont

    public init(fontBoldItalic: NSFont, fontBold: NSFont, fontItalic: NSFont, fontCode: NSFont, fontSuperscript: NSFont, fontDefault: NSFont, fontH1: NSFont, fontH2: NSFont, fontH3: NSFont, fontH4: NSFont, fontH5: NSFont, fontH6: NSFont) {
        self.fontBoldItalic = fontBoldItalic
        self.fontBold = fontBold
        self.fontItalic = fontItalic
        self.fontCode = fontCode
        self.fontSuperscript = fontSuperscript
        self.fontDefault = fontDefault
        self.fontH1 = fontH1
        self.fontH2 = fontH2
        self.fontH3 = fontH3
        self.fontH4 = fontH4
        self.fontH5 = fontH5
        self.fontH6 = fontH6
    }
}

public enum MarkdownComponent {
    case text(NSAttributedString)
    case code(String)
    case image(URL, CGSize)
    case table(MarkdownTable)
    case list(MarkdownList)
    case blockquote([NSAttributedString], Int)
}

public struct MarkdownTable {
    var headers = [NSAttributedString]()
    var rows = [[NSAttributedString]]()
}

public class MarkdownList {
    public enum Kind {
        case ordered
        case unordered
    }

    let kind: Kind
    var children: [MarkdownListNode]

    public init(kind: Kind, children: [MarkdownListNode]) {
        self.kind = kind
        self.children = children
    }
}

public class MarkdownListNode {
    let attributed: NSMutableAttributedString
    var list: MarkdownList?

    public init(attributed: NSMutableAttributedString, list: MarkdownList? = nil) {
        self.attributed = attributed
        self.list = list
    }
}

// MARK: - Internal use only

struct ParseTemp {
    // Temp data
    var allowAppend = false
    var builder = ""
    var builderLen = 0
    var activeStyles = 0
    var currentStyleStart = 0
    var currentStyling: TagStyle = []
    var markedIndex = 0 // used for links & spoilers
    var blockQuoteFragments = [NSAttributedString]()
    var blockQuoteDepth = 0
    var lastLink = ""
    var tempTable = MarkdownTable()
    var tempLists = [MarkdownList]()
    // Temp component data
    var styleRanges = [StyleRange]()
    var spoilerRanges = [NSRange]()
    var linkRanges = [LinkRange]()
    // Final parse data
    var result = ParseResult()
}

struct TagAction: OptionSet {
    let rawValue: Int
    static let newBuilder = TagAction(rawValue: 1 << 0)
    static let popBuilder = TagAction(rawValue: 1 << 1)
    static let allowAppend = TagAction(rawValue: 1 << 2)
    static let disallowAppend = TagAction(rawValue: 1 << 3)
    static let markIndex = TagAction(rawValue: 1 << 4)
    static let markIndexAsSpoiler = TagAction(rawValue: 1 << 5)
    static let markIndexAsLink = TagAction(rawValue: 1 << 6)
    static let markCodeBlock = TagAction(rawValue: 1 << 7)
    static let closeHeader = TagAction(rawValue: 1 << 8)
    static let closeTableHeader = TagAction(rawValue: 1 << 9)
    static let closeTableRow = TagAction(rawValue: 1 << 10)
    static let newTable = TagAction(rawValue: 1 << 11)
    static let closeTable = TagAction(rawValue: 1 << 12)
    static let newOrderedList = TagAction(rawValue: 1 << 13)
    static let newUnorderedList = TagAction(rawValue: 1 << 14)
    static let closeList = TagAction(rawValue: 1 << 15)
    static let closeListElement = TagAction(rawValue: 1 << 16)
    static let openBlockQuote = TagAction(rawValue: 1 << 17)
    static let closeBlockQuote = TagAction(rawValue: 1 << 18)
}

struct TagStyle: OptionSet {
    let rawValue: Int
    static let bold = TagStyle(rawValue: 1 << 0)
    static let italic = TagStyle(rawValue: 1 << 1)
    static let strikethrough = TagStyle(rawValue: 1 << 2)
    static let superscript = TagStyle(rawValue: 1 << 3)
    static let inlineCode = TagStyle(rawValue: 1 << 4)
    static let h1 = TagStyle(rawValue: 1 << 5)
    static let h2 = TagStyle(rawValue: 1 << 6)
    static let h3 = TagStyle(rawValue: 1 << 7)
    static let h4 = TagStyle(rawValue: 1 << 8)
    static let h5 = TagStyle(rawValue: 1 << 9)
    static let h6 = TagStyle(rawValue: 1 << 10)
}

struct StyleRange {
    let style: TagStyle
    let range: NSRange
}

struct LinkRange {
    let link: String
    let range: NSRange
}
