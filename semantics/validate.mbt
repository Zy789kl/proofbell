///|
fn require(ok : Bool, message : String) -> Unit raise SemanticError {
  if !ok {
    raise InvalidProfile(message)
  }
}

///|
fn identifier(id : String) -> Bool {
  if id.is_empty() || id.length() > 48 {
    return false
  }
  for ch in id {
    if !((ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_') {
      return false
    }
  }
  true
}

///|
fn unique(
  ids : Array[String],
  label : String,
) -> Map[String, Unit] raise SemanticError {
  let seen : Map[String, Unit] = Map([])
  for id in ids {
    require(
      identifier(id) && !seen.contains(id),
      "\{label}: invalid or duplicate ID '\{id}'",
    )
    seen[id] = ()
  }
  seen
}

///|
fn validate(
  profile : Profile,
  report : @alignment.Report,
) -> Map[String, Claim] raise SemanticError {
  require(
    profile.schema == 1 && profile.course == report.course,
    "Profile schema must be 1 and course must match the blueprint",
  )
  require(
    profile.observations.length() <= 128 && profile.rules.length() <= 128,
    "At most 128 observation names and 128 rules are supported",
  )
  require(
    profile.claims.length() == report.objectives.length(),
    "Declare one semantic claim for every objective",
  )
  require(profile.tasks.length() <= 1000, "At most 1000 tasks are supported")
  let primitive = unique(profile.observations, "observations")
  ignore(unique(profile.rules.map(rule => rule.id), "rules"))
  let known = Map::from_array(profile.observations.map(fact => (fact, ())))
  for rule in profile.rules {
    require(
      identifier(rule.yields) && !primitive.contains(rule.yields),
      "Rule \{rule.id}: conclusion must be a derived fact",
    )
    known[rule.yields] = ()
  }
  for rule in profile.rules {
    validate_needs(rule.needs, known, "Rule " + rule.id)
  }
  let objectives = Map::from_array(
    report.objectives.map(goal => (goal.objective, ())),
  )
  ignore(unique(profile.claims.map(claim => claim.objective), "claims"))
  let claims : Map[String, Claim] = Map([])
  for claim in profile.claims {
    require(
      objectives.contains(claim.objective),
      "Unknown objective '\{claim.objective}'",
    )
    validate_needs(claim.needs, known, "Claim " + claim.objective)
    claims[claim.objective] = claim
  }
  let items = Map::from_array(report.unmapped_evidence.map(id => (id, ())))
  for goal in report.objectives {
    for trace in goal.trace {
      items[trace.item_id] = ()
    }
  }
  ignore(unique(profile.tasks.map(task => task.item), "tasks"))
  for task in profile.tasks {
    require(items.contains(task.item), "Unknown task '\{task.item}'")
    require(identifier(task.context), "Invalid context for '\{task.item}'")
    require(
      task.observations.length() <= 128,
      "Too many observations on '\{task.item}'",
    )
    ignore(
      unique(
        task.observations.map(row => row.fact),
        "observations for " + task.item,
      ),
    )
    for row in task.observations {
      require(
        primitive.contains(row.fact),
        "Task \{task.item}: '\{row.fact}' is not an observable fact",
      )
      require(
        !row.rubric.trim().is_empty() && row.rubric.length() <= 400,
        "Task \{task.item}: specify a rubric excerpt for '\{row.fact}'",
      )
    }
  }
  claims
}

///|
fn validate_needs(
  needs : Array[String],
  known : Map[String, Unit],
  label : String,
) -> Unit raise SemanticError {
  require(
    !needs.is_empty() && needs.length() <= 16,
    "\{label}: expected 1–16 prerequisites",
  )
  ignore(unique(needs, label))
  for fact in needs {
    require(known.contains(fact), "\{label}: unknown fact '\{fact}'")
  }
}
