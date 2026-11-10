///|
#derive(ToJson)
pub struct CourseSummary {
  course : String
  title : String
  ready : Bool
  objectives : Int32
  ready_objectives : Int32
  unallocated_points : Int32
  unmapped_items : Int32
}

///|
#derive(ToJson)
pub struct Portfolio {
  courses : Array[CourseSummary]
  ready_courses : Int32
  ready : Bool
}

///|
pub extend CourseSummary with @json.ToJson::{to_json}

///|
pub extend Portfolio with @json.ToJson::{to_json}

///|
/// Summarize courses in input order. Point scales remain per course.
/// Each course may occur only once in the portfolio.
pub fn portfolio(reports : Array[Report]) -> Portfolio raise BlueprintError {
  require(!reports.is_empty(), "portfolio", "expected at least one course")
  let seen : Map[String, Unit] = Map([])
  let courses = []
  let mut ready_courses = 0
  for report in reports {
    require(
      !seen.contains(report.course),
      report.course,
      "duplicate course in portfolio",
    )
    seen[report.course] = ()
    if report.ready {
      ready_courses += 1
    }
    let mut ready_objectives = 0
    for finding in report.objectives {
      if finding.ready {
        ready_objectives += 1
      }
    }
    courses.push({
      course: report.course,
      title: report.title,
      ready: report.ready,
      objectives: report.objectives.length(),
      ready_objectives,
      unallocated_points: report.unallocated_points,
      unmapped_items: report.unmapped_evidence.length(),
    })
  }
  { courses, ready_courses, ready: ready_courses == courses.length(), }
}
