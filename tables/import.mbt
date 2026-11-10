///|
pub suberror TableError {
  InvalidTable(String)
}

///|
fn bad(table : String, row : Int32, message : String) -> TableError {
  InvalidTable("\{table} row \{row}: \{message}")
}

///|
fn rows(
  source : String,
  table : String,
  header : String,
  limit : Int32,
) -> Array[Array[String]] raise TableError {
  guard source.length() <= 2000000 else {
    raise bad(table, 1, "table exceeds two million code units")
  }
  let lines = source[:]
    .strip_suffix("\n")
    .unwrap_or(source[:])
    .to_owned()
    .split("\n")
  let first = lines.next().unwrap_or("")
  let first = first.strip_prefix("\ufeff").unwrap_or(first)
  guard first.strip_suffix("\r").unwrap_or(first) == header[:] else {
    raise bad(table, 1, "expected columns \{header}")
  }
  let records = []
  for line in lines {
    let row = records.length() + 2
    guard records.length() < limit else {
      raise bad(table, row, "too many rows")
    }
    let cells = line
      .strip_suffix("\r")
      .unwrap_or(line)
      .to_owned()
      .split("\t")
      .map(cell => cell.to_owned())
      .collect()
    guard cells.length() == 5 else {
      raise bad(table, row, "expected 5 tab-separated cells")
    }
    records.push(cells)
  }
  records
}

///|
fn integer(
  cell : String,
  table : String,
  row : Int32,
  field : String,
) -> Int32 raise TableError {
  @string.parse_int(cell, base=10) catch {
    _ => raise bad(table, row, "expected an integer in \{field}")
  }
}

///|
/// Import three UTF-8 TSV tables into a validated course blueprint.
pub fn import_tables(
  course~ : String,
  title~ : String,
  objectives~ : String,
  evidence~ : String,
  links~ : String,
) -> @alignment.Blueprint raise TableError {
  let goals : Array[@alignment.Objective] = []
  for
    index, cells in rows(
      objectives, "objectives", "id\ttitle\tlevel\tminimum_points\trequire_rehearsal",
      200,
    ) {
    let row = index + 2
    let rehearsal = match cells[4] {
      "true" => true
      "false" => false
      _ =>
        raise bad("objectives", row, "require_rehearsal must be true or false")
    }
    goals.push({
      id: cells[0],
      title: cells[1],
      level: integer(cells[2], "objectives", row, "level"),
      minimum_points: integer(cells[3], "objectives", row, "minimum_points"),
      require_rehearsal: rehearsal,
    })
  }
  let items : Array[@alignment.Evidence] = []
  let by_id : Map[String, Int32] = Map([])
  for
    index, cells in rows(
      evidence, "evidence", "id\ttitle\tphase\tkind\tpoints", 1000,
    ) {
    let row = index + 2
    guard !by_id.contains(cells[0]) else {
      raise bad("evidence", row, "duplicate item ID")
    }
    by_id[cells[0]] = index
    items.push({
      id: cells[0],
      title: cells[1],
      phase: integer(cells[2], "evidence", row, "phase"),
      kind: cells[3],
      points: integer(cells[4], "evidence", row, "points"),
      links: [],
    })
  }
  for
    index, cells in rows(
      links, "links", "item_id\tobjective\tlevel\tpoints\tcriterion", 200000,
    ) {
    let row = index + 2
    guard by_id.get(cells[0]) is Some(item) else {
      raise bad("links", row, "unknown item ID")
    }
    items[item].links.push({
      objective: cells[1],
      level: integer(cells[2], "links", row, "level"),
      points: integer(cells[3], "links", row, "points"),
      criterion: cells[4],
    })
  }
  let plan : @alignment.Blueprint = {
    schema: 1,
    course,
    title,
    objectives: goals,
    evidence: items,
  }
  guard plan.to_json().stringify().length() <= 2000000 else {
    raise InvalidTable("combined blueprint exceeds two million code units")
  }
  ignore(@alignment.audit_blueprint(plan)) catch {
    error => raise InvalidTable(error.message())
  }
  plan
}
