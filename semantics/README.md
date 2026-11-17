# 教学证据规则

用 `moon run brief -- semantics <蓝图.json> <规则配置.json>` 审查课前设计。给当前蓝图附上配置即可，既有 JSON 和 TSV 输入仍可使用原来的命令。MoonBit 应用可调用 `@semantics.analyze(@alignment.audit_blueprint(plan), profile_json)`，也可从文件蓝图调用 `@alignment.audit`。

| 配置 | 含义 |
| --- | --- |
| `schema` / `course` | 模式版本固定为 1，课程编号与蓝图相同 |
| `observations` | 可直接从评分细则确认的事实编号 |
| `rules` | 一条规则的 `needs` 必须全部成立，才推出 `yields`。多条规则可分别推出同一结论 |
| `claims` | 每个目标一条声明。需在同一项考核中得到全部 `needs`，`transfer` 表示是否还要求跨情境练习 |
| `tasks` | 记录题目 `item`、情境 `context`、是否独立完成 `independent`，以及每条事实对应的 `rubric` 摘录 |

规则在单项任务内反复执行，直到无法再推出新事实。不同任务的事实各自保留。只有明确声明的可观察事实可直接录入，派生结论须由规则推出。循环规则在有可观察证据时可以参与推导，缺少支持时不会凭循环产生结论。报告中的 `derivations` 记录评分摘录和规则依据，`blocked_rules` 记录各条未满足规则的前提。若同一结论有多条路径，`missing_observations` 汇总这些路径涉及的缺失事实，修订时可选择满足其中一条完整路径。

独立考核须达到蓝图要求的等级。开启迁移检查时，至少要有一项达到同样证据要求、阶段更早、材料情境不同的练习。同一阶段不视为有先后。分数和时序仍由蓝图审计单独检查，报告里的 `blueprint_ready` 与 `findings` 可分别查看。

课程团队负责将评分细则映射到事实，并判断两个情境是否有实质差异。工具根据这些输入判断任务设计能提供哪些证据。输出用于课前教研，学生实际表现需要通过实施后的作答或操作记录评估。

## 对照样例

| 蓝图与规则 | 预期 | 核对项 |
| --- | --- | --- |
| 引文核验与 `independent.json` | 退出 0 | 从出处定位和原文摘录推出可复查原文，再结合比较结论支持核验目标 |
| 同一蓝图与 `missing-evidence.json` | 退出 1 | 仍能推出原文可复查，但缺少 `claim-comparison` |
| 同一蓝图与 `reused-material.json` | 退出 1 | 核验事实齐备，练习和考核使用相同材料情境 |
| 教师研修与 `teacher-profile.json` | 退出 0 | 新图表的替代文本同时满足描述数据和回答读者任务的要求 |
| 岗位培训与 `training-profile.json` | 退出 1 | 只有看图识标练习，缺少能支撑模拟状态确认的先行练习 |

样例均为构造材料。仓库根目录运行 `moon run verify.mbtx --deny-warn` 会执行上述对照及既有工作流。
