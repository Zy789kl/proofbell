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
fn audit(path : String, json : Bool) -> Bool raise {
  let report = @alignment.audit(read_blueprint(path))
  if json {
    println(report.to_json().stringify(indent=2))
  } else {
    show_audit(report)
  }
  report.ready
}

///|
fn review_sheet(path : String) -> Bool raise {
  let report = @alignment.audit(read_blueprint(path))
  println(render_review_sheet(report))
  report.ready
}

///|
fn show_comparison(report : @alignment.Comparison) -> Unit {
  println("# 课程改版 · \{report.course}")
  for revision in report.changes {
    let label = match revision.change {
      "resolved" => "缺口已补齐"
      "regressed" => "出现新缺口"
      "requirements_changed" => "目标要求已变，需重新判断"
      "evidence_changed" => "证据有变化，达标状态相同"
      "added" => "新增目标"
      _ => "移除目标"
    }
    println("[\{label}] \{revision.objective}")
    for pair in [("旧版", revision.before), ("新版", revision.after)] {
      let (edition, finding) = pair
      if finding is Some(goal) {
        let practice = if goal.rehearsal_ready {
          "满足练习规则"
        } else {
          "缺少先行练习"
        }
        println(
          "  \{edition} · \{goal.title} · 达标分值 \{goal.qualifying_points} / \{goal.minimum_points} · \{practice}",
        )
      }
    }
  }
  println(
    "未归属分值 \{report.before_unallocated} → \{report.after_unallocated}",
  )
  for change in report.remainder_changes {
    let before = change.before.map(item => item.points).unwrap_or(0)
    let after = change.after.map(item => item.points).unwrap_or(0)
    println("  \{change.item_id} · \{before} → \{after} 分")
  }
  for id in report.newly_unmapped {
    println("新增未关联项 · \{id}")
  }
  for id in report.no_longer_unmapped {
    println("移出未关联清单 · \{id}")
  }
}

///|
fn compare(before : String, after : String, json : Bool) -> Bool raise {
  let report = @alignment.compare(read_blueprint(before), read_blueprint(after))
  if json {
    println(report.to_json().stringify(indent=2))
  } else {
    show_comparison(report)
  }
  report.ready
}

///|
fn run(args : FixedArray[String]) -> Int32 raise {
  let ready = match args[:] {
    ["audit", path] => audit(path, false)
    ["audit", path, "--json"] => audit(path, true)
    ["review-sheet", path] => review_sheet(path)
    ["compare", before, after] => compare(before, after, false)
    ["compare", before, after, "--json"] => compare(before, after, true)
    _ =>
      raise UsageError(
        "用法：moon run brief -- audit <课程.json> [--json]\n      moon run brief -- compare <旧版.json> <新版.json> [--json]\n      moon run brief -- review-sheet <课程.json>",
      )
  }
  if ready {
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
