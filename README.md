# SnudownParser
Parsing markdown is a challenge due to competing standards and edge cases. This Swift Package makes it easy to parse Snudown in the form of HTML.

# Features
* Easily extract text, lists, tables, inline images/gifs and more from Snudown HTML strings
* Easily loop all found links
* Efficiently parse huge examples quickly and efficiently

# TODO
- [ ] Add additional `NSAttributedString.Key.*` properties

# Use case
You may be tasked with parsing the Snudown formatted string.
```
&#x200B;\n\n|Header 1|Header 2|\n|:-|:-|\n|Key|Value|
```

The Snudown HTML representation of the raw markdown string will be present in responses you get from Reddit. This is considerably easier to work with.
```html
<div class=\"md\"><p>&#x200B;</p>\n\n<table><thead>\n<tr>\n<th align=\"left\">Header 1</th>\n<th align=\"left\">Header 2</th>\n</tr>\n</thead><tbody>\n<tr>\n<td align=\"left\">Key</td>\n<td align=\"left\">Value</td>\n</tr>\n</tbody></table>\n</div>
```

Suppose you want extract the table, and preserve the display attributes (e.g., spoiler, bold, link etc.) You can do this easily using:

```swift
let html = ...
let config = ...
let parser = SnudownParser(config: config)
let result = parser.parse(html: html)

if case MarkdownComponent.table(let table) = result.components[1] {
   let headers = table.headers
}
```

Easily see all links in the order they were discovered using:
```swift
let allLinks = result.linkOrder
```

If you want to get all elements, you can loop the components:
```swift
for component in result.components {
    switch component {
    case .text(let attributed):
        break
    case .code(let code):
        break
    case .image(let url, let size):
        break
    case .table(let table):
        break
    case .list(let list):
        break
    case .blockquote(let elements, let depth):
        break
    }
}
```

You can customize the font for various attributes using `MarkdownConfig`. Make sure the fonts exist, and be careful about force unwrapping like in this example!
```swift
let fontSize = NSFont.systemFontSize + 2
let config = MarkdownConfig(
      fontBoldItalic: NSFont(name: "AvenirNext-BoldItalic", size: fontSize)!,
      fontBold: NSFont.boldSystemFont(ofSize: fontSize),
      fontItalic: NSFont(name: "Avenir-BookOblique", size: fontSize)!,
      fontCode: NSFont(name: "AmericanTypewriter", size: fontSize)!,
      fontSuperscript: NSFont.systemFont(ofSize: NSFont.systemFontSize - 2),
      fontDefault: NSFont.systemFont(ofSize: fontSize),
      fontH1: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 6),
      fontH2: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 4),
      fontH3: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 3),
      fontH4: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2),
      fontH5: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 1),
      fontH6: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize - 1)
)
```

You can then use NSAttributedString functions to get or modify styles. For example, use `NSAttributedString.Key.spoiler` and `NSAttributedString.Key.quote` from this package.
```swift
let attributes = attributedString.attributes(at: 0, effectiveRange: nil)

for attr in attributes {
   print(attr.key, attr.value)
}
```

# Installation
Open Xcode and add the Swift Package opening `Project > Package Dependencies > +` and search for this repository: `https://github.com/aciodev/SnudownParser`

Then add the `SnudownParser` import at the top of your source file.
