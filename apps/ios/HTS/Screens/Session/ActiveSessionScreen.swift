import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI
import UIKit

/// The active workout, over everything. Header with number, name, clock and one bullet per block; one page per block
/// and a last page to finish, like TrainHeroic (#108).
struct ActiveSessionScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: ActiveSessionModel
    @State private var confirmingFinish = false
    @State private var page: Int?
    @State private var completed: Completed?

    struct Completed {
        let completion: ProgressService.Completion
        let promotedArc: Arc?
        let nextWorkout: String?
    }

    private let database: AppDatabase

    init(database: AppDatabase, session: Session, defaultRestSeconds: Int) {
        self.database = database
        _model = State(
            initialValue: ActiveSessionModel(
                database: database, session: session, defaultRestSeconds: defaultRestSeconds))
    }

    var body: some View {
        if let completed {
            SessionCompleteView(
                completion: completed.completion, promotedArc: completed.promotedArc,
                nextWorkout: completed.nextWorkout
            ) { app.endWorkout() }
            .preferredColorScheme(.dark)
        } else {
            workout
        }
    }

    private var workout: some View {
        VStack(spacing: 0) {
            header
            pager
            pagerControls
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { RestFooter(model: model) }
        .background(Color.hts.black)
        .preferredColorScheme(.dark)
        .task {
            await model.load()
            page = model.firstPendingPage
            #if DEBUG
                // `-HTSDemoPage N` opens on page N (screenshots; the last page is Finalizar).
                if UserDefaults.standard.object(forKey: "HTSDemoPage") != nil {
                    page = min(UserDefaults.standard.integer(forKey: "HTSDemoPage"), finishPage)
                }
                // `-HTSDemoRest YES` starts a rest on the first exercise (screenshots).
                if UserDefaults.standard.bool(forKey: "HTSDemoRest"),
                    let exercise = model.snapshot.blocks.first(where: { $0.kind != .fightRound })?.exercises.first
                {
                    model.startRest(after: exercise)
                }
                // `-HTSDemoFinish YES` checks every set and finishes (screenshots of "Treino concluído").
                if UserDefaults.standard.bool(forKey: "HTSDemoFinish") {
                    for block in model.snapshot.blocks {
                        for exercise in block.exercises {
                            for set in model.rows(for: exercise) where !set.completed {
                                var heavier = set
                                heavier.weightKg = model.previous(for: exercise, setNumber: set.setNumber)?
                                    .weightKg.map { $0 + 5 }
                                model.update(heavier)
                                model.toggle(
                                    model.rows(for: exercise).first { $0.id == set.id } ?? heavier, exercise: exercise)
                            }
                        }
                    }
                    model.skipRest()
                    try? await Task.sleep(for: .milliseconds(300))
                    await finish()
                }
            #endif
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            HStack {
                IconButton(symbol: "chevron.down", label: "Minimizar treino") { app.showsActiveSession = false }
                Spacer()
                ElapsedClock(since: model.session.startedAt).htsTextStyle(.data).foregroundStyle(Color.hts.bone)
            }
            Text(numberLabel).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: "\(model.snapshot.letter) · \(model.snapshot.name)")
                .htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            PageBullets(model: model, current: currentPage) { go(to: $0) }
            if let error = model.error {
                Text(verbatim: error).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
            }
        }
        .padding(.horizontal, HTSSpacing.space5)
        .padding(.top, HTSSpacing.space4)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
    }

    /// One page per block and a last one to finish, swiped sideways or moved with the arrows (#108).
    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0...finishPage, id: \.self) { index in
                    ScrollView {
                        Group {
                            if index < finishPage {
                                BlockSection(model: model, block: model.snapshot.blocks[index], index: index)
                            } else {
                                finishPageContent
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, HTSSpacing.space5)
                        .padding(.vertical, HTSSpacing.space5)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .containerRelativeFrame(.horizontal)
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
    }

    private var pagerControls: some View {
        HStack {
            IconButton(symbol: "chevron.left", label: "Bloco anterior") { go(to: currentPage - 1) }
                .disabled(currentPage == 0)
                .opacity(currentPage == 0 ? 0.3 : 1)
            Spacer()
            Text(pageLabel).htsTextStyle(.label).foregroundStyle(Color.hts.grey).monospacedDigit()
            Spacer()
            IconButton(symbol: "chevron.right", label: "Próximo bloco") { go(to: currentPage + 1) }
                .disabled(currentPage == finishPage)
                .opacity(currentPage == finishPage ? 0.3 : 1)
        }
        .padding(.horizontal, HTSSpacing.space3)
        .overlay(alignment: .top) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
    }

    private var finishPage: Int { model.snapshot.blocks.count }
    private var currentPage: Int { page ?? 0 }

    private var pageLabel: LocalizedStringKey {
        currentPage == finishPage
            ? "FINALIZAR" : "BLOCO \(String(format: "%02d", currentPage + 1)) DE \(String(format: "%02d", finishPage))"
    }

    private func go(to index: Int) {
        withAnimation(.easeOut(duration: 0.25)) { page = min(max(index, 0), finishPage) }
    }

    /// Last slide: what was done, then Finalizar treino. Unchecked sets ask for confirmation on the page itself.
    private var finishPageContent: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space5) {
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                Text("FINALIZAR TREINO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                Text(
                    "\(String(format: "%02d", model.setCount - model.uncheckedCount)) de \(String(format: "%02d", model.setCount)) séries"
                )
                .htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone).monospacedDigit()
            }
            VStack(spacing: 0) {
                ForEach(Array(model.snapshot.blocks.enumerated()), id: \.element.blockId) { index, block in
                    Button {
                        go(to: index)
                    } label: {
                        HStack(spacing: HTSSpacing.space3) {
                            PageBullet(done: model.isDone(block), current: false)
                            Text(verbatim: String(format: "%02d", index + 1)).htsTextStyle(.dataSm)
                                .foregroundStyle(Color.hts.grey)
                            Text(verbatim: block.exercises.map(\.name).joined(separator: " + "))
                                .htsTextStyle(.body).foregroundStyle(Color.hts.bone).lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text(model.isDone(block) ? "Feito" : "Falta").htsTextStyle(.caption)
                                .foregroundStyle(Color.hts.greyApp)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
                }
            }
            if confirmingFinish {
                finishConfirmation
            } else {
                HTSButton("Finalizar treino") {
                    if model.uncheckedCount > 0 {
                        confirmingFinish = true
                    } else {
                        Task { await finish() }
                    }
                }
            }
        }
    }

    private var numberLabel: LocalizedStringKey {
        guard let number = model.number else { return "TREINO" }
        return "TREINO \(String(format: "%02d", number.inArc)) · TR \(String(format: "%02d", number.global))"
    }

    /// Asked on the screen itself, not in an alert, so it never blocks the set table.
    private var finishConfirmation: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            Text("\(model.uncheckedCount) séries não marcadas.").htsTextStyle(.bodyStrong)
                .foregroundStyle(Color.hts.redText)
            Text("Séries não marcadas não contam para o XP nem para o volume.")
                .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            HTSButton("Finalizar mesmo assim") { Task { await finish() } }
            HTSButton("Voltar ao treino", kind: .ghost) { confirmingFinish = false }
        }
        .padding(HTSSpacing.space5)
        .background(Color.hts.bloodDeep, in: NotchShape())
        .overlay(NotchShape().strokeBorder(Color.hts.blood, lineWidth: HTSStroke.hair))
    }

    private func finish() async {
        guard let session = await model.finish() else { return }
        let promoted = try? await ArcService(database).completeIfDone(arcId: session.arcId)
        guard let completion = try? await ProgressService(database).completion(sessionId: session.id) else {
            app.endWorkout()
            return
        }
        completed = Completed(
            completion: completion, promotedArc: promoted,
            nextWorkout: await nextWorkout(arcId: promoted?.id ?? session.arcId))
    }

    /// "B · Trincheira": the rotation after this session in the arc that is now current.
    private func nextWorkout(arcId: UUID) async -> String? {
        guard let plan = try? await PlanRepository(database).plan(arcId: arcId) else { return nil }
        let last = try? await SessionRepository(database).lastLetter(arcId: arcId)
        guard let letter = ArcSchedule(plan).next(after: last),
            let template = plan.templates.first(where: { $0.template.letter == letter })?.template
        else { return nil }
        return "\(template.letter) · \(template.name)"
    }
}

/// One square per block, filled `blood` when done and outlined when pending; the flag is the finish page. The
/// current page has a `bone` bar under it. Tapping one opens that page.
private struct PageBullets: View {
    let model: ActiveSessionModel
    let current: Int
    let select: (Int) -> Void

    var body: some View {
        let blocks = model.snapshot.blocks
        HStack(spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.element.blockId) { index, block in
                let done = model.isDone(block)
                button(index) { PageBullet(done: done, current: index == current) }
                    .accessibilityLabel(done ? "Bloco \(index + 1), feito" : "Bloco \(index + 1), falta")
            }
            button(blocks.count) {
                Image(systemName: "flag").font(.caption2).fontWeight(.light)
                    .foregroundStyle(current == blocks.count ? Color.hts.bone : Color.hts.grey)
            }
            .accessibilityLabel("Finalizar treino")
            Spacer(minLength: 0)
        }
    }

    private func button(_ index: Int, @ViewBuilder label: () -> some View) -> some View {
        Button {
            select(index)
        } label: {
            label()
                .frame(width: 28, height: 40)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(index == current ? Color.hts.bone : Color.clear)
                        .frame(width: 14, height: HTSStroke.rule)
                }
                .contentShape(Rectangle())
        }
    }
}

struct PageBullet: View {
    let done: Bool
    let current: Bool

    var body: some View {
        Rectangle()
            .fill(done ? Color.hts.blood : Color.clear)
            .overlay(Rectangle().strokeBorder(border, lineWidth: HTSStroke.hair))
            .frame(width: 10, height: 10)
    }

    private var border: Color {
        if done { return Color.hts.blood }
        return current ? Color.hts.bone : Color.hts.lineStrong
    }
}

private struct BlockSection: View {
    let model: ActiveSessionModel
    let block: PlanSnapshot.Block
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            HStack(spacing: HTSSpacing.space2) {
                Text(verbatim: String(format: "%02d", index + 1)).htsTextStyle(.label)
                Text(block.kind.label).textCase(.uppercase).htsTextStyle(.label)
                AttributeBadges(attributes: block.attributes)
            }
            .foregroundStyle(Color.hts.grey)
            if block.kind == .fightRound {
                FightRoundSection(model: model, block: block)
            } else {
                if block.kind == .combo || block.kind == .chainedCombo {
                    Text(
                        block.kind == .combo
                            ? "Em sequência. Descanso depois do último exercício."
                            : "Um logo após o outro, sem pausa. Descanso no fim."
                    )
                    .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
                ForEach(block.exercises, id: \.prescribedExerciseId) { exercise in
                    ExerciseTable(model: model, exercise: exercise)
                }
            }
        }
    }
}

private struct ExerciseTable: View {
    let model: ActiveSessionModel
    let exercise: PlanSnapshot.Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
            Text(verbatim: exercise.name).htsTextStyle(.uiSection).foregroundStyle(Color.hts.bone)
            Text(verbatim: prescription).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            HStack(spacing: HTSSpacing.space2) {
                Text("SÉRIE").lineLimit(1).fixedSize().frame(width: 52, alignment: .leading)
                Text("ANTERIOR").frame(maxWidth: .infinity, alignment: .leading)
                Text("KG").frame(width: 72)
                Text(amountHeader).frame(width: 64)
                Text(verbatim: "✓").frame(width: 44)
            }
            .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            ForEach(model.rows(for: exercise)) { set in
                SetRow(model: model, exercise: exercise, set: set)
            }
            Button {
                Task { await model.addSet(to: exercise) }
            } label: {
                Label("Adicionar série", systemImage: "plus").htsTextStyle(.caption)
                    .frame(minHeight: 44)
            }
            .foregroundStyle(Color.hts.bone)
        }
    }

    private var amountHeader: LocalizedStringKey {
        switch exercise.unit {
        case .reps: "REPS"
        case .seconds: "SEG"
        case .minutes: "MIN"
        case .meters: "M"
        }
    }

    private var prescription: String {
        var parts = [
            "\(TargetNotation.formatSets(min: exercise.setsMin, max: exercise.setsMax)) × "
                + TargetNotation.format(exercise.targets, unit: exercise.unit, perSide: exercise.perSide)
        ]
        if let hint = LoadGuide.hint(for: exercise.targets, unit: exercise.unit) { parts.append(hint.label) }
        if let rest = exercise.restSeconds { parts.append("desc. \(rest) s") }
        return parts.joined(separator: " · ")
    }
}

private struct SetRow: View {
    let model: ActiveSessionModel
    let exercise: PlanSnapshot.Exercise
    let set: LoggedSet

    var body: some View {
        let previous = model.previous(for: exercise, setNumber: set.setNumber)
        let target = exercise.targets.target(forSet: set.setNumber - 1)
        HStack(spacing: HTSSpacing.space2) {
            Text(verbatim: String(format: "%02d", set.setNumber)).htsTextStyle(.dataSm)
                .frame(width: 52, alignment: .leading)
            Text(verbatim: previous?.summary(unit: exercise.unit) ?? "—").htsTextStyle(.dataSm)
                .foregroundStyle(Color.hts.greyApp)
                .frame(maxWidth: .infinity, alignment: .leading)
            NumberField(
                value: set.weightKg, prompt: previous?.weightKg.map(LoggedSet.format) ?? "kg",
                keyboard: .decimalPad, done: set.completed
            ) { value in
                var changed = set
                changed.weightKg = value
                model.update(changed)
            }
            .frame(width: 72)
            NumberField(
                value: amount, prompt: SetRules.defaultAmount(for: target).map(LoggedSet.format) ?? "máx",
                keyboard: exercise.unit == .meters ? .decimalPad : .numberPad, done: set.completed
            ) { value in
                model.update(with(amount: value))
            }
            .frame(width: 64)
            Button {
                model.toggle(set, exercise: exercise)
            } label: {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(set.completed ? Color.hts.black : Color.clear)
                    .frame(width: 32, height: 32)
                    .background(set.completed ? Color.hts.bone : Color.clear)
                    .overlay(Rectangle().strokeBorder(set.completed ? Color.clear : Color.hts.lineStrong))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(set.completed ? "Desmarcar série \(set.setNumber)" : "Concluir série \(set.setNumber)")
        }
        .foregroundStyle(Color.hts.bone)
        .contextMenu {
            Button("Remover série", role: .destructive) { Task { await model.remove(set) } }
        }
    }

    private var amount: Decimal? {
        switch exercise.unit {
        case .reps: set.reps.map { Decimal($0) }
        case .seconds: set.seconds.map { Decimal($0) }
        case .minutes: set.seconds.map { Decimal($0) / 60 }
        case .meters: set.meters
        }
    }

    private func with(amount value: Decimal?) -> LoggedSet {
        var changed = set
        let int = value.map { NSDecimalNumber(decimal: $0).intValue }
        switch exercise.unit {
        case .reps: changed.reps = int
        case .seconds: changed.seconds = int
        case .minutes: changed.seconds = value.map { NSDecimalNumber(decimal: $0 * 60).intValue }
        case .meters: changed.meters = value
        }
        return changed
    }
}

/// Numeric field that keeps its own text while typing and reports parsed decimals (comma or dot).
struct NumberField: View {
    let value: Decimal?
    let prompt: String
    let keyboard: UIKeyboardType
    /// Completed set: the value is final, shown in `bone` on `track` (#104).
    var done = false
    let onChange: (Decimal?) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(text: $text, prompt: Text(verbatim: prompt).foregroundStyle(Color.hts.tabIdle)) {
            Text(verbatim: prompt)
        }
        .keyboardType(keyboard)
        .focused($focused)
        .multilineTextAlignment(.center)
        .htsTextStyle(.dataSm)
        .fontWeight(done ? .semibold : nil)
        .foregroundStyle(Color.hts.bone)
        .frame(minHeight: 44)
        .background(done ? Color.hts.track : Color.hts.surface)
        .onAppear { text = value.map(LoggedSet.format) ?? "" }
        .onChange(of: value) { _, newValue in
            // Also while focused: checking a set fills the empty field with its placeholder value (#104).
            if Self.parse(text) != newValue { text = newValue.map(LoggedSet.format) ?? "" }
        }
        .onChange(of: text) { _, newText in
            let parsed = Self.parse(newText)
            if newText.isEmpty || parsed != nil, parsed != value { onChange(parsed) }
        }
    }

    /// "62,5" or "62.5" → 62.5; empty or invalid → nil.
    static func parse(_ text: String) -> Decimal? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return normalized.isEmpty ? nil : Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// "32:10", ticking every second from `since`.
struct ElapsedClock: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(verbatim: Self.format(context.date.timeIntervalSince(since)))
                .monospacedDigit()
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let (hours, minutes, seconds) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
}

/// "Treino em andamento · 32:10" above the tabs while the workout is minimized.
struct ActiveSessionBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let session = app.activeSession, !app.showsActiveSession {
            Button {
                app.showsActiveSession = true
            } label: {
                HStack(spacing: HTSSpacing.space3) {
                    Text("Treino em andamento").htsTextStyle(.bodyStrong)
                    Text(verbatim: "·")
                    ElapsedClock(since: session.startedAt).htsTextStyle(.dataSm)
                    Spacer()
                    Image(systemName: "chevron.up").fontWeight(.light)
                }
                .foregroundStyle(Color.hts.bone)
                .padding(.horizontal, HTSSpacing.space5)
                .frame(minHeight: 52)
                .background(Color.hts.surface)
                .overlay(alignment: .top) { Rectangle().fill(Color.hts.blood).frame(height: HTSStroke.rule) }
            }
            .accessibilityLabel("Abrir treino em andamento")
        }
    }
}
