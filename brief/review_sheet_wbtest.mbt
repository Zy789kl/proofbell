///|
test "review sheet treats course and rubric text as HTML data" {
  let report = @alignment.audit(
    (
      #| {
      #|   "schema": 1, "course": "markup", "title": "<script>alert(1)</script>",
      #|   "objectives": [
      #|     {"id": "identify", "title": "Recognize < and &", "level": 2,
      #|      "minimum_points": 4, "require_rehearsal": true}
      #|   ],
      #|   "evidence": [
      #|     {"id": "quiz", "title": "<img src=x>", "phase": 2,
      #|      "kind": "assessment", "points": 7,
      #|      "links": [{"objective": "identify", "level": 1, "points": 4,
      #|                 "criterion": "Explain \"x & y\"."}]}
      #|   ]
      #| }
    ),
  )
  let page = render_review_sheet(report)
  assert_false(page.contains("<script>"))
  assert_false(page.contains("<img "))
  assert_true(page.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
  assert_true(page.contains("&lt;img src=x&gt;"))
  assert_true(page.contains("Explain &quot;x &amp; y&quot;."))
  assert_true(page.contains("达标分值 0 / 4"))
  assert_true(page.contains("未归属 3 分"))
  assert_true(
    page.contains("缺少在首次达标考核之前安排的达标练习"),
  )
}

///|
test "review sheet marks unmapped practice and leaves room for teacher notes" {
  let report = @alignment.audit(
    (
      #| {
      #|   "schema": 1, "course": "empty-trace", "title": "New module",
      #|   "objectives": [
      #|     {"id": "apply", "title": "Apply the workflow", "level": 3,
      #|      "minimum_points": 4, "require_rehearsal": false}
      #|   ],
      #|   "evidence": [
      #|     {"id": "demo", "title": "Demo", "phase": 1,
      #|      "kind": "practice", "points": 0, "links": []}
      #|   ]
      #| }
    ),
  )
  let page = render_review_sheet(report)
  assert_true(page.contains("此目标没有关联的练习或考核"))
  assert_true(page.contains("<li><code>demo</code></li>"))
  assert_true(page.contains("标注依据"))
  assert_true(page.contains("拟调整内容"))
}
