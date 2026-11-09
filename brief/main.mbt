///|
suberror UsageError {
  UsageError(String)
}

///|
fn read_blueprint(path : String) -> String raise UsageError {
  let result = read_input(path)
  guard result[0].is_empty() else {
    raise UsageError("读取课程文件失败（\{result[0]}）")
  }
  result[1]
}

///|
fn show_audit(report : @alignment.Report) -> Unit {
  println("# \{report.title}")
  for goal in report.objectives {
    let status = if goal.ready { "通过" } else { "需复核" }
    println("\n[\{status}] \{goal.objective} · \{goal.title}")
    println(
      "  达标考核分值 \{goal.qualifying_points} / \{goal.minimum_points}",
    )
    if !goal.rehearsal_ready {
      println("  缺少安排在首次达标考核之前的达标练习")
    }
    for row in goal.trace {
      let kind = if row.kind == "practice" { "练习" } else { "考核" }
      let level = if row.meets_level { "达标" } else { "低于目标要求" }
      println(
        "  第 \{row.phase} 阶段 · \{kind} \{row.item_id} \{row.item_title} · L\{row.level} \{level} · \{row.points} 分",
      )
      println("    \{row.criterion}")
    }
  }
  println(
    "\n考核总分 \{report.assessment_points}，未归属分值 \{report.unallocated_points}",
  )
  for remainder in report.point_remainders {
    println(
      "未归属分值 · \{remainder.item_id} \{remainder.item_title} · \{remainder.points} 分",
    )
  }
  for id in report.unmapped_evidence {
    println("未关联目标的活动或题目 · \{id}")
  }
}

///|
fn run(args : FixedArray[String]) -> Int32 raise {
  let (path, json) = match args[:] {
    ["audit", path] => (path, false)
    ["audit", path, "--json"] => (path, true)
    _ =>
      raise UsageError(
        "用法：moon run brief -- audit <课程.json> [--json]",
      )
  }
  let report = @alignment.audit(read_blueprint(path))
  if json {
    println(report.to_json().stringify(indent=2))
  } else {
    show_audit(report)
  }
  if report.ready {
    0
  } else {
    1
  }
}

///|
fn main {
  let status = run(arguments()) catch {
    UsageError(message) => {
      stderr(message)
      2
    }
    @alignment.InvalidBlueprint(message) => {
      stderr(message)
      2
    }
    _ => {
      stderr("无法完成课程审计")
      2
    }
  }
  set_status(status)
}
