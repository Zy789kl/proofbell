///|
fn blueprint(items : Array[Json]) -> String {
  let json : Json = {
    "schema": 1,
    "course": "test-course",
    "title": "Sample",
    "objectives": [
      {
        "id": "check",
        "title": "Check a source",
        "level": 3,
        "minimum_points": 10,
        "require_rehearsal": true,
      },
      {
        "id": "name",
        "title": "Name a source",
        "level": 1,
        "minimum_points": 4,
        "require_rehearsal": false,
      },
    ],
    "evidence": Json::array(items),
  }
  json.stringify()
}

///|
fn rehearsal(phase : Int32) -> Json {
  {
    "id": "workshop",
    "title": "Workshop",
    "phase": Json(phase),
    "kind": "practice",
    "points": 0,
    "links": [
      {
        "objective": "check",
        "level": 3,
        "points": 0,
        "criterion": "Open and read the source",
      },
    ],
  }
}

///|
fn assessment(
  level : Int32,
  points : Int32,
  objective~ : String = "name",
) -> Json {
  {
    "id": "source-quiz",
    "title": "Source quiz",
    "phase": 3,
    "kind": "assessment",
    "points": Json(points),
    "links": [
      {
        "objective": "check",
        "level": Json(level),
        "points": 10,
        "criterion": "Compare the claim with the source",
      },
      {
        "objective": Json(objective),
        "level": 1,
        "points": 4,
        "criterion": "Name the author",
      },
    ],
  }
}

///|
test "allocated scores count only at or above the required demand" {
  let report = @alignment.audit(blueprint([rehearsal(2), assessment(1, 16)]))
  assert_false(report.ready)
  assert_eq(report.objectives[0].qualifying_points, 0)
  assert_true(report.objectives[0].rehearsal_ready)
  assert_false(report.objectives[0].trace[1].meets_level)
  assert_eq(report.objectives[1].qualifying_points, 4)
  assert_eq(report.unallocated_points, 2)
  assert_eq(report.point_remainders[0].item_id, "source-quiz")
}

///|
test "same phase does not establish that rehearsal came first" {
  let report = @alignment.audit(blueprint([assessment(4, 14), rehearsal(3)]))
  assert_eq(report.objectives[0].qualifying_points, 10)
  assert_false(report.objectives[0].rehearsal_ready)
  assert_false(report.ready)
  assert_true(
    @alignment.audit(blueprint([assessment(4, 14), rehearsal(2)])).ready,
  )
}

///|
test "an unallocated mark blocks readiness even when both objectives pass" {
  let report = @alignment.audit(blueprint([rehearsal(2), assessment(3, 15)]))
  assert_true(report.objectives[0].ready)
  assert_true(report.objectives[1].ready)
  assert_false(report.ready)
}

///|
test "reject allocations that spend an item twice" {
  assert_true(
    audit_error(blueprint([assessment(3, 12)])).contains(
      "evidence[0].links[1].points",
    ),
  )
}

///|
test "reject unknown or duplicate objectives on an item" {
  for id in ["elsewhere", "check"] {
    assert_true(
      audit_error(blueprint([assessment(3, 14, objective=id)])).contains(
        "evidence[0].links[1].objective",
      ),
    )
  }
}

///|
test "duplicate JSON keys are rejected before validation" {
  assert_true(
    audit_error("{\"schema\":1,\"schema\":1}").contains("Invalid JSON"),
  )
}

///|
fn audit_error(text : String) -> String raise {
  try @alignment.audit(text) catch {
    error => error.message()
  } noraise {
    _ => fail("expected an invalid blueprint")
  }
}
