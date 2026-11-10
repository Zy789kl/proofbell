///|
fn html(text : String) -> String {
  let output = StringBuilder()
  for ch in text {
    match ch {
      '&' => output.write_string("&amp;")
      '<' => output.write_string("&lt;")
      '>' => output.write_string("&gt;")
      '"' => output.write_string("&quot;")
      '\'' => output.write_string("&#39;")
      _ => output.write_char(ch)
    }
  }
  output.to_string()
}

///|
let sheet_style : String =
  #| :root{color-scheme:light;--ink:#1e2828;--muted:#475954;--rule:#b8c5be;--paper:#fcfaf4;--review:#8c281f;--pass:#1c5d48}
  #| *{box-sizing:border-box}body{margin:0;color:var(--ink);background:var(--paper);font:1rem/1.6 system-ui,sans-serif}
  #| main{max-width:62rem;margin:auto;padding:clamp(1rem,5vw,4rem)}header{border-bottom:2px solid var(--ink);padding-bottom:1.5rem}
  #| h1,h2,h3,p{margin:0 0 .65rem}h1{font-size:clamp(1.75rem,4vw,2.75rem);line-height:1.25}h2{margin-top:2rem}
  #| .eyebrow{font-size:.85rem;font-weight:700;letter-spacing:.12em}.muted{color:var(--muted)}.review{color:var(--review)}.pass{color:var(--pass)}
  #| .review,.pass{font-weight:700}.goal{margin-top:1.5rem;padding-top:1rem;border-top:1px solid var(--rule)}
  #| .table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;margin:1rem 0;table-layout:fixed}
  #| caption{text-align:left;font-weight:600;margin-bottom:.35rem}th,td{text-align:left;vertical-align:top;padding:.55rem;border-bottom:1px solid var(--rule);overflow-wrap:anywhere}
  #| th:nth-child(1){width:34%}th:nth-child(2){width:26%}code{overflow-wrap:anywhere}
  #| .notes{display:grid;grid-template-columns:1fr 1fr;gap:1rem}.notes p{min-height:3rem;border-bottom:1px dotted var(--muted)}
  #| footer{margin-top:2rem;color:var(--muted);border-top:1px solid var(--rule);padding-top:1rem}
  #| @media(max-width:34rem){.notes{grid-template-columns:1fr}table{min-width:28rem}}
  #| @media print{main{max-width:none;padding:0}body{background:white}.table-wrap{overflow:visible}table{min-width:0}h2,h3{break-after:avoid}tr,.notes{break-inside:avoid}thead{display:table-header-group}}

///|
fn render_goal(out : StringBuilder, goal : @alignment.Finding) -> Unit {
  let (state_class, status) = if goal.ready {
    ("pass", "通过")
  } else {
    ("review", "需复核")
  }
  out.write_string(
    (
      $| <article class="goal">
      $| <h3><code>\{html(goal.objective)}</code> · \{html(goal.title)}</h3>
      $| <p><span class="\{state_class}">\{status}</span> · 要求 L\{goal.level} · 达标分值 \{goal.qualifying_points} / \{goal.minimum_points}</p>
    ),
  )
  if !goal.rehearsal_ready {
    out.write_string(
      "<p class=\"review\">缺少在首次达标考核之前安排的达标练习。</p>",
    )
  }
  if goal.trace.is_empty() {
    out.write_string("<p>此目标没有关联的练习或考核。</p>")
  } else {
    out.write_string(
      (
        $| <div class="table-wrap"><table><caption>逐项证据</caption>
        $| <thead><tr><th scope="col">题目或练习</th><th scope="col">阶段与要求</th><th scope="col">评分细则或产出</th></tr></thead><tbody>
      ),
    )
    for row in goal.trace {
      let kind = if row.kind == "assessment" { "考核" } else { "练习" }
      let demand = if row.meets_level { "达标" } else { "低于目标" }
      out.write_string(
        (
          $| <tr><td>\{html(row.item_title)}<br><code>\{html(row.item_id)}</code></td>
          $| <td>阶段 \{row.phase} · \{kind}<br>L\{row.level} · \{demand} · \{row.points} 分</td>
          $| <td>\{html(row.criterion)}</td></tr>
        ),
      )
    }
    out.write_string("</tbody></table></div>")
  }
  out.write_string(
    (
      $| <div class="notes"><p>标注依据</p><p>拟调整内容</p></div>
      $| </article>
    ),
  )
}

///|
fn render_review_sheet(report : @alignment.Report) -> String {
  let out = StringBuilder()
  let ready_count = report.objectives.fold(init=0, (count, goal) => {
    count + (if goal.ready { 1 } else { 0 })
  })
  let title = html(report.title)
  out.write_string(
    (
      $| <!doctype html>
      $| <html lang="zh-CN"><head><meta charset="utf-8">
      $| <meta name="viewport" content="width=device-width, initial-scale=1">
      $| <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
      $| <title>\{title} | Proofbell</title><style>\{sheet_style}</style></head><body><main>
      $| <header><p class="eyebrow">PROOFBELL / 课前审阅</p><h1>\{title}</h1>
      $| <p>目标通过 \{ready_count} / \{report.objectives.length()} · 考核总分 \{report.assessment_points} · 未归属 \{report.unallocated_points} 分</p>
      $| <p class="muted">复核人：________________　日期：________________</p></header>
      $| <h2>目标与证据</h2>
    ),
  )
  for goal in report.objectives {
    render_goal(out, goal)
  }
  if !report.point_remainders.is_empty() {
    out.write_string("<h2>未归属分值</h2><ul>")
    for item in report.point_remainders {
      out.write_string(
        "<li>\{html(item.item_title)} <code>\{html(item.item_id)}</code> · \{item.points} 分</li>",
      )
    }
    out.write_string("</ul>")
  }
  if !report.unmapped_evidence.is_empty() {
    out.write_string("<h2>未关联的题目与练习</h2><ul>")
    for id in report.unmapped_evidence {
      out.write_string("<li><code>\{html(id)}</code></li>")
    }
    out.write_string("</ul>")
  }
  out.write_string(
    (
      $| <footer>此报告根据录入的教学蓝图生成。等级与证据是否合理，以教师对实际题目和评分细则的复核为准。</footer>
      $| </main></body></html>
    ),
  )
  out.to_string()
}
