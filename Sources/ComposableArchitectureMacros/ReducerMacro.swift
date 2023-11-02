import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum ReducerMacro {
}

extension ReducerMacro: ExtensionMacro {
  public static func expansion<D: DeclGroupSyntax, T: TypeSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    attachedTo declaration: D,
    providingExtensionsOf type: T,
    conformingTo protocols: [TypeSyntax],
    in context: C
  ) throws -> [ExtensionDeclSyntax] {
    if let inheritanceClause = declaration.inheritanceClause,
      inheritanceClause.inheritedTypes.contains(
        where: {
          ["Reducer"].withQualified.contains($0.type.trimmedDescription)
        }
      )
    {
      return []
    }
    let ext: DeclSyntax =
      """
      extension \(type.trimmed): ComposableArchitecture.Reducer {}
      """
    return [ext.cast(ExtensionDeclSyntax.self)]
  }
}

extension ReducerMacro: MemberAttributeMacro {
  public static func expansion<D: DeclGroupSyntax, M: DeclSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    attachedTo declaration: D,
    providingAttributesFor member: M,
    in context: C
  ) throws -> [AttributeSyntax] {
    if let enumDecl = member.as(EnumDeclSyntax.self) {
      var attributes: [String] = []
      switch enumDecl.name.text {
      case "State":
        attributes = ["CasePathable", "dynamicMemberLookup"]
      case "Action":
        attributes = ["CasePathable"]
      default:
        break
      }
      for attribute in enumDecl.attributes {
        guard
          case let .attribute(attribute) = attribute,
          let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
        else { continue }
        attributes.removeAll(where: { $0 == attributeName })
      }
      return attributes.map {
        AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier($0)))
      }
    } else if let property = member.as(VariableDeclSyntax.self),
      property.bindingSpecifier.text == "var",
      property.bindings.count == 1,
      let binding = property.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      identifier.text == "body",
      case .getter = binding.accessorBlock?.accessors
    {
      if let reduce = declaration.memberBlock.members.first(where: {
        guard
          let method = $0.decl.as(FunctionDeclSyntax.self),
          method.name.text == "reduce",
          method.signature.parameterClause.parameters.count == 2,
          let state = method.signature.parameterClause.parameters.first,
          state.firstName.text == "into",
          state.type.as(AttributedTypeSyntax.self)?.specifier?.text == "inout",
          method.signature.parameterClause.parameters.last?.firstName.text == "action",
          method.signature.effectSpecifiers == nil,
          method.signature.returnClause?.type.as(IdentifierTypeSyntax.self) != nil
        else {
          return false
        }
        return true
      }) {
        context.diagnose(
          Diagnostic(
            node: reduce.decl.cast(FunctionDeclSyntax.self).name,
            message: SimpleDiagnosticMessage(
              message: """
                A 'reduce' method should not be defined in a reducer with a 'body'; it takes \
                precedence and 'body' will never be invoked
                """,
              diagnosticID: "reducer-with-body-and-reduce",
              severity: .warning
            ),
            notes: [
              Note(
                node: Syntax(identifier),
                message: SimpleNoteMessage(
                  message: "'body' defined here",
                  fixItID: "reducer-with-body-and-reduce"
                )
              )
            ]
          )
        )
      }
      for attribute in property.attributes {
        guard
          case let .attribute(attribute) = attribute,
          let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
        else { continue }
        guard
          !attributeName.starts(with: "ReducerBuilder"),
          !attributeName.starts(with: "ComposableArchitecture.ReducerBuilder")
        else { return [] }
      }
      return [
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(
            name: .identifier("ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>")
          )
        )
      ]
    } else {
      return []
    }
  }
}

struct SimpleDiagnosticMessage: DiagnosticMessage {
  var message: String
  var diagnosticID: MessageID
  var severity: DiagnosticSeverity

  init(message: String, diagnosticID: String, severity: DiagnosticSeverity) {
    self.message = message
    self.diagnosticID = MessageID(
      domain: "co.pointfree.swift-composable-architecture",
      id: diagnosticID
    )
    self.severity = severity
  }
}

struct SimpleNoteMessage: NoteMessage {
  var message: String
  var fixItID: MessageID

  init(message: String, fixItID: String) {
    self.message = message
    self.fixItID = MessageID(
      domain: "co.pointfree.swift-composable-architecture",
      id: fixItID
    )
  }
}

extension DeclGroupSyntax {
  var inheritanceClause: InheritanceClauseSyntax? {
    if let decl = self.as(StructDeclSyntax.self) {
      return decl.inheritanceClause
    } else if let decl = self.as(ClassDeclSyntax.self) {
      return decl.inheritanceClause
    } else if let decl = self.as(EnumDeclSyntax.self) {
      return decl.inheritanceClause
    } else {
      return nil
    }
  }

  var memberBlock: MemberBlockSyntax? {
    if let decl = self.as(StructDeclSyntax.self) {
      return decl.memberBlock
    } else if let decl = self.as(ClassDeclSyntax.self) {
      return decl.memberBlock
    } else if let decl = self.as(EnumDeclSyntax.self) {
      return decl.memberBlock
    } else {
      return nil
    }
  }
}

extension Array where Element == String {
  var withQualified: Self {
    self.flatMap { [$0, "ComposableArchitecture.\($0)"] }
  }
}