import Foundation
import Testing

@testable import HTSDomain

/// Observações in the session snapshot (#212).
@Suite struct PlanSnapshotNotesTests {
    func json(notes: String?) -> Data {
        let exercise: [String: Any?] = [
            "prescribedExerciseId": "01a18daf-f5ba-772f-a021-96fd16087a3d",
            "exerciseId": "01a18daf-f5ba-772f-a021-96fd16087a3e", "name": "Back Squat", "unit": "reps",
            "perSide": false, "setsMin": 1, "setsMax": 1, "targets": [["type": "fixed", "value": 20]],
            "restSeconds": nil,
        ]
        var withNotes = exercise.compactMapValues { $0 }
        withNotes["restSeconds"] = NSNull()
        if let notes { withNotes["notes"] = notes }
        let snapshot: [String: Any] = [
            "workoutTemplateId": "01a18daf-f5ba-772f-a021-96fd16087a3f", "letter": "A", "name": "Pernas",
            "focus": NSNull(),
            "blocks": [
                [
                    "blockId": "01a18daf-f5ba-772f-a021-96fd16087a40", "kind": "strength",
                    "attributes": ["strength"], "durationMinutes": NSNull(), "exercises": [withNotes],
                ]
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: snapshot)
    }

    @Test func snapshotsFromBeforeNotesStillDecode() throws {
        let snapshot = try JSONDecoder().decode(PlanSnapshot.self, from: json(notes: nil))
        #expect(snapshot.blocks[0].exercises[0].notes == nil)
    }

    @Test func notesRoundTrip() throws {
        let snapshot = try JSONDecoder().decode(PlanSnapshot.self, from: json(notes: "Widow Maker."))
        #expect(snapshot.blocks[0].exercises[0].notes == "Widow Maker.")
        let again = try JSONDecoder().decode(PlanSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(again.blocks[0].exercises[0].notes == "Widow Maker.")
    }
}
