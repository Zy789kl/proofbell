///|
test "spreadsheet data survives JSON import with rehearsal and points intact" {
  let plan = @tables.import_tables(
    course="lab",
    title="Lab",
    objectives="\ufeffid\ttitle\tlevel\tminimum_points\trequire_rehearsal\r\ncheck\tCheck the reading\t3\t4\ttrue\r\n",
    evidence="id\ttitle\tphase\tkind\tpoints\np\tPractice\t1\tpractice\t0\na\tAssessment\t2\tassessment\t4",
    links="item_id\tobjective\tlevel\tpoints\tcriterion\np\tcheck\t3\t0\tFind the reading\na\tcheck\t3\t4\tReport the result",
  )
  let report = @alignment.audit(plan.to_json().stringify())
  assert_true(report.ready)
  assert_eq(report.objectives[0].first_rehearsal_phase, Some(1))
  assert_eq(report.objectives[0].qualifying_points, 4)
}

///|
test "unknown assessment in mapping is reported at its table row" {
  try
    @tables.import_tables(
      course="lab",
      title="Lab",
      objectives="id\ttitle\tlevel\tminimum_points\trequire_rehearsal\ncheck\tCheck the reading\t3\t4\ttrue",
      evidence="id\ttitle\tphase\tkind\tpoints\na\tAssessment\t2\tassessment\t4",
      links="item_id\tobjective\tlevel\tpoints\tcriterion\nb\tcheck\t3\t4\tReport the result",
    )
  catch {
    @tables.InvalidTable(message) =>
      assert_true(message.contains("links row 2"))
  } noraise {
    _ => fail("expected an invalid link")
  }
}
