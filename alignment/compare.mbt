///|
#derive(ToJson)
pub struct Revision {
  objective : String
  change : String
  before : Finding?
  after : Finding?
}

///|
#derive(ToJson)
pub struct Comparison {
  course : String
  changes : Array[Revision]
  before_unallocated : Int32
  after_unallocated : Int32
  ready : Bool
}

///|
pub extend Revision with @json.ToJson::{to_json}

///|
pub extend Comparison with @json.ToJson::{to_json}

///|
fn evidence_changed(before : Array[Trace], after : Array[Trace]) -> Bool {
  if before.length() != after.length() {
    return true
  }
  let by_item = Map::from_array(before.map(row => (row.item_id, row)))
  after.any(row => {
    match by_item.get(row.item_id) {
      None => true
      Some(old) => !old.to_json().equal(row.to_json())
    }
  })
}

///|
fn change_kind(before : Finding, after : Finding) -> String? {
  if before.title != after.title ||
    before.level != after.level ||
    before.minimum_points != after.minimum_points ||
    before.require_rehearsal != after.require_rehearsal {
    return Some("requirements_changed")
  }
  match (before.ready, after.ready) {
    (false, true) => Some("resolved")
    (true, false) => Some("regressed")
    _ =>
      if evidence_changed(before.trace, after.trace) {
        Some("evidence_changed")
      } else {
        None
      }
  }
}

///|
/// Compare revisions of the same course by stable objective and evidence IDs.
/// Changed requirements take precedence over a change in readiness.
pub fn compare(
  before : String,
  after : String,
) -> Comparison raise BlueprintError {
  let previous = audit(before) catch {
    error => raise InvalidBlueprint("Before: \{error.message()}")
  }
  let next = audit(after) catch {
    error => raise InvalidBlueprint("After: \{error.message()}")
  }
  require(
    previous.course == next.course,
    "course",
    "compare revisions with the same course ID",
  )
  let before_goals = Map::from_array(
    previous.objectives.map(goal => (goal.objective, goal)),
  )
  let after_goals = Map::from_array(
    next.objectives.map(goal => (goal.objective, goal)),
  )
  let changes = []
  for goal in next.objectives {
    let old = before_goals.get(goal.objective)
    let change = match old {
      None => Some("added")
      Some(previous) => change_kind(previous, goal)
    }
    if change is Some(change) {
      changes.push({
        objective: goal.objective,
        change,
        before: old,
        after: Some(goal),
      })
    }
  }
  for goal in previous.objectives {
    if !after_goals.contains(goal.objective) {
      changes.push({
        objective: goal.objective,
        change: "removed",
        before: Some(goal),
        after: None,
      })
    }
  }
  {
    course: next.course,
    changes,
    before_unallocated: previous.unallocated_points,
    after_unallocated: next.unallocated_points,
    ready: next.ready,
  }
}
