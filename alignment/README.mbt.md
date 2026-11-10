# 从 MoonBit 接入 Proofbell

教务系统已经持有课程目标和评分细则时，可以直接构造 `Blueprint` 并调用 `audit_blueprint`。核心库只依赖 MoonBit 标准库。文件导入使用 `audit`，两种入口执行相同的校验。

```mbt check
///|
test "audit a lab rubric supplied by a calling application" {
  let plan : @alignment.Blueprint = {
    schema: 1,
    course: "lab",
    title: "Lab exercise",
    objectives: [
      {
        id: "verify",
        title: "Verify the result",
        level: 3,
        minimum_points: 4,
        require_rehearsal: false,
      },
    ],
    evidence: [
      {
        id: "station",
        title: "Lab station",
        phase: 2,
        kind: "assessment",
        points: 4,
        links: [
          {
            objective: "verify",
            level: 3,
            points: 4,
            criterion: "Check the measured value against the reference",
          },
        ],
      },
    ],
  }
  let report = @alignment.audit_blueprint(plan)
  assert_true(report.ready)
  assert_eq(report.objectives[0].qualifying_points, 4)
}
```

`compare_blueprints` 可对比使用同一课程编号的两份蓝图。课程目标和题目各自使用稳定编号。报告按新版顺序输出变更，移除项按旧版顺序附后。JSON 报告也提供每道题未归属分值的前后状态，以及未关联项目的增减。
