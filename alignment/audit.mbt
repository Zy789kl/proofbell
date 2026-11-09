///|
/// A teacher's mapping from one activity or assessment to an objective.
#derive(ToJson)
pub struct Trace {
  item_id : String
  item_title : String
  kind : String
  phase : Int32
  level : Int32
  criterion : String
  points : Int32
  meets_level : Bool
}

///|
#derive(ToJson)
pub struct Finding {
  objective : String
  title : String
  level : Int32
  minimum_points : Int32
  require_rehearsal : Bool
  qualifying_points : Int32
  first_assessment_phase : Int32?
  first_rehearsal_phase : Int32?
  rehearsal_ready : Bool
  ready : Bool
  trace : Array[Trace]
}

///|
#derive(ToJson)
pub struct PointRemainder {
  item_id : String
  item_title : String
  points : Int32
}

///|
#derive(ToJson)
pub struct Report {
  course : String
  title : String
  objectives : Array[Finding]
  assessment_points : Int32
  unallocated_points : Int32
  point_remainders : Array[PointRemainder]
  unmapped_evidence : Array[String]
  ready : Bool
}

///|
pub extend Trace with @json.ToJson::{to_json}

///|
pub extend Finding with @json.ToJson::{to_json}

///|
pub extend PointRemainder with @json.ToJson::{to_json}

///|
pub extend Report with @json.ToJson::{to_json}

///|
fn earliest(existing : Int32?, phase : Int32) -> Int32 {
  match existing {
    None => phase
    Some(previous) => previous.min(phase)
  }
}

///|
fn summarize(goal : Objective, trace : Array[Trace]) -> Finding {
  let mut qualifying_points = 0
  let mut first_assessment_phase = None
  let mut first_rehearsal_phase = None
  for row in trace {
    if !row.meets_level {
      continue
    }
    if row.kind == "assessment" {
      qualifying_points += row.points
      first_assessment_phase = Some(earliest(first_assessment_phase, row.phase))
    } else {
      first_rehearsal_phase = Some(earliest(first_rehearsal_phase, row.phase))
    }
  }
  let rehearsal_ready = !goal.require_rehearsal ||
    (match (first_rehearsal_phase, first_assessment_phase) {
      (Some(practice), Some(assessment)) => practice < assessment
      (Some(_), None) => true
      _ => false
    })
  {
    objective: goal.id,
    title: goal.title,
    level: goal.level,
    minimum_points: goal.minimum_points,
    require_rehearsal: goal.require_rehearsal,
    qualifying_points,
    first_assessment_phase,
    first_rehearsal_phase,
    rehearsal_ready,
    ready: qualifying_points >= goal.minimum_points && rehearsal_ready,
    trace,
  }
}

///|
/// Audit a schema-1 blueprint. The report preserves its objective and evidence
/// order, with links below the required demand kept visible for review.
pub fn audit(text : String) -> Report raise BlueprintError {
  let plan = decode(text)
  let indices : Map[String, Int32] = Map([])
  let traces : Array[Array[Trace]] = []
  for i, goal in plan.objectives {
    indices[goal.id] = i
    traces.push([])
  }
  let unmapped_evidence = []
  let point_remainders = []
  let mut assessment_points = 0
  let mut unallocated_points = 0
  for item in plan.evidence {
    assessment_points += item.points
    if item.links.is_empty() {
      unmapped_evidence.push(item.id)
    }
    let mut remaining = item.points
    for link in item.links {
      let i = indices[link.objective]
      remaining -= link.points
      traces[i].push({
        item_id: item.id,
        item_title: item.title,
        kind: item.kind,
        phase: item.phase,
        level: link.level,
        criterion: link.criterion,
        points: link.points,
        meets_level: link.level >= plan.objectives[i].level,
      })
    }
    if remaining > 0 {
      unallocated_points += remaining
      point_remainders.push({
        item_id: item.id,
        item_title: item.title,
        points: remaining,
      })
    }
  }
  let objectives = plan.objectives.mapi((i, goal) => summarize(goal, traces[i]))
  {
    course: plan.course,
    title: plan.title,
    ready: objectives.all(goal => goal.ready) && unallocated_points == 0,
    objectives,
    assessment_points,
    unallocated_points,
    point_remainders,
    unmapped_evidence,
  }
}
