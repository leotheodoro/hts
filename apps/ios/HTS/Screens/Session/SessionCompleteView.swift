import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// "Treino concluído": XP earned, level bar, sets, volume, time, records and the next workout. A new rank gets its
/// own screen first.
struct SessionCompleteView: View {
    let completion: ProgressService.Completion
    /// The arc that became current because this session closed the previous one.
    let promotedArc: Arc?
    let nextWorkout: String?
    let onClose: () -> Void

    @State private var showsRankUp: Bool

    init(
        completion: ProgressService.Completion, promotedArc: Arc?, nextWorkout: String?, onClose: @escaping () -> Void
    ) {
        self.completion = completion
        self.promotedArc = promotedArc
        self.nextWorkout = nextWorkout
        self.onClose = onClose
        _showsRankUp = State(initialValue: completion.rankedUp)
    }

    var body: some View {
        if showsRankUp {
            RankUpView(rank: completion.after.rank, level: completion.after.level) { showsRankUp = false }
        } else {
            summary
        }
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                    Text("TREINO CONCLUÍDO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Text(
                        verbatim: "\(completion.session.planSnapshot.letter) · \(completion.session.planSnapshot.name)"
                    )
                    .htsTextStyle(.uiTitle)
                }
                XPProgressCard(completion: completion)
                stats
                if !completion.recordNames.isEmpty { records }
                if !completion.newTitles.isEmpty {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        Text("TÍTULO DESBLOQUEADO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        ForEach(completion.newTitles, id: \.self) { title in
                            Text(title.name).htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.oliveInk)
                                .padding(.horizontal, HTSSpacing.space3).padding(.vertical, HTSSpacing.space2)
                                .background(Color.hts.olive)
                        }
                    }
                }
                if let promotedArc { arcCard(promotedArc) }
                if let nextWorkout {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        Text("PRÓXIMO TREINO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        Text(verbatim: nextWorkout).htsTextStyle(.uiSection)
                    }
                }
                HTSButton("Voltar para Home", action: onClose)
            }
            .foregroundStyle(Color.hts.bone)
            .padding(.horizontal, HTSSpacing.space5)
            .padding(.vertical, HTSSpacing.space8)
        }
        .background(Color.hts.black)
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: HTSSpacing.space4) {
            stat("SÉRIES", String(format: "%02d", completion.progress.completedSets))
            stat("VOLUME", "\(LoggedSet.format(completion.progress.volumeKg)) kg")
            stat("TEMPO", ElapsedClock.format(completion.session.duration ?? 0))
        }
    }

    private var records: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
            Text("LIMITE QUEBRADO").htsTextStyle(.label).foregroundStyle(Color.hts.redText)
            ForEach(completion.recordNames, id: \.self) { name in
                Text(verbatim: name).htsTextStyle(.bodyStrong)
            }
        }
    }

    private func arcCard(_ arc: Arc) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                Text("ARCO CONCLUÍDO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                Text("Próximo arco: \(arc.name)").htsTextStyle(.uiSection)
            }
        }
    }

    private func stat(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
            Text(label).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: value).htsTextStyle(.data)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// XP earned with the level bar filling from before to after; then each attribute this session fed appears below,
/// smaller, one at a time with the same fill (#89). Reduce Motion shows the end state at once.
struct XPProgressCard: View {
    let completion: ProgressService.Completion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownXp: Double
    @State private var revealed = 0
    @State private var attributeXp: [Attribute: Double] = [:]

    init(completion: ProgressService.Completion) {
        self.completion = completion
        _shownXp = State(initialValue: Double(completion.before.totalXp))
    }

    var body: some View {
        let progress = completion.progress
        let rules = Progression().rules.xp
        let level = Progression().levelProgress(xp: Int(shownXp.rounded()))
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text(verbatim: "+\(progress.xp) XP").htsTextStyle(.uiDisplay)
                row("Séries", "+\(progress.completedSets * rules.setCompleted)")
                row("Treino concluído", "+\(rules.sessionCompleted)")
                if !progress.records.isEmpty {
                    row("Limite Quebrado", "+\(progress.records.count * rules.personalRecord)")
                }
                row(
                    "Volume",
                    "+\(progress.xp - progress.completedSets * rules.setCompleted - rules.sessionCompleted - progress.records.count * rules.personalRecord)"
                )
                HStack {
                    Text(level.level > completion.before.level ? "NOVO NÍVEL \(level.level)" : "NÍVEL \(level.level)")
                        .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Spacer()
                    Text(verbatim: "\(Int(shownXp.rounded())) / \(level.end) XP").htsTextStyle(.dataSm)
                        .monospacedDigit()
                }
                ProgressBar(value: level.fraction, highlighted: true)
                    .frame(height: HTSStroke.bar)
                ForEach(completion.attributeGains.prefix(revealed), id: \.self) { attribute in
                    attributeRow(attribute)
                        .transition(.opacity)
                }
            }
        }
        .task { await play() }
    }

    private func attributeRow(_ attribute: Attribute) -> some View {
        let before = completion.attributesBefore[attribute]?.xp ?? 0
        let after = completion.attributesAfter[attribute]?.xp ?? 0
        let xp = Int((attributeXp[attribute] ?? Double(before)).rounded())
        let level = Progression().levelProgress(xp: xp)
        return VStack(alignment: .leading, spacing: HTSSpacing.space1) {
            HStack(spacing: HTSSpacing.space2) {
                Text(verbatim: attribute.abbreviation).htsTextStyle(.label)
                Text(attribute.label).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                Spacer()
                Text(verbatim: "+\(after - before) XP").htsTextStyle(.dataSm).monospacedDigit()
                Text("NÍV \(level.level)").htsTextStyle(.label).foregroundStyle(Color.hts.grey).monospacedDigit()
            }
            ProgressBar(value: level.fraction)
        }
        .padding(.top, HTSSpacing.space2)
    }

    private func play() async {
        let gains = completion.attributeGains
        let after = Double(completion.after.totalXp)
        guard !reduceMotion else {
            shownXp = after
            for attribute in gains { attributeXp[attribute] = Double(completion.attributesAfter[attribute]?.xp ?? 0) }
            revealed = gains.count
            return
        }
        await count(from: shownXp, to: after, seconds: 1.2) { shownXp = $0 }
        for attribute in gains {
            let from = Double(completion.attributesBefore[attribute]?.xp ?? 0)
            attributeXp[attribute] = from
            withAnimation(.easeOut(duration: 0.2)) { revealed += 1 }
            await count(
                from: from, to: Double(completion.attributesAfter[attribute]?.xp ?? 0), seconds: 0.7
            ) { attributeXp[attribute] = $0 }
        }
    }

    /// Steps a value with an ease-out curve, about 60 times a second. Level-ups wrap the bar on the way.
    private func count(from: Double, to: Double, seconds: Double, set: (Double) -> Void) async {
        let steps = max(Int(seconds * 60), 1)
        for step in 1...steps {
            try? await Task.sleep(for: .milliseconds(16))
            if Task.isCancelled { return }
            let t = Double(step) / Double(steps)
            set(from + (to - from) * (1 - pow(1 - t, 3)))
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            Spacer()
            Text(verbatim: value).htsTextStyle(.dataSm)
        }
    }
}

/// Moment screen for a new rank (E Recruta → D Soldado…), different from a new level.
struct RankUpView: View {
    let rank: Rank
    let level: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: HTSSpacing.space6) {
            Spacer()
            Text("NOVA PATENTE").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: rank.id.rawValue).htsTextStyle(.pieceTitle)
                .font(.custom(HTSFontFamily.display.postScriptName(weight: 900), size: HTSTextStyle.brandStack.size))
                .foregroundStyle(Color.hts.bone)
            Text(verbatim: rank.name.uppercased()).htsTextStyle(.pieceSub).foregroundStyle(Color.hts.khaki)
            Text("Nível \(level)").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            Spacer()
            HTSButton("Continuar", action: onContinue)
        }
        .padding(HTSSpacing.space5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hts.black)
    }
}
