import Foundation

/// What the arc form edits. Saving turns it into arc and workout template rows.
public struct ArcDraft: Hashable, Sendable {
    public struct Template: Hashable, Sendable, Identifiable {
        public enum Origin: Hashable, Sendable {
            /// A template already in this arc (editing).
            case existing(UUID)
            /// A new empty template; blocks are added in the template editor.
            case new
            /// A copy of a template from another arc (docs/decisions/0015).
            case reuse(UUID)
        }

        public let id: UUID
        public var origin: Origin
        public var name: String
        public var focus: String?

        public init(id: UUID = UUID(), origin: Origin, name: String, focus: String? = nil) {
            self.id = id
            self.origin = origin
            self.name = name
            self.focus = focus
        }
    }

    /// Nil when creating.
    public var arcId: UUID?
    public var name: String
    public var kanji: String
    public var program: String
    public var kind: ArcKind
    public var weeks: Int
    public var startDate: LocalDate
    /// In order; letters follow it.
    public var templates: [Template]

    public init(
        arcId: UUID? = nil, name: String = "", kanji: String = "", program: String = "", kind: ArcKind = .normal,
        weeks: Int = 4, startDate: LocalDate, templates: [Template] = []
    ) {
        self.arcId = arcId
        self.name = name
        self.kanji = kanji
        self.program = program
        self.kind = kind
        self.weeks = weeks
        self.startDate = startDate
        self.templates = templates
    }

    public init(_ plan: ArcPlan, today: LocalDate) {
        self.init(
            arcId: plan.arc.id, name: plan.arc.name, kanji: plan.arc.kanji ?? "", program: plan.arc.program ?? "",
            kind: plan.arc.kind, weeks: plan.arc.weeks ?? 4, startDate: plan.arc.startDate ?? today,
            templates: plan.templates.map {
                Template(origin: .existing($0.template.id), name: $0.template.name, focus: $0.template.focus)
            })
    }

    /// Filler arcs have no duration.
    public var hasDuration: Bool { kind != .filler }

    public var schedule: ArcSchedule {
        ArcSchedule(
            letters: templates.indices.map(TemplateLetter.letter(at:)), weeks: hasDuration ? weeks : nil,
            startDate: hasDuration ? startDate : nil)
    }

    public var isValid: Bool {
        // Every arc has a kanji (#79).
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !kanji.trimmingCharacters(in: .whitespaces).isEmpty
            && !templates.isEmpty
            && templates.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            && (!hasDuration || (1...52).contains(weeks))
    }
}
