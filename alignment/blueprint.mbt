///|
#derive(FromJson)
priv struct Blueprint {
  schema : Int32
  course : String
  title : String
  objectives : Array[Objective]
  evidence : Array[Evidence]
}

///|
#derive(FromJson)
priv struct Objective {
  id : String
  title : String
  level : Int32
  minimum_points : Int32
  require_rehearsal : Bool
}

///|
#derive(FromJson)
priv struct Evidence {
  id : String
  title : String
  phase : Int32
  kind : String
  points : Int32
  links : Array[Link]
}

///|
#derive(FromJson)
priv struct Link {
  objective : String
  level : Int32
  points : Int32
  criterion : String
}

///|
pub suberror BlueprintError {
  InvalidBlueprint(String)
}

///|
pub fn BlueprintError::message(self : BlueprintError) -> String {
  let InvalidBlueprint(message) = self
  message
}

///|
fn require(
  ok : Bool,
  location : String,
  reason : String,
) -> Unit raise BlueprintError {
  if !ok {
    raise InvalidBlueprint("\{location}: \{reason}")
  }
}

///|
fn check_id(id : String, location : String) -> Unit raise BlueprintError {
  require(
    !id.is_empty() && id.length() <= 48,
    location,
    "ID must contain 1–48 characters",
  )
  for ch in id {
    require(
      (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_',
      location,
      "use lowercase letters, digits, hyphens or underscores for IDs",
    )
  }
}

///|
fn check_text(text : String, location : String) -> Unit raise BlueprintError {
  require(
    !text.trim().is_empty() && text.length() <= 400,
    location,
    "expected 1–400 characters",
  )
  for ch in text {
    require(ch >= ' ' && ch != '\u007f', location, "use single-line text")
  }
}

///|
fn check_level(level : Int32, location : String) -> Unit raise BlueprintError {
  require(level >= 1 && level <= 4, location, "level must be in 1..4")
}

///|
fn validate(plan : Blueprint) -> Unit raise BlueprintError {
  require(plan.schema == 1, "schema", "expected version 1")
  check_id(plan.course, "course")
  check_text(plan.title, "title")
  require(
    plan.objectives.length() >= 1 && plan.objectives.length() <= 200,
    "objectives",
    "expected 1–200 objectives",
  )
  require(
    plan.evidence.length() <= 1000,
    "evidence",
    "at most 1000 entries are supported",
  )
  let objectives : Map[String, Bool] = Map([])
  for i, goal in plan.objectives {
    let at = "objectives[\{i}]"
    check_id(goal.id, at + ".id")
    require(!objectives.contains(goal.id), at + ".id", "duplicate objective")
    objectives[goal.id] = true
    check_text(goal.title, at + ".title")
    check_level(goal.level, at + ".level")
    require(
      goal.minimum_points >= 1 && goal.minimum_points <= 1000000,
      at + ".minimum_points",
      "expected 1–1000000 points",
    )
  }
  let evidence_ids : Map[String, Bool] = Map([])
  for i, item in plan.evidence {
    let at = "evidence[\{i}]"
    check_id(item.id, at + ".id")
    require(
      !evidence_ids.contains(item.id),
      at + ".id",
      "duplicate evidence ID",
    )
    evidence_ids[item.id] = true
    validate_evidence(item, objectives, at)
  }
}

///|
fn validate_evidence(
  item : Evidence,
  objectives : Map[String, Bool],
  at : String,
) -> Unit raise BlueprintError {
  check_text(item.title, at + ".title")
  require(
    item.phase >= 1 && item.phase <= 10000,
    at + ".phase",
    "expected phase 1–10000",
  )
  let assessment = item.kind == "assessment"
  require(
    assessment || item.kind == "practice",
    at + ".kind",
    "expected practice or assessment",
  )
  require(
    if assessment {
      item.points >= 1 && item.points <= 1000
    } else {
      item.points == 0
    },
    at + ".points",
    "assessment must be worth 1–1000 points; practice must be worth 0",
  )
  require(
    item.links.length() <= objectives.length(),
    at + ".links",
    "too many links",
  )
  let seen : Map[String, Bool] = Map([])
  let mut allocated = 0
  for i, link in item.links {
    let path = at + ".links[\{i}]"
    require(
      objectives.contains(link.objective),
      path + ".objective",
      "unknown objective",
    )
    require(
      !seen.contains(link.objective),
      path + ".objective",
      "objective already linked from this item",
    )
    seen[link.objective] = true
    check_level(link.level, path + ".level")
    check_text(link.criterion, path + ".criterion")
    require(
      if assessment {
        link.points > 0 && link.points <= item.points
      } else {
        link.points == 0
      },
      path + ".points",
      "allocate positive points from the item budget; practice must be worth 0",
    )
    allocated += link.points
    require(
      allocated <= item.points,
      path + ".points",
      "allocations exceed the item's point budget",
    )
  }
}

///|
fn decode(text : String) -> Blueprint raise BlueprintError {
  require(
    text.length() <= 2000000,
    "$",
    "input exceeds two million UTF-16 code units",
  )
  let value = @json.parse(
    text,
    max_nesting_depth=12,
    reject_duplicate_keys=true,
  ) catch {
    err => raise InvalidBlueprint("Invalid JSON: \{@debug.to_string(err)}")
  }
  let plan : Blueprint = @json.from_json(value) catch {
    err =>
      raise InvalidBlueprint(
        "Invalid blueprint fields: \{@debug.to_string(err)}",
      )
  }
  validate(plan)
  plan
}
