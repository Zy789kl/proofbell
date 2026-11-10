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
  remainder_changes : Array[RemainderChange]
  newly_unmapped : Array[String]
  no_longer_unmapped : Array[String]
  ready : Bool
}

///|
/// A change in marks left unallocated on one assessment.
#derive(ToJson)
pub struct RemainderChange {
  item_id : String
  before : PointRemainder?
  after : PointRemainder?
}

///|
pub extend Revision with @json.ToJson::{to_json}

///|
pub extend Comparison with @json.ToJson::{to_json}

///|
pub extend RemainderChange with @json.ToJson::{to_json}

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
  compare_reports(previous, next)
}

///|
/// Compare typed snapshots using the same validation and rules as JSON import.
pub fn compare_blueprints(
  before : Blueprint,
  after : Blueprint,
) -> Comparison raise BlueprintError {
  let previous = audit_blueprint(before) catch {
    error => raise InvalidBlueprint("Before: \{error.message()}")
  }
  let next = audit_blueprint(after) catch {
    error => raise InvalidBlueprint("After: \{error.message()}")
  }
  compare_reports(previous, next)
}

///|
fn compare_reports(
  previous : Report,
  next : Report,
) -> Comparison raise BlueprintError {
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
    remainder_changes: compare_remainders(
      previous.point_remainders,
      next.point_remainders,
    ),
    newly_unmapped: id_difference(
      next.unmapped_evidence,
      previous.unmapped_evidence,
    ),
    no_longer_unmapped: id_difference(
      previous.unmapped_evidence,
      next.unmapped_evidence,
    ),
    ready: next.ready,
  }
}

///|
fn id_difference(ids : Array[String], other : Array[String]) -> Array[String] {
  let existing = Map::from_array(other.map(id => (id, ())))
  ids.filter(id => !existing.contains(id))
}

///|
fn compare_remainders(
  before : Array[PointRemainder],
  after : Array[PointRemainder],
) -> Array[RemainderChange] {
  let previous = Map::from_array(before.map(item => (item.item_id, item)))
  let current = Map::from_array(after.map(item => (item.item_id, item)))
  let changes = []
  for item in after {
    let old = previous.get(item.item_id)
    if old is Some(old) &&
      old.points == item.points &&
      old.item_title == item.item_title {
      continue
    }
    changes.push({ item_id: item.item_id, before: old, after: Some(item), })
  }
  for item in before {
    if !current.contains(item.item_id) {
      changes.push({ item_id: item.item_id, before: Some(item), after: None, })
    }
  }
  changes
}
