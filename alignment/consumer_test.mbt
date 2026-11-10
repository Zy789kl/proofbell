///|
fn sample_blueprint() -> @alignment.Blueprint {
  {
    schema: 1,
    course: "lab",
    title: "Lab safety",
    objectives: [
      {
        id: "practice-safely",
        title: "Use the safety checklist",
        level: 3,
        minimum_points: 4,
        require_rehearsal: false,
      },
    ],
    evidence: [
      {
        id: "station-a",
        title: "Station A",
        kind: "assessment",
        phase: 2,
        points: 5,
        links: [
          {
            objective: "practice-safely",
            level: 3,
            points: 4,
            criterion: "Complete the checklist",
          },
        ],
      },
      {
        id: "station-b",
        title: "Station B",
        kind: "assessment",
        phase: 3,
        points: 4,
        links: [
          {
            objective: "practice-safely",
            level: 3,
            points: 4,
            criterion: "Check the next station",
          },
        ],
      },
      {
        id: "orientation",
        title: "Orientation",
        kind: "practice",
        phase: 1,
        points: 0,
        links: [],
      },
    ],
  }
}

///|
test "typed inputs are validated before indexing their links" {
  let plan = sample_blueprint()
  let report = @alignment.audit_blueprint(plan)
  assert_eq(report.objectives[0].qualifying_points, 8)
  let original = plan.evidence[0].links[0]
  plan.evidence[0].links[0] = { ..original, objective: "unknown", }
  try @alignment.audit_blueprint(plan) catch {
    error =>
      assert_true(error.message().contains("evidence[0].links[0].objective"))
  } noraise {
    _ => fail("expected an unknown objective error")
  }
}

///|
test "same total does not conceal where unallocated marks moved" {
  let before = sample_blueprint()
  let after = sample_blueprint()
  after.evidence[0] = { ..after.evidence[0], points: 4, }
  after.evidence[1] = { ..after.evidence[1], points: 5, }
  after.evidence[2] = {
    ..after.evidence[2],
    links: [
      {
        objective: "practice-safely",
        level: 3,
        points: 0,
        criterion: "Rehearse the checklist",
      },
    ],
  }
  let report = @alignment.compare_blueprints(before, after)
  assert_eq(report.before_unallocated, 1)
  assert_eq(report.after_unallocated, 1)
  assert_eq(report.remainder_changes.map(change => change.item_id), [
    "station-b", "station-a",
  ])
  assert_eq(report.remainder_changes[0].after.map(item => item.points), Some(1))
  assert_eq(
    report.remainder_changes[1].before.map(item => item.points),
    Some(1),
  )
  assert_eq(report.no_longer_unmapped, ["orientation"])
  assert_eq(@alignment.compare_blueprints(after, before).newly_unmapped, [
    "orientation",
  ])
}
