import Foundation

extension Arc {
    /// A monthly arc of a season (#210): it has calendar months.
    public var isMonthly: Bool { !(months ?? []).isEmpty }
}

/// Seasons with monthly arcs (#210, docs/decisions/0035). The initial arcs (no months) unlock one at a time, in
/// order; the monthly arcs stay locked until every initial arc is completed, then all open at once. The current
/// arc follows the calendar month.
public enum MonthlyArcs {
    /// The season has monthly arcs and every other arc of it (Manutenção aside) is completed.
    public static func inMonthlyPhase(_ seasonArcs: [Arc]) -> Bool {
        let live = seasonArcs.filter { $0.deletedAt == nil && $0.kind != .filler }
        return live.contains(where: \.isMonthly)
            && live.filter { !$0.isMonthly }.allSatisfy { $0.status == .completed }
    }

    /// A monthly arc not completed, in an active season past its initial arcs: its workouts can be started.
    public static func isOpen(_ arc: Arc, in seasonArcs: [Arc], seasonActive: Bool) -> Bool {
        seasonActive && arc.isMonthly && arc.status != .completed && arc.deletedAt == nil
            && inMonthlyPhase(seasonArcs)
    }

    /// The arc that should be current in `month` (1 to 12): the open monthly arc covering it, else the first open
    /// monthly arc. Nil outside the monthly phase or when every month is completed.
    public static func current(in seasonArcs: [Arc], month: Int) -> Arc? {
        guard inMonthlyPhase(seasonArcs) else { return nil }
        let open = seasonArcs.filter { $0.isMonthly && $0.status != .completed && $0.deletedAt == nil }
            .sorted { $0.position < $1.position }
        return open.first { $0.months?.contains(month) == true } ?? open.first
    }
}
