import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI
import UIKit

/// The active workout, over everything. Header with number, name, clock and Finalizar; one table per exercise.
struct ActiveSessionScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: ActiveSessionModel
    @State private var confirmingFinish = false

    init(database: AppDatabase, session: Session, defaultRestSeconds: Int) {
        _model = State(
            initialValue: ActiveSessionModel(
                database: database, session: session, defaultRestSeconds: defaultRestSeconds))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                header
                if confirmingFinish { finishConfirmation }
                ForEach(Array(model.snapshot.blocks.enumerated()), id: \.element.blockId) { index, block in
                    BlockSection(model: model, block: block, index: index)
                }
                if let error = model.error {
                    Text(verbatim: error).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
                }
            }
            .padding(.horizontal, HTSSpacing.space5)
            .padding(.vertical, HTSSpacing.space4)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { RestFooter(model: model) }
        .background(Color.hts.black)
        .preferredColorScheme(.dark)
        .task {
            await model.load()
            #if DEBUG
                // `-HTSDemoRest YES` starts a rest on the first exercise (screenshots).
                if UserDefaults.standard.bool(forKey: "HTSDemoRest"),
                    let exercise = model.snapshot.blocks.first(where: { $0.kind != .fightRound })?.exercises.first
                {
                    model.startRest(after: exercise)
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
            HTSButton("Finalizar", kind: .ghost) {
                if model.uncheckedCount > 0 {
                    confirmingFinish = true
                } else {
                    Task { await finish() }
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
        if await model.finish() != nil {
            app.endWorkout()
        }
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
                Text(verbatim: block.attributes.map(\.abbreviation).joined(separator: " ")).htsTextStyle(.label)
            }
            .foregroundStyle(Color.hts.grey)
            if block.kind == .fightRound {
                Text("Round de Luta: o registro de rounds chega no próximo ticket.")
                    .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            } else {
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
                keyboard: .decimalPad
            ) { value in
                var changed = set
                changed.weightKg = value
                model.update(changed)
            }
            .frame(width: 72)
            NumberField(
                value: amount, prompt: SetRules.defaultAmount(for: target).map(LoggedSet.format) ?? "máx",
                keyboard: exercise.unit == .meters ? .decimalPad : .numberPad
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
        .foregroundStyle(set.completed ? Color.hts.greyApp : Color.hts.bone)
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
private struct NumberField: View {
    let value: Decimal?
    let prompt: String
    let keyboard: UIKeyboardType
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
        .frame(minHeight: 44)
        .background(Color.hts.surface)
        .onAppear { text = value.map(LoggedSet.format) ?? "" }
        .onChange(of: value) { _, newValue in
            if !focused { text = newValue.map(LoggedSet.format) ?? "" }
        }
        .onChange(of: text) { _, newText in
            let normalized = newText.replacingOccurrences(of: ",", with: ".")
            let parsed =
                normalized.isEmpty ? nil : Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
            if normalized.isEmpty || parsed != nil, parsed != value { onChange(parsed) }
        }
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
