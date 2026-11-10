# Proofbell

课程上线前，拿课程目标对照一遍练习和考核。Proofbell 根据教师填写的目标、题目、评分细则和教学阶段，找出低层次考核、来得太晚的练习和未归属分值。每条判断都能追到题目和评分细则。

## 先校一次 AI 素养课

使用 MoonBit（本地验证版本为 moonc 0.10.20）与 Node.js 22.3 或更新版本。在仓库根目录运行：

```sh
moon run brief -- audit curricula/ai-literacy/draft.json
```

样例中的 AI 引用术语题给“核验原始文献”分了 20 分，但只考 DOI 的含义。这 20 分不会被计为达标证据。另一个目标有足够的考核分值，却把同伴练习排在考核之后。报告也会指出编辑说明题剩余的 5 分。

追加 `--json` 可供教研工具读取。退出码 0 表示蓝图满足规则，1 表示有需复核的缺口，2 表示调用或输入失败。所有处理在本机完成，样例为虚构课程材料。

## 对照改版前后

```sh
moon run brief -- compare curricula/ai-literacy/draft.json curricula/ai-literacy/revised.json
```

新版把术语选择题改为原始文献核验，安排同伴互审先于编辑说明题，并取消未归属的 5 分。对比显示两个目标的缺口已补齐，未归属分值从 5 变为 0。若直接改了目标文字、等级或分值要求，报告会请教师重新判断。

把 [教师研修](curricula/teacher-workshop.json) 或 [岗位培训](curricula/workplace-training.json) 复制一份，即可用自己的题目替换。填表字段和判定条件见 [蓝图说明](curricula/blueprint.md)。

## 带着审阅单开教研会

```sh
moon run brief -- review-sheet curricula/ai-literacy/draft.json > review.html
```

在浏览器离线打开生成的 HTML，可打印或用浏览器另存 PDF。审阅单按目标列出题号、评分细则、达标分值和先行练习缺口，每个目标留有记录标注依据与修改决定的空白。示例有缺口，命令会生成报告并返回退出码 1。

## 设计边界

`alignment/` 是独立 MoonBit 库，`audit(String)` 接收课程蓝图并返回可序列化的报告。`brief/` 负责本地文件读取和展示。`curricula/` 保存可复验的课程蓝图。

目标要求、证据映射、任务难度均由课程设计者判断。程序检查这些声明是否一致。报告用于课前审阅，无法据此判断学生的实际掌握程度。

```sh
moon check --deny-warn
moon test --deny-warn
```

初版的实现、构造样例和测试由 AI 辅助起草并运行验证。课程标注与规则适用性留待参赛者复核，见 [复核记录](curricula/review.md)。
