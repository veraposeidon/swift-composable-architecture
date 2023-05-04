import ComposableArchitecture
import XCTest

@testable import Standups

@MainActor
final class AppFeatureTests: XCTestCase {
  func testDelete() async throws {
    let standup = Standup.mock

    let store = TestStore(
      initialState: AppFeature.State(),
      reducer: AppFeature()
    ) {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock(
        initialData: try! JSONEncoder().encode([standup])
      )
    }

    await store.send(.path(.push(id: 0, state: .detail(StandupDetail.State(standup: standup))))) {
      $0.path[id: 0] = .detail(StandupDetail.State(standup: standup))
    }

    await store.send(.path(.element(id: 0, action: .detail(.deleteButtonTapped)))) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = .alert(.deleteStandup)
      }
    }

    await store.send(
      .path(.element(id: 0, action: .detail(.destination(.presented(.alert(.confirmDeletion))))))
    ) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = nil
      }
    }

    await store.receive(.path(.element(id: 0, action: .detail(.delegate(.deleteStandup))))) {
      $0.path = StackState()
      $0.standupsList.standups = []
    }
  }

  func testDetailEdit() async throws {
    let standup = Standup.mock

    let store = TestStore(
      initialState: AppFeature.State(),
      reducer: AppFeature()
    ) {
      $0.continuousClock = ImmediateClock()
      $0.dataManager = .mock(
        initialData: try! JSONEncoder().encode([standup])
      )
    }

    let savedData = LockIsolated(Data?.none)
    store.dependencies.dataManager.save = { data, _ in savedData.setValue(data) }

    await store.send(.path(.push(id: 0, state: .detail(StandupDetail.State(standup: standup))))) {
      $0.path[id: 0] = .detail(StandupDetail.State(standup: standup))
    }

    await store.send(.path(.element(id: 0, action: .detail(.editButtonTapped)))) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = .edit(StandupForm.State(standup: standup))
      }
    }

    await store.send(
      .path(
        .element(
          id: 0,
          action: .detail(.destination(.presented(.edit(.binding(.set(\.$standup.title, "Blob"))))))
        )
      )
    ) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        XCTModify(&$0.destination, case: /StandupDetail.Destination.State.edit) {
          $0.standup.title = "Blob"
        }
      }
    }

    await store.send(.path(.element(id: 0, action: .detail(.doneEditingButtonTapped)))) {
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.destination = nil
        $0.standup.title = "Blob"
      }
      $0.standupsList.standups[0].title = "Blob"
    }

    await store.send(.path(.popFrom(id: 0))) {
      $0.path = StackState()
    }
  }

  func testRecording() async {
    let speechResult = SpeechRecognitionResult(
      bestTranscription: Transcription(formattedString: "I completed the project"),
      isFinal: true
    )
    let standup = Standup(
      id: Standup.ID(),
      attendees: [
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
      ],
      duration: .seconds(6)
    )

    let store = TestStore(
      initialState: AppFeature.State(
        path: StackState([
          .detail(StandupDetail.State(standup: standup)),
          .record(RecordMeeting.State(standup: standup))
        ])
      ),
      reducer: AppFeature()
    ) {
      $0.dataManager = .mock(initialData: try! JSONEncoder().encode([standup]))
      $0.date.now = Date(timeIntervalSince1970: 1234567890)
      $0.continuousClock = ImmediateClock()
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { _ in
        AsyncThrowingStream { continuation in
          continuation.yield(speechResult)
          continuation.finish()
        }
      }
      $0.uuid = .incrementing
    }

    await store.send(.path(.element(id: 1, action: .record(.task))))

    await store.receive(.path(.element(id: 1, action: .record(.speechResult(speechResult))))) {
      XCTModify(&$0.path[id: 1], case: /AppFeature.Path.State.record) {
        $0.transcript = "I completed the project"
      }
    }

    store.exhaustivity = .off(showSkippedAssertions: true)
    await store.receive(.path(.element(id: 1, action: .record(.timerTick))))
    await store.receive(.path(.element(id: 1, action: .record(.timerTick))))
    await store.receive(.path(.element(id: 1, action: .record(.timerTick))))
    await store.receive(.path(.element(id: 1, action: .record(.timerTick))))
    await store.receive(.path(.element(id: 1, action: .record(.timerTick))))
    await store.receive(.path(.element(id: 1, action: .record(.timerTick))))
    store.exhaustivity = .on

    await store.receive(
      .path(
        .element(id: 1, action: .record(.delegate(.save(transcript: "I completed the project"))))
      )
    ) {
      // TODO: this shows confusing "expected failure" when in non-exhaustive mode... can we do better?
      // XCTAssertEqual($0.path.count, 1)

      $0.path.removeLast()
      XCTModify(&$0.path[id: 0], case: /AppFeature.Path.State.detail) {
        $0.standup.meetings = [
          Meeting(
            id: Meeting.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            date: Date(timeIntervalSince1970: 1234567890),
            transcript: "I completed the project"
          )
        ]
      }
      $0.standupsList.standups[0].meetings = [
        Meeting(
          id: Meeting.ID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          date: Date(timeIntervalSince1970: 1234567890),
          transcript: "I completed the project"
        )
      ]
    }
    XCTAssertEqual(store.state.path.count, 1)
  }
}

// TODO: integration test for recording
