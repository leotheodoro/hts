import GRDB
import HTSDomain

// Domain entities are plain HTSDomain types; storage is added here so the domain stays free of GRDB.
extension Season: HTSRecord { public static let databaseTableName = "season" }
extension Arc: HTSRecord { public static let databaseTableName = "arc" }
extension WorkoutTemplate: HTSRecord { public static let databaseTableName = "workout_template" }
extension Block: HTSRecord { public static let databaseTableName = "block" }
extension Exercise: HTSRecord { public static let databaseTableName = "exercise" }
extension PrescribedExercise: HTSRecord { public static let databaseTableName = "prescribed_exercise" }
extension Session: HTSRecord { public static let databaseTableName = "session" }
extension LoggedSet: HTSRecord { public static let databaseTableName = "logged_set" }
extension LoggedRound: HTSRecord { public static let databaseTableName = "logged_round" }
extension Battle: HTSRecord { public static let databaseTableName = "battle" }
extension ImportedActivity: HTSRecord { public static let databaseTableName = "imported_activity" }
