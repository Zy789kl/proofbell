///|
fn fact_task(item : String, facts : Array[String]) -> Task {
  {
    item,
    context: "trial",
    independent: true,
    observations: facts.map(fact => { fact, rubric: "Rubric for " + fact, }),
  }
}

///|
test "conjunctive rules cannot pool observations across tasks" {
  let rules : Array[Rule] = [
    { id: "justify", needs: ["source", "comparison"], yields: "verified", },
  ]
  let source = close(fact_task("source-task", ["source"]), rules)
  let comparison = close(fact_task("comparison-task", ["comparison"]), rules)
  assert_false(source.facts.contains("verified"))
  assert_false(comparison.facts.contains("verified"))
  let together = close(
    fact_task("complete-task", ["source", "comparison"]),
    rules,
  )
  assert_true(together.facts.contains("verified"))
}

///|
test "a circular rule set needs an observable starting point" {
  let rules : Array[Rule] = [
    { id: "advance", needs: ["source"], yields: "result", },
    { id: "reverse", needs: ["result"], yields: "source", },
    { id: "seed", needs: ["measurement"], yields: "source", },
  ]
  assert_true(close(fact_task("empty", []), rules).facts.is_empty())
  let derivation = close(fact_task("observed", ["measurement"]), rules)
  assert_eq(derivation.facts["source"].rule, Some("seed"))
  assert_eq(derivation.facts["result"].rule, Some("advance"))
}

///|
test "complete evidence in a guided assessment is not an independent witness" {
  let task = { ..fact_task("assessment", ["comparison"]), independent: false, }
  let proof = close(task, [])
  let report = @alignment.audit(
    (
      #| {"schema":1,"course":"lesson","title":"Lesson",
      #| "objectives":[{"id":"compare","title":"Compare","level":3,"minimum_points":10,"require_rehearsal":false}],
      #| "evidence":[{"id":"assessment","title":"Assessment","phase":2,"kind":"assessment","points":10,
      #| "links":[{"objective":"compare","level":3,"points":10,"criterion":"Compare responses"}]}]}
    ),
  )
  let claim : Claim = {
    objective: "compare",
    needs: ["comparison"],
    transfer: false,
  }
  let result = candidate(
    report.objectives[0].trace[0],
    claim,
    Some(proof),
    [],
    Map([]),
  )
  assert_true(result.missing.is_empty())
  assert_eq(result.status, "guided_assessment")
}

///|
test "unknown facts and asserted conclusions cannot enter the engine" {
  let report = @alignment.audit(
    (
      #| {"schema":1,"course":"lesson","title":"Lesson",
      #| "objectives":[{"id":"compare","title":"Compare","level":3,"minimum_points":10,"require_rehearsal":false}],
      #| "evidence":[{"id":"assessment","title":"Assessment","phase":2,"kind":"assessment","points":10,
      #| "links":[{"objective":"compare","level":3,"points":10,"criterion":"Compare responses"}]}]}
    ),
  )
  let profile =
    #| {"schema":1,"course":"lesson","observations":["source"],
    #| "rules":[{"id":"combine","needs":["source"],"yields":"verified"}],
    #| "claims":[{"objective":"compare","needs":["verified"],"transfer":false}],
    #| "tasks":[{"item":"assessment","context":"new","independent":true,
    #| "observations":[{"fact":"verified","rubric":"Claims the result"}]}]}
  let result = Ok(analyze(report, profile)) catch { error => Err(error) }
  guard result is Err(InvalidProfile(message)) else {
    fail("expected invalid asserted conclusion")
  }
  assert_true(message.contains("not an observable fact"))
}
