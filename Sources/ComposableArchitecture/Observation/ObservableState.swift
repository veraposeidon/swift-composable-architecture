import Foundation
import Perception

/// A type that emits notifications to observers when underlying data changes.
///
/// Conforming to this protocol signals to other APIs that the value type supports observation.
/// However, applying the ``ObservableState`` protocol by itself to a type doesn’t add observation
/// functionality to the type. Instead, always use the ``ObservableState()`` macro when adding
/// observation support to a type.
public protocol ObservableState: Perceptible {
  var _$id: ObservableStateID { get }
  mutating func _$willSet()
  mutating func _$didSet()
}

/// A unique identifier for a observed value.
public struct ObservableStateID: Equatable, Hashable, Sendable {
  private var uuid: UUID
  private var tag: Int?
  public var _flag = false

  public init() {
    self.uuid = UUID()
  }

  public static let _$inert = Self()

  // TODO: inlinable?
  public func _$tag(_ tag: Int?) -> Self {
    var copy = self
    copy.tag = tag
    return copy
  }

  // TODO: inlinable?
  public static func _$id<T>(for value: T) -> Self {
    (value as? any ObservableState)?._$id ?? ._$inert
  }
  // TODO: inlinable?
  public static func _$id(for value: some ObservableState) -> Self {
    value._$id
  }
}

// TODO: inlinable?
public func _$isIdentityEqual<ID: Hashable, T: ObservableState>(
  _ lhs: IdentifiedArray<ID, T>, _ rhs: IdentifiedArray<ID, T>
) -> Bool {
  areOrderedSetsDuplicates(lhs.ids, rhs.ids)
}

// TODO: inlinable?
public func _$isIdentityEqual<T: ObservableState>(
  _ lhs: PresentationState<T>, _ rhs: PresentationState<T>
) -> Bool {
  lhs.wrappedValue?._$id == rhs.wrappedValue?._$id
}

// TODO: inlinable?
public func _$isIdentityEqual<T: ObservableState>(
  _ lhs: StackState<T>, _ rhs: StackState<T>
) -> Bool {
  areOrderedSetsDuplicates(lhs.ids, rhs.ids)
}

// TODO: inlinable?
// TODO: When is this hit?
@_disfavoredOverload
public func _$isIdentityEqual<C: Collection>(_ lhs: C, _ rhs: C) -> Bool
where C.Element: ObservableState {
  fatalError(
    """
    If you encounter this fatal error, please let us know on GitHub:

    https://github.com/pointfreeco/swift-composable-architecture
    """
  )
  // lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0._$id == $1._$id }
}

// TODO: inlinable?
// NB: This is a fast path so that String is not checked as a collection.
public func _$isIdentityEqual(_ lhs: String, _ rhs: String) -> Bool {
  false
}

// TODO: inlinable?
public func _$isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  func openCollection<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
    guard C.Element.self is ObservableState.Type else { return false }

    func openIdentifiable<Element: Identifiable>(_: Element.Type) -> Bool? {
      guard
        let lhs = lhs as? IdentifiedArrayOf<Element>,
        let rhs = rhs as? IdentifiedArrayOf<Element>
      else { return nil }
      return areOrderedSetsDuplicates(lhs.ids, rhs.ids)
    }

    if
      let identifiable = C.Element.self as? any Identifiable.Type,
      let result = openIdentifiable(identifiable)
    {
      return result
    } else if let rhs = rhs as? C {
      return lhs.count == rhs.count && zip(lhs, rhs).allSatisfy(_$isIdentityEqual)
    } else {
      return false
    }
  }

  if let lhs = lhs as? any ObservableState, let rhs = rhs as? any ObservableState {
    return lhs._$id == rhs._$id
  } else if let lhs = lhs as? any Collection {
    return openCollection(lhs, rhs)
  } else {
    return false
  }
}

public func _$willSet<T>(_: inout T) {}
public func _$willSet<T: ObservableState>(_ value: inout T) {
  value._$willSet()
}
public func _$didSet<T>(_: inout T) {}
public func _$didSet<T: ObservableState>(_ value: inout T) {
  value._$didSet()
}
