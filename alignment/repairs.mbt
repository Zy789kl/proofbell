///|
/// One review task. Amount is a point count when the task involves marks.
#derive(ToJson)
pub struct Repair {
  kind : String
  target : String
  amount : Int32?
  rehearsal_phase : Int32?
  assessment_phase : Int32?
}

///|
pub extend Repair with @json.ToJson::{to_json}

///|
/// List gaps in objective order, then unassigned marks and unmapped items.
/// An unmapped practice is advisory. An unmapped assessment is already
/// represented by its unallocated marks.
pub fn repairs(report : Report) -> Array[Repair] {
  let tasks = []
  for goal in report.objectives {
    let deficit = goal.minimum_points - goal.qualifying_points
    if deficit > 0 {
      tasks.push({
        kind: "assessment_shortfall",
        target: goal.objective,
        amount: Some(deficit),
        rehearsal_phase: None,
        assessment_phase: None,
      })
    }
    if !goal.rehearsal_ready {
      let kind = if goal.first_rehearsal_phase is None {
        "rehearsal_missing"
      } else {
        "rehearsal_late"
      }
      tasks.push({
        kind,
        target: goal.objective,
        amount: None,
        rehearsal_phase: goal.first_rehearsal_phase,
        assessment_phase: goal.first_assessment_phase,
      })
    }
  }
  let unallocated : Map[String, Unit] = Map([])
  for item in report.point_remainders {
    unallocated[item.item_id] = ()
    tasks.push({
      kind: "unallocated_marks",
      target: item.item_id,
      amount: Some(item.points),
      rehearsal_phase: None,
      assessment_phase: None,
    })
  }
  for id in report.unmapped_evidence {
    if !unallocated.contains(id) {
      tasks.push({
        kind: "unmapped_practice",
        target: id,
        amount: None,
        rehearsal_phase: None,
        assessment_phase: None,
      })
    }
  }
  tasks
}
