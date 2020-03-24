////
///  HtmlColorizer.swift
//

import Ashen


class HtmlColorizer: Colorizer {
    func process(_ input: String) -> TextType {
        guard let tag = Tag(input: input) else { return input }
        return tag.attrText
    }
}
