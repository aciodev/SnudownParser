import XCTest
@testable import SnudownParser

final class SnudownParserTests: XCTestCase {
    func testComprehensive() throws {
        let comprehensiveHtml = """
                   <div class=\\"md\\"><h1><a href=\\"https://google.com\\">Header 1</a></h1>\\n\\n<h2>Header 2</h2>\\n\\n<p>This is <strong>bold</strong> and this is <em>italic</em>, this is <strong><em>bold-italic</em></strong> and this is <strong>bold with</strong> <strong><em>italic</em></strong> <strong>in the middle</strong> and some <del>deleted</del> <strong><em><del>bold-italic</del></em></strong> <del>text</del> and don&#39;t forget**<sup>super</sup>**<sup>script</sup><strong><em><del><sup>s</sup></del></em></strong> <sup>notation</sup>. A <a href=\\"https://reddit.com\\"><strong>bold</strong> link</a> with a <span class=\\"md-spoiler-text\\">top secret spoiler</span>. Inline code: <code>if (options &amp; 1)</code> .</p>\\n\\n<table><thead>\\n<tr>\\n<th align=\\"left\\">Name</th>\\n<th align=\\"left\\">Salary</th>\\n</tr>\\n</thead><tbody>\\n<tr>\\n<td align=\\"left\\">Joe Mama</td>\\n<td align=\\"left\\">$40,000</td>\\n</tr>\\n</tbody></table>\\n\\n<p><strong>List:</strong></p>\\n\\n<ol>\\n<li>This <strong>bold</strong> list element\\n\\n<ol>\\n<li>With sublist element\\n\\n<ol>\\n<li>aaa</li>\\n</ol></li>\\n</ol></li>\\n<li>This <a href=\\"https://www.google.com\\">linked</a> list element</li>\\n</ol>\\n\\n<p><strong>Block quote</strong></p>\\n\\n<blockquote>\\n<p><strong>Line 1</strong>  </p>\\n\\n<p>Line 2</p>\\n</blockquote>\\n\\n<p><strong>Code:</strong></p>\\n\\n<pre><code>let width: Double = 3.0\\nprint(&quot;Width: \\\\(width)&quot;)\\n</code></pre>\\n</div>
                   """
        
        let defaultFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let config = MarkdownConfig(
            fontBoldItalic: defaultFont,
            fontBold: defaultFont,
            fontItalic: defaultFont,
            fontCode: defaultFont,
            fontSuperscript: defaultFont,
            fontDefault: defaultFont,
            fontH1: defaultFont,
            fontH2: defaultFont,
            fontH3: defaultFont,
            fontH4: defaultFont,
            fontH5: defaultFont,
            fontH6: defaultFont
        )
        
        let parser = SnudownParser(config: config)
        let parseResult = parser.parse(html: comprehensiveHtml)
        let components = parseResult.components
        
        XCTAssertEqual(components.count, 10)
        XCTAssertEqual(parseResult.uniqueLinks.count, 3)
        XCTAssert(parseResult.uniqueLinks.contains("https://google.com"))
        XCTAssert(parseResult.uniqueLinks.contains("https://reddit.com"))
        XCTAssert(parseResult.uniqueLinks.contains("https://www.google.com"))
    }
}
