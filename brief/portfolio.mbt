///|
fn portfolio(paths : ArrayView[String]) -> Bool raise {
  guard paths.length() >= 1 && paths.length() <= 100 else {
    raise UsageError("请提供 1–100 份不同课程的蓝图")
  }
  let reports = []
  for index, path in paths {
    let report = @alignment.audit(read_blueprint(path)) catch {
      @alignment.InvalidBlueprint(message) =>
        raise UsageError("第 \{index + 1} 份蓝图 · \{message}")
      UsageError(message) =>
        raise UsageError("第 \{index + 1} 份蓝图 · \{message}")
      error => raise error
    }
    reports.push(report)
  }
  let portfolio = @alignment.portfolio(reports)
  println(portfolio.to_json().stringify(indent=2))
  portfolio.ready
}
