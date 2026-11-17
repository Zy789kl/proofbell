///|
priv struct TaskFacts {
  task : Task
  facts : Map[String, Derivation]
}

///|
// Each pass only adds facts. Unsupported cycles cannot create their own proof.
fn close(task : Task, rules : Array[Rule]) -> TaskFacts {
  let facts : Map[String, Derivation] = Map([])
  for row in task.observations {
    facts[row.fact] = {
      fact: row.fact,
      rubric: Some(row.rubric),
      rule: None,
      premises: [],
    }
  }
  let mut changed = true
  while changed {
    changed = false
    for rule in rules {
      if !facts.contains(rule.yields) &&
        rule.needs.all(fact => facts.contains(fact)) {
        facts[rule.yields] = {
          fact: rule.yields,
          rubric: None,
          rule: Some(rule.id),
          premises: rule.needs,
        }
        changed = true
      }
    }
  }
  { task, facts, }
}

///|
priv struct Explanation {
  facts : Map[String, Derivation]
  by_conclusion : Map[String, Array[Rule]]
  visited : Map[String, Unit]
  steps : Array[Derivation]
  blocked : Array[BlockedRule]
  missing_observations : Array[String]
}

///|
fn Explanation::trace(self : Explanation, fact : String) -> Unit {
  if self.visited.contains(fact) {
    return
  }
  self.visited[fact] = ()
  match self.facts.get(fact) {
    Some(step) => {
      for premise in step.premises {
        self.trace(premise)
      }
      self.steps.push(step)
    }
    None =>
      match self.by_conclusion.get(fact) {
        None => self.missing_observations.push(fact)
        Some(rules) =>
          for rule in rules {
            self.blocked.push({
              rule: rule.id,
              conclusion: fact,
              missing: rule.needs.filter(premise => {
                !self.facts.contains(premise)
              }),
            })
            for premise in rule.needs {
              self.trace(premise)
            }
          }
      }
  }
}

///|
priv struct Rehearsal {
  item : String
  phase : Int32
  context : String
}

///|
fn rehearsal_index(
  goal : @alignment.Finding,
  claim : Claim,
  tasks : Map[String, TaskFacts],
) -> Array[Rehearsal] {
  let rehearsals : Array[Rehearsal] = []
  for row in goal.trace {
    if row.kind == "practice" &&
      row.meets_level &&
      tasks.get(row.item_id) is Some(entry) &&
      claim.needs.all(fact => entry.facts.contains(fact)) {
      rehearsals.push({
        item: row.item_id,
        phase: row.phase,
        context: entry.task.context,
      })
    }
  }
  rehearsals.sort_by((left, right) => left.phase.compare(right.phase))
  guard rehearsals.get(0) is Some(first) else { return [] }
  // The earliest practice and earliest different context suffice for any test.
  for practice in rehearsals {
    if practice.context != first.context {
      return [first, practice]
    }
  }
  [first]
}

///|
fn candidate(
  row : @alignment.Trace,
  claim : Claim,
  facts : TaskFacts?,
  rehearsals : Array[Rehearsal],
  by_conclusion : Map[String, Array[Rule]],
) -> Candidate {
  guard facts is Some(entry) else {
    return {
      item: row.item_id,
      context: None,
      missing: claim.needs.copy(),
      derivations: [],
      blocked_rules: [],
      missing_observations: [],
      independent: false,
      transfer_from: None,
      status: "unprofiled",
    }
  }
  let missing = claim.needs.filter(fact => !entry.facts.contains(fact))
  let explanation : Explanation = {
    facts: entry.facts,
    by_conclusion,
    visited: Map([]),
    steps: [],
    blocked: [],
    missing_observations: [],
  }
  for fact in claim.needs {
    explanation.trace(fact)
  }
  let mut transfer_from = None
  if claim.transfer {
    for practice in rehearsals {
      if practice.phase < row.phase && practice.context != entry.task.context {
        transfer_from = Some(practice.item)
        break
      }
    }
  }
  let status = if !row.meets_level {
    "below_level"
  } else if !missing.is_empty() {
    "missing_evidence"
  } else if !entry.task.independent {
    "guided_assessment"
  } else if claim.transfer && transfer_from is None {
    "transfer_not_demonstrated"
  } else {
    "supported"
  }
  {
    item: row.item_id,
    context: Some(entry.task.context),
    missing,
    derivations: explanation.steps,
    blocked_rules: explanation.blocked,
    missing_observations: explanation.missing_observations,
    independent: entry.task.independent,
    transfer_from,
    status,
  }
}

///|
/// Analyze rubric observations with per-task rules against a validated blueprint
/// report. Facts from different tasks never combine into a single witness.
pub fn analyze(
  report : @alignment.Report,
  profile_json : String,
) -> SemanticReport raise SemanticError {
  require(
    profile_json.length() <= 2000000,
    "Profile exceeds two million code units",
  )
  let json = @json.parse(
    profile_json,
    max_nesting_depth=12,
    reject_duplicate_keys=true,
  ) catch {
    error =>
      raise InvalidProfile("Invalid profile JSON: \{@debug.to_string(error)}")
  }
  let profile : Profile = @json.from_json(json) catch {
    error =>
      raise InvalidProfile("Invalid profile fields: \{@debug.to_string(error)}")
  }
  let claims = validate(profile, report)
  let by_conclusion : Map[String, Array[Rule]] = Map([])
  for rule in profile.rules {
    if by_conclusion.get(rule.yields) is Some(group) {
      group.push(rule)
    } else {
      by_conclusion[rule.yields] = [rule]
    }
  }
  let tasks = Map::from_array(
    profile.tasks.map(task => (task.item, close(task, profile.rules))),
  )
  let findings : Array[ClaimFinding] = []
  for goal in report.objectives {
    let claim = claims[goal.objective]
    let rehearsals = if claim.transfer {
      rehearsal_index(goal, claim, tasks)
    } else {
      []
    }
    let candidates = []
    let mut witness = None
    for row in goal.trace {
      if row.kind == "assessment" {
        let result = candidate(
          row,
          claim,
          tasks.get(row.item_id),
          rehearsals,
          by_conclusion,
        )
        if witness is None && result.status == "supported" {
          witness = Some(row.item_id)
        }
        candidates.push(result)
      }
    }
    findings.push({ objective: goal.objective, witness, candidates, })
  }
  {
    course: report.course,
    blueprint_ready: report.ready,
    ready: report.ready && findings.all(finding => finding.witness is Some(_)),
    findings,
  }
}
