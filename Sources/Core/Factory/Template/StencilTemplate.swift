//
//  StencilTemplate.swift
//  StyleSource
//
//  Created by Bruno Fernandes on 6/28/18.
//  Copyright © 2018 Bruno Fernandes. All rights reserved.
//

import Foundation
import Stencil

public class StencilTemplate: Stencil.Template {

    public required init(templateString: String, environment: Environment? = nil, name: String? = nil) {
        let templateWithMarkedNewlines = templateString
            .replacingOccurrences(of: "\n\n", with: "\n\u{000b}\n")
            .replacingOccurrences(of: "\n\n", with: "\n\u{000b}\n")
        super.init(templateString: templateWithMarkedNewlines, environment: environment, name: name)
    }

    public override func render(_ dictionary: [String: Any]? = nil) throws -> String {
        return try removeExtraLines(from: super.render(dictionary))
    }

    private func removeExtraLines(from str: String) -> String {
        let extraLinesRE: NSRegularExpression = {
            do {
                return try NSRegularExpression(pattern: "\\n([ \\t]*\\n)+", options: [])
            } catch {
                fatalError("Regular Expression pattern error: \(error)")
            }
        }()
        let compact = extraLinesRE.stringByReplacingMatches(
            in: str,
            options: [],
            range: NSRange(location: 0, length: str.utf16.count),
            withTemplate: "\n"
        )
        let unmarkedNewlines = compact
            .replacingOccurrences(of: "\n\u{000b}\n", with: "\n\n")
            .replacingOccurrences(of: "\n\u{000b}\n", with: "\n\n")
        return unmarkedNewlines
    }
}

internal extension Extension {

    internal func registerExtensions() {
        registerStringsFilters()
    }

    private func registerStringsFilters() {
        registerFilter("reviseName", filter: Filters.Strings.reviseName)
        registerFilter("transform", filter: Filters.Strings.transform)
    }
}
