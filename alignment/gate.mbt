///|
/// Changes that warrant explicit approval before accepting a new course draft.
#derive(ToJson)
pub struct GateFlag {
  target : String
  reason : String
}

///|
pub extend GateFlag with @json.ToJson::{to_json}

///|
/// Detect new or worsened gaps without failing a draft for inherited gaps alone.
/// Requirement changes and removed objectives always need review.
pub fn gate_flags(comparison : Comparison) -> Array[GateFlag] {
  let flags = []
  for revision in comparison.changes {
    let target = revision.objective
    match revision.change {
      "removed" => flags.push({ target, reason: "objective_removed", })
      "requirements_changed" =>
        flags.push({ target, reason: "requirements_changed", })
      "added" =>
        if revision.after is Some(goal) && !goal.ready {
          flags.push({ target, reason: "new_objective_gap", })
        }
      _ =>
        if (revision.before, revision.after) is (Some(before), Some(after)) {
          let before_deficit = (before.minimum_points - before.qualifying_points).max(
            0,
          )
          let after_deficit = (after.minimum_points - after.qualifying_points).max(
            0,
          )
          if after_deficit > before_deficit {
            flags.push({ target, reason: "assessment_deficit_grew", })
          }
          if before.rehearsal_ready && !after.rehearsal_ready {
            flags.push({ target, reason: "rehearsal_no_longer_ready", })
          }
        }
    }
  }
  for change in comparison.remainder_changes {
    let before = change.before.map(item => item.points).unwrap_or(0)
    let after = change.after.map(item => item.points).unwrap_or(0)
    if after > before {
      flags.push({ target: change.item_id, reason: "unallocated_marks_grew", })
    }
  }
  for id in comparison.newly_unmapped {
    flags.push({ target: id, reason: "new_unmapped_item", })
  }
  flags
}
