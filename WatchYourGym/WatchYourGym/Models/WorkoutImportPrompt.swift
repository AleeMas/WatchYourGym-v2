//
//  WorkoutImportPrompt.swift
//  WatchYourGym
//
//  The prompt the user copies into an AI assistant together with a photo of
//  their training plan. It lives next to WorkoutImport.swift on purpose:
//  if the accepted schema changes, both must change together.
//

import Foundation

enum WorkoutImportPrompt {

    static let text = """
    You convert a photo of a gym training plan into JSON for the WatchYourGym iOS app.

    Read the attached image and return ONLY the JSON object, with no explanation \
    and no markdown code fences.

    SCHEMA
    {
      "name": "string - the name of the plan, e.g. Push Day",
      "type": "tab" or "circuit",
      "rounds": integer,
      "restBetweenExercises": integer,
      "exercises": [
        {
          "name": "string - the exercise, e.g. Bench press",
          "muscle": "string - the muscle group, e.g. Chest",
          "weightKg": integer,
          "sets": integer,
          "reps": integer,
          "repsType": "reps" or "seconds",
          "restSeconds": integer,
          "notes": "string",
          "superset": {
            "name": "string",
            "muscle": "string",
            "weightKg": integer,
            "reps": integer,
            "repsType": "reps" or "seconds",
            "notes": "string"
          }
        }
      ]
    }

    RULES
    1. "type": use "circuit" only when the plan repeats the WHOLE list of \
    exercises several times in a row. Use "tab" for a normal plan where each \
    exercise finishes all of its sets before the next one starts.
    2. "rounds": how many times the whole circuit is repeated. Only for \
    "circuit"; use 1 for "tab".
    3. "sets": how many sets of that single exercise. Only for "tab"; use 1 \
    for "circuit" (in a circuit each exercise is performed once per round).
    4. "restBetweenExercises": for "tab", the rest between one exercise and the \
    next; for "circuit", the rest between one round and the next.
    5. "restSeconds": for "tab", the rest between the sets of that exercise; \
    for "circuit", the rest after that exercise inside the round.
    6. All times are integer SECONDS. Convert "1:30" or "1 min 30" to 90.
    7. "repsType": use "seconds" when the exercise is held or timed \
    (for example plank 30"), otherwise "reps".
    8. If a value is a range such as "8-12", use the lower number.
    9. If a value is missing or unreadable in the photo, use 0 for numbers and \
    "" for text. Never invent weights or rest times that are not written.
    10. Keep the exercises in the same order as the plan.
    11. "superset" is OPTIONAL and only for "tab" plans. Use it when two \
    exercises are marked as a superset (often written "SS", "superset", \
    "A1/A2" or joined with a "+"): they are done back to back with no rest \
    in between, and one set means doing both. Put the FIRST exercise as a \
    normal exercise with its "sets" and "restSeconds", and the SECOND one \
    inside its "superset" object. The second exercise has its own "reps", \
    "repsType", "weightKg", "muscle" and "notes" but NO "sets" and NO \
    "restSeconds" (they are shared). Omit "superset" entirely for exercises \
    that are not part of a superset.
    12. Do not add any field that is not in the schema and do not add an "id".

    EXAMPLE OUTPUT
    {
      "name": "Push Day",
      "type": "tab",
      "rounds": 1,
      "restBetweenExercises": 120,
      "exercises": [
        {
          "name": "Bench press",
          "muscle": "Chest",
          "weightKg": 60,
          "sets": 4,
          "reps": 10,
          "repsType": "reps",
          "restSeconds": 90,
          "notes": "Slow on the way down"
        },
        {
          "name": "Incline dumbbell press",
          "muscle": "Chest",
          "weightKg": 22,
          "sets": 3,
          "reps": 10,
          "repsType": "reps",
          "restSeconds": 90,
          "notes": "",
          "superset": {
            "name": "Push up",
            "muscle": "Chest",
            "weightKg": 0,
            "reps": 15,
            "repsType": "reps",
            "notes": "To failure on the last set"
          }
        },
        {
          "name": "Plank",
          "muscle": "Core",
          "weightKg": 0,
          "sets": 3,
          "reps": 45,
          "repsType": "seconds",
          "restSeconds": 60,
          "notes": ""
        }
      ]
    }

    Save the answer as a .json file.
    """
}
