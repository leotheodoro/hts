import HTSDomain
import SwiftUI

// pt-BR names of domain values, as the handoff uses them.

extension BlockKind {
    var label: LocalizedStringKey {
        switch self {
        case .activation: "Ativação"
        case .strength: "Força"
        case .combo: "Combo"
        case .chainedCombo: "Combo Encadeado"
        case .fightRound: "Round de Luta"
        case .conditioning: "Condicionamento"
        case .core: "Core"
        case .mobility: "Mobilidade"
        case .cardio: "Cardio"
        }
    }
}

extension Attribute {
    /// FOR, EXP, GÁS, NÚC, MOB.
    var abbreviation: String {
        switch self {
        case .strength: "FOR"
        case .power: "EXP"
        case .conditioning: "GÁS"
        case .core: "NÚC"
        case .mobility: "MOB"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .strength: "Força"
        case .power: "Explosão"
        case .conditioning: "Resistência"
        case .core: "Núcleo"
        case .mobility: "Mobilidade"
        }
    }
}

extension ExerciseUnit {
    var shortLabel: LocalizedStringKey {
        switch self {
        case .reps: "Reps"
        case .seconds: "Seg"
        case .minutes: "Min"
        case .meters: "M"
        }
    }
}
