import MarkdownUI
import SwiftUI

extension Theme {
    /// GitHub's layout with larp's colours: Apple greys and a red inline code
    /// in light, neon links and green inline code on black in dark. Every
    /// colour comes from Chrome, so the page matches the panes around it.
    @MainActor static func larp(fontSize: Double) -> Theme {
        let separator = Color(nsColor: Chrome.separator)
        let codeBackground = Color(nsColor: Chrome.codeBackground)

        return Theme.gitHub
            .text {
                ForegroundColor(.primary)
                BackgroundColor(nil)
                FontSize(fontSize)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                ForegroundColor(Color(nsColor: Chrome.inlineCode))
                BackgroundColor(codeBackground)
            }
            .link {
                ForegroundColor(Color(nsColor: Chrome.link))
            }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.bold)
                            FontSize(.em(2))
                        }
                    separator.frame(height: 1)
                }
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.5))
                        }
                    separator.frame(height: 1)
                }
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: Chrome.accent))
                        .relativeFrame(width: .em(0.2))
                    configuration.label
                        .markdownTextStyle { ForegroundColor(.secondary) }
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                        }
                        .padding(16)
                }
                .background(codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(separator))
                .markdownMargin(top: 0, bottom: 16)
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: separator))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(Color(nsColor: Chrome.contentBackground), Color(nsColor: Chrome.stripe)))
                    .markdownMargin(top: 0, bottom: 16)
            }
            .thematicBreak {
                separator
                    .frame(height: 1)
                    .markdownMargin(top: 24, bottom: 24)
            }
    }
}
