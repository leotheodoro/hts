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
    /// FOR, EXP, GÁS, COR, MOB.
    var abbreviation: String {
        switch self {
        case .strength: "FOR"
        case .power: "EXP"
        case .conditioning: "GÁS"
        case .core: "COR"
        case .mobility: "MOB"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .strength: "Força"
        case .power: "Explosão"
        case .conditioning: "Resistência"
        case .core: "Core"
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
        case .calories: "Cal"
        }
    }
}

extension TitleID {
    var name: LocalizedStringKey {
        switch self {
        case .firstSession: "Primeiro Treino"
        case .recruitmentComplete: "Recrutamento Concluído"
        case .perfectWeek: "Semana Perfeita"
        case .streakLit: "Sequência Acesa"
        case .limitBroken10: "Limite Quebrado x10"
        case .hundredBars: "Cem Barras"
        case .readyForBattle: "Pronto para a Batalha"
        }
    }

    var condition: LocalizedStringKey {
        switch self {
        case .firstSession: "Conclua o primeiro treino."
        case .recruitmentComplete: "Feche o primeiro arco."
        case .perfectWeek: "Bata a meta de uma semana."
        case .streakLit: "Bata a meta 4 semanas seguidas."
        case .limitBroken10: "Quebre 10 limites."
        case .hundredBars: "Faça 100 séries de barra fixa."
        case .readyForBattle: "Conclua os treinos da Véspera."
        }
    }
}

extension BattleResult {
    var label: LocalizedStringKey {
        switch self {
        case .gold: "Ouro"
        case .silver: "Prata"
        case .bronze: "Bronze"
        case .participation: "Participação"
        }
    }
}

extension ImportedActivity {
    /// The Garmin type in pt-BR; unknown types read as "Atividade".
    var typeLabel: LocalizedStringKey {
        // Activity API 2.1, Appendix A.
        switch activityType {
        case "RUNNING", "INDOOR_RUNNING", "OBSTACLE_RUN", "STREET_RUNNING", "TRACK_RUNNING", "TRAIL_RUNNING",
            "TREADMILL_RUNNING", "ULTRA_RUN", "VIRTUAL_RUN":
            "Corrida"
        case "CYCLING", "CYCLOCROSS", "DOWNHILL_BIKING", "E_BIKE_FITNESS", "E_BIKE_MOUNTAIN", "E_ENDURO_MTB",
            "ENDURO_MTB", "GRAVEL_CYCLING", "INDOOR_CYCLING", "MOUNTAIN_BIKING", "RECUMBENT_CYCLING", "ROAD_BIKING",
            "TRACK_CYCLING", "VIRTUAL_RIDE", "HANDCYCLING", "INDOOR_HANDCYCLING":
            "Bike"
        case "ROWING", "ROWING_V2", "INDOOR_ROWING": "Remo"
        case "ELLIPTICAL": "Elíptico"
        case "STAIR_CLIMBING": "Escada"
        case "WALKING", "CASUAL_WALKING", "SPEED_WALKING": "Caminhada"
        case "HIKING", "RUCKING": "Trilha"
        case "SWIMMING", "LAP_SWIMMING", "OPEN_WATER_SWIMMING": "Natação"
        case "HIIT": "HIIT"
        case "INDOOR_CARDIO": "Cardio"
        case "JUMP_ROPE": "Corda"
        case "YOGA": "Yoga"
        case "PILATES": "Pilates"
        case "MOBILITY": "Mobilidade"
        case "STRENGTH_TRAINING": "Musculação"
        case "BOXING": "Boxe"
        case "MIXED_MARTIAL_ARTS": "Luta"
        default: "Atividade"
        }
    }

    /// "8,2 km · 40 min · 4:53 /km · FC 152": each part only when the activity has it.
    func summary(locale: Locale = .current) -> String {
        var parts: [String] = []
        let km = distanceMeters.map { NSDecimalNumber(decimal: $0).doubleValue / 1000 } ?? 0
        if km > 0 {
            parts.append("\(km.formatted(.number.precision(.fractionLength(1)).locale(locale))) km")
        }
        parts.append("\(durationSeconds / 60) min")
        if km > 0 {
            let pace = Int((Double(durationSeconds) / km).rounded())
            parts.append(String(format: "%d:%02d /km", pace / 60, pace % 60))
        }
        if let averageHeartRate { parts.append("FC \(averageHeartRate)") }
        return parts.joined(separator: " · ")
    }
}
