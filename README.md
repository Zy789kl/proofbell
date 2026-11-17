# Proofbell

Proofbell 帮助教师在开课前核对课程目标、练习与考核。安装 [MoonBit](https://www.moonbitlang.com/download/) 和 [Node.js](https://nodejs.org/) 22.3 或更新版本，在仓库根目录运行以下示例。

## 检查题目能否提供目标所需的证据

一份考核可以同时满足任务等级、分值与时序要求，却没有要求学员交出足以支撑目标的产物。Proofbell 的教学证据检查将评分细则中的可观察要求表示为事实，通过课程团队编写的规则推导它们支持的能力。报告可追到具体题目、评分条目、推导规则和缺失前提。对于要求迁移的目标，还要找到一项更早、情境不同且具备完整证据的练习，并在新情境中安排独立考核。

```sh
moon run brief -- semantics curricula/semantic/blueprint.json curricula/semantic/independent.json
moon run brief -- semantics curricula/semantic/blueprint.json curricula/semantic/missing-evidence.json
moon run brief -- semantics curricula/semantic/blueprint.json curricula/semantic/reused-material.json
```

三次使用同一份课程蓝图，原来的等级、分值和时序检查均通过。完整核验任务通过教学证据检查，删去「比较原文与主张」后返回 1，并指出缺失的评分要求。复用练习材料也返回 1，因为样例要求在不同情境展示同一能力。规则文件与库接口见 [教学证据规则](semantics/README.md)。

## 先校一次 AI 素养课

项目使用 moonc `0.10.20+65efd5b93` 验证。克隆仓库后可运行基础审计：

```sh
git clone https://github.com/Zy789kl/proofbell.git
cd proofbell
moon run brief -- audit curricula/ai-literacy/draft.json
```

样例中的 AI 引用术语题给“核验原始文献”分了 20 分，但只考 DOI 的含义。这 20 分不会被计为达标证据。另一个目标有足够的考核分值，却把同伴练习排在考核之后。报告也会指出编辑说明题剩余的 5 分。

追加 `--json` 可供教研工具读取。退出码 0 表示蓝图满足规则，1 表示有需复核的缺口，2 表示调用或输入失败。所有处理在本机完成，样例为虚构课程材料。

`moon run brief -- repairs curricula/ai-literacy/draft.json` 可提取教研会上要处理的事项，列出缺多少分、练习与考核的实际阶段，以及哪道题还有分值需要归属。追加 `--json` 可供其他工具接入。

## 对照改版前后

```sh
moon run brief -- compare curricula/ai-literacy/draft.json curricula/ai-literacy/revised.json
```

新版把术语选择题改为原始文献核验，安排同伴互审先于编辑说明题，并取消未归属的 5 分。对比显示两个目标的缺口已补齐，编辑说明题的未归属分值从 5 变为 0。若直接改了目标文字、等级或分值要求，报告会请教师重新判断。分值总量相同但换了题目时，对比也会逐题显示变动。

教研团队逐步整理旧课时，可用 `moon run brief -- gate <旧版.json> <新版.json>` 做改版检查。它以 JSON 给出需复核的变更，新增或扩大的缺口、删除目标、变更目标要求都会返回退出码 1。原有缺口保持不变时，`accepted` 可以为真，但新版仍须通过独立审计才会得到 `ready: true`。

把 [教师研修](curricula/teacher-workshop.json) 或 [岗位培训](curricula/workplace-training.json) 复制一份，即可用自己的题目替换。填表字段和判定条件见 [蓝图说明](curricula/blueprint.md)。

同时复核多门课时，可汇总各课程达标目标数量和未归属分值：

```sh
moon run brief -- portfolio curricula/ai-literacy/revised.json curricula/teacher-workshop.json curricula/workplace-training.json
```

结果是 JSON，按输入顺序列出课程，分值保留在各自课程内。每个课程编号只可出现一次。此例有一门课需要复核，因此返回 1。

## 从表格导入蓝图

目标、活动和评分映射也可从电子表格整理成三份 UTF-8 TSV。以 [实验课样例](curricula/lab-tables/) 为模板，保留首行字段名，每个单元格使用单行文本。导入后沿用相同的蓝图校验：

```sh
moon run brief -- import-table lab "实验课" curricula/lab-tables/objectives.tsv curricula/lab-tables/evidence.tsv curricula/lab-tables/links.tsv --output lab.json
moon run brief -- audit lab.json
```

## 带着审阅单开教研会

```sh
moon run brief -- review-sheet curricula/ai-literacy/draft.json --output review.html
```

在浏览器离线打开生成的 HTML，可打印或用浏览器另存 PDF。审阅单按目标列出题号、评分细则、达标分值和先行练习缺口，每个目标留有记录标注依据与修改决定的空白。示例有缺口，命令会生成报告并返回退出码 1。

`--output` 创建 UTF-8 文件，目标文件已存在时返回退出码 2。省略该选项时结果写到标准输出，便于接入其他命令。

## 设计边界

`alignment/` 是独立 MoonBit 库，`audit(String)` 接收 JSON 蓝图并返回可序列化的报告。已有结构化课程数据的调用方可用 `audit_blueprint` 与 `compare_blueprints`，见 [MoonBit 接入示例](alignment/README.mbt.md)。`brief/` 负责本地文件读取和展示。`curricula/` 保存可复验的课程蓝图。

目标要求、证据映射、任务难度均由课程设计者判断。程序检查这些声明是否一致。报告用于课前审阅，无法据此判断学生的实际掌握程度。

```sh
moon check --deny-warn
moon test --deny-warn
moon run verify.mbtx --deny-warn
moon package --list
```

`moon package --list` 在本地构建发布包并列出包含的文件。可用包内的 `alignment/` 接入示例核对库的调用方式。

项目按 MIT 许可证发布。核心逻辑与审阅单为原创实现，核心库只使用 MoonBit 标准库，命令行使用 Node.js 内置模块读写。仓库中的课程蓝图为构造样例，未使用学生档案、第三方试题库或私有课程材料。工具链生成的接口文件为 `pkg.generated.mbti`。

实现、构造样例、测试与文档使用了 AI 辅助。课程标注与规则适用性留待参赛者复核，见 [复核记录](curricula/review.md)。历次功能变动见 [更新记录](CHANGELOG.md)。
