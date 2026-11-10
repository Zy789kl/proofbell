///|
fn gate(before : String, after : String) -> Bool raise {
  let comparison = @alignment.compare(
    read_blueprint(before),
    read_blueprint(after),
  )
  let flags = @alignment.gate_flags(comparison)
  let result : Json = {
    "course": Json(comparison.course),
    "accepted": Json(flags.is_empty()),
    "ready": Json(comparison.ready),
    "flags": Json(flags),
  }
  println(result.stringify(indent=2))
  flags.is_empty()
}
