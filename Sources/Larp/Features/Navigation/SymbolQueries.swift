import CodeEditLanguages

/// Tree-sitter patterns that find definitions, per language. Each captures
/// the defining name, and the capture's name is the kind of symbol.
///
/// Every pattern is compiled on its own first and the ones a grammar rejects
/// are dropped (see SymbolIndex), so one wrong node name costs that pattern,
/// not the whole language.
enum SymbolQueries {
    static func patterns(for language: TreeSitterLanguage) -> [String] {
        switch language {
        case .python:
            return [
                "(function_definition name: (identifier) @function)",
                "(class_definition name: (identifier) @class)",
                "(module (expression_statement (assignment left: (identifier) @constant)))",
            ]
        case .go:
            return [
                "(function_declaration name: (identifier) @function)",
                "(method_declaration name: (field_identifier) @method)",
                "(type_spec name: (type_identifier) @type)",
                "(source_file (const_declaration (const_spec name: (identifier) @constant)))",
                "(source_file (var_declaration (var_spec name: (identifier) @constant)))",
            ]
        case .java:
            return [
                "(class_declaration name: (identifier) @class)",
                "(interface_declaration name: (identifier) @type)",
                "(enum_declaration name: (identifier) @type)",
                "(record_declaration name: (identifier) @class)",
                "(method_declaration name: (identifier) @method)",
                "(constructor_declaration name: (identifier) @method)",
            ]
        case .rust:
            return [
                "(function_item name: (identifier) @function)",
                "(function_signature_item name: (identifier) @function)",
                "(struct_item name: (type_identifier) @type)",
                "(enum_item name: (type_identifier) @type)",
                "(trait_item name: (type_identifier) @type)",
                "(type_item name: (type_identifier) @type)",
                "(const_item name: (identifier) @constant)",
                "(static_item name: (identifier) @constant)",
                "(mod_item name: (identifier) @type)",
                "(macro_definition name: (identifier) @function)",
            ]
        case .typescript, .tsx:
            return [
                "(function_declaration name: (identifier) @function)",
                "(class_declaration name: (type_identifier) @class)",
                "(abstract_class_declaration name: (type_identifier) @class)",
                "(interface_declaration name: (type_identifier) @type)",
                "(type_alias_declaration name: (type_identifier) @type)",
                "(enum_declaration name: (identifier) @type)",
                "(method_definition name: (property_identifier) @method)",
                "(program (lexical_declaration (variable_declarator name: (identifier) @constant)))",
                "(program (export_statement (lexical_declaration (variable_declarator name: (identifier) @constant))))",
            ]
        case .javascript, .jsx:
            return [
                "(function_declaration name: (identifier) @function)",
                "(class_declaration name: (identifier) @class)",
                "(method_definition name: (property_identifier) @method)",
                "(program (lexical_declaration (variable_declarator name: (identifier) @constant)))",
                "(program (export_statement (lexical_declaration (variable_declarator name: (identifier) @constant))))",
                "(program (variable_declaration (variable_declarator name: (identifier) @constant)))",
            ]
        case .swift:
            return [
                "(function_declaration name: (simple_identifier) @function)",
                "(class_declaration name: (type_identifier) @type)",
                "(protocol_declaration name: (type_identifier) @type)",
                "(typealias_declaration name: (type_identifier) @type)",
                "(enum_entry name: (simple_identifier) @constant)",
                "(source_file (property_declaration name: (pattern bound_identifier: (simple_identifier) @constant)))",
            ]
        case .kotlin:
            return [
                "(function_declaration (simple_identifier) @function)",
                "(class_declaration (type_identifier) @class)",
                "(object_declaration (type_identifier) @class)",
                "(source_file (property_declaration (variable_declaration (simple_identifier) @constant)))",
            ]
        default:
            return []
        }
    }
}
