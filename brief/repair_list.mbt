///|
fn repair_list(path : String, json : Bool) -> Bool raise {
  let report = @alignment.audit(read_blueprint(path))
  let tasks = @alignment.repairs(report)
  if json {
    let result : Json = {
      "course": Json(report.course),
      "ready": Json(report.ready),
      "tasks": Json(tasks),
    }
    println(result.stringify(indent=2))
  } else {
    for task in tasks {
      let note = match task.kind {
        "assessment_shortfall" =>
          "尚缺 \{task.amount.unwrap_or(0)} 分达标考核证据"
        "rehearsal_missing" => "补充达到目标等级的先行练习"
        "rehearsal_late" =>
          "达标练习在第 \{task.rehearsal_phase.unwrap_or(0)} 阶段，首次达标考核在第 \{task.assessment_phase.unwrap_or(0)} 阶段，请调整顺序"
        "unallocated_marks" =>
          "核对 \{task.amount.unwrap_or(0)} 分的评分归属"
        _ => "核对练习是否需要关联课程目标"
      }
      println("\{task.target} · \{note}")
    }
    if tasks.is_empty() {
      println("当前蓝图无需整改")
    }
  }
  report.ready
}
