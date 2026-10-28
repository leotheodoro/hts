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
                xp
                stats
                if !completion.recordNames.isEmpty { records }
                if let promotedArc { arcCard(promotedArc) }
                if let nextWorkout {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        Text("PRÓXIMO TREINO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        Text(verbatim: nextWorkout).htsTextStyle(.uiSection)
                    }
                }
                HTSButton("Voltar ao Status", action: onClose)
            }
            .foregroundStyle(Color.hts.bone)
            .padding(.horizontal, HTSSpacing.space5)
            .padding(.vertical, HTSSpacing.space8)
        }
        .background(Color.hts.black)
    }

    private var xp: some View {
        let progress = completion.progress
        let rules = Progression().rules.xp
        let level = Progression().levelProgress(xp: completion.after.totalXp)
        return NotchCard {
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
                    Text(completion.leveledUp ? "NOVO NÍVEL \(level.level)" : "NÍVEL \(level.level)")
                        .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Spacer()
                    Text(verbatim: "\(completion.after.totalXp) / \(level.end) XP").htsTextStyle(.dataSm)
                }
                ProgressBar(value: level.fraction, highlighted: true)
                    .frame(height: HTSStroke.bar)
            }
        }
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

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            Spacer()
            Text(verbatim: value).htsTextStyle(.dataSm)
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
