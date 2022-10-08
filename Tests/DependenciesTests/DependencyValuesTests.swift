import ComposableArchitecture
import XCTest

extension DependencyValues {
  fileprivate var missingLiveDependency: Int {
    get { self[TestKey.self] }
    set { self[TestKey.self] = newValue }
  }
}

private enum TestKey: TestDependencyKey {
  static let testValue = 42
}

final class DependencyValuesTests: XCTestCase {
  func testMissingLiveValue() {
    #if DEBUG
      var line = 0
      XCTExpectFailure {
        var values = DependencyValues._current
        values.context = .live
        DependencyValues.$_current.withValue(values) {
          line = #line + 1
          @Dependency(\.missingLiveDependency) var missingLiveDependency: Int
          _ = missingLiveDependency
        }
      } issueMatcher: {
        $0.compactDescription == """
          @Dependency(\\.missingLiveDependency) has no live implementation, but was accessed from \
          a live context.

            Location:
              DependenciesTests/DependencyValuesTests.swift:\(line)
            Key:
              TestKey
            Value:
              Int

          Every dependency registered with the library must conform to 'DependencyKey', and that \
          conformance must be visible to the running application.

          To fix, make sure that 'TestKey' conforms to 'DependencyKey' by providing a live \
          implementation of your dependency, and make sure that the conformance is linked with \
          this current application.
          """
      }
    #endif
  }

  func testWithValues() {
    let date = DependencyValues.withValues {
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
    } operation: {
      @Dependency(\.date) var date
      return date.now
    }

    let defaultDate = DependencyValues.withValues {
      $0.context = .live
    } operation: {
      @Dependency(\.date) var date
      return date.now
    }

    XCTAssertEqual(date, Date(timeIntervalSince1970: 1234567890))
    XCTAssertNotEqual(
      defaultDate,
      Date(timeIntervalSince1970: 1234567890)
    )
  }

  func testWithValue() {
    DependencyValues.withValue(\.context, .live) {
      let date = DependencyValues.withValue(\.date.now,  Date(timeIntervalSince1970: 1234567890)) {
        @Dependency(\.date) var date
        return date.now
      }

      XCTAssertEqual(date, Date(timeIntervalSince1970: 1234567890))
      XCTAssertNotEqual(
        DependencyValues._current.date.now,
        Date(timeIntervalSince1970: 1234567890)
      )
    }
  }
}
