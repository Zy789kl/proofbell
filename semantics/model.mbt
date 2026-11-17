///|
#derive(FromJson)
priv struct Profile {
  schema : Int32
  course : String
  observations : Array[String]
  rules : Array[Rule]
  claims : Array[Claim]
  tasks : Array[Task]
}

///|
#derive(FromJson)
priv struct Rule {
  id : String
  needs : Array[String]
  yields : String
}

///|
#derive(FromJson)
priv struct Claim {
  objective : String
  needs : Array[String]
  transfer : Bool
}

///|
#derive(FromJson)
priv struct Task {
  item : String
  context : String
  independent : Bool
  observations : Array[Observation]
}

///|
#derive(FromJson)
priv struct Observation {
  fact : String
  rubric : String
}

///|
pub suberror SemanticError {
  InvalidProfile(String)
}

///|
#derive(ToJson)
pub struct Derivation {
  fact : String
  rubric : String?
  rule : String?
  premises : Array[String]
}

///|
#derive(ToJson)
pub struct Candidate {
  item : String
  context : String?
  missing : Array[String]
  derivations : Array[Derivation]
  blocked_rules : Array[BlockedRule]
  missing_observations : Array[String]
  independent : Bool
  transfer_from : String?
  status : String
}

///|
#derive(ToJson)
pub struct BlockedRule {
  rule : String
  conclusion : String
  missing : Array[String]
}

///|
pub extend BlockedRule with @json.ToJson::{to_json}

///|
#derive(ToJson)
pub struct ClaimFinding {
  objective : String
  witness : String?
  candidates : Array[Candidate]
}

///|
#derive(ToJson)
pub struct SemanticReport {
  course : String
  blueprint_ready : Bool
  ready : Bool
  findings : Array[ClaimFinding]
}

///|
pub extend Derivation with @json.ToJson::{to_json}

///|
pub extend Candidate with @json.ToJson::{to_json}

///|
pub extend ClaimFinding with @json.ToJson::{to_json}

///|
pub extend SemanticReport with @json.ToJson::{to_json}
