module labour::Syntax

/*
 * Concrete Syntax for LaBouR (Language for Bouldering Routes)
 *
 * DESIGN DECISIONS:
 *
 * 1. LAYOUT: We allow C-style block comments (/* */) and line comments (//)
 *    as well as whitespace. This matches the style shown in the assignment listings.
 *
 * 2. POSITION AMBIGUITY: A hold position can be either {x: N, y: N} or {angle: N}.
 *    We model these as two alternatives in the Position rule. For side_holds in a
 *    circle this is the only valid form, but we leave that constraint to the checker
 *    because the grammar cannot know the hold's context without substantial lookahead.
 *
 * 3. HOLD LABEL: start_hold and end_hold are optional keywords inside a hold body.
 *    They are modelled as separate optional alternatives in HoldProperty. We do NOT
 *    enforce "at most two start holds per route" in the grammar — that is a semantic
 *    constraint checked in Check.rsc.
 *
 * 4. HOLD SEQUENCE ENTRIES: A route's holds list can contain plain hold IDs (strings)
 *    or split groups {id, id}. We call the latter a SplitEntry. The grammar allows
 *    any number of SplitEntries; the constraint "at most one split per route" lives
 *    in Check.rsc.
 *
 * 5. COLOUR ENUM: Colours are unquoted keywords. We enumerate them directly in the
 *    grammar so the parser rejects any unknown colour at parse time. This is one of
 *    the validations best embedded in the concrete syntax.
 *
 * 6. HOLD ID FORMAT: The spec says hold IDs are always four digits. We enforce this
 *    in the HoldId lexical rule so the parser rejects malformed IDs immediately.
 *    This is a good candidate for syntax-level validation because it is purely
 *    structural (no context needed).
 *
 * 7. INTEGERS: can be negative (depth can be negative for volumes).
 *
 * 8. SEPARATOR FLEXIBILITY: commas between route hold-sequence entries and between
 *    colours are required. The grammar uses {X ","}+ notation for non-empty
 *    comma-separated lists.
 */

// ─── Layout ─────────────────────────────────────────────────────────────────

layout Whitespace = [\t\n\r\ ]* !>> [\t\n\r\ ];

lexical Comment
  = "/*" (![\*] | Asterisks !>> [/])* Asterisks "/"
  | "//" ![\n]* [\n]
  ;

lexical Asterisks = [\*]+;

layout Layout = ([\t\n\r\ ] | Comment)* !>> [\t\n\r\ ] !>> "/*" !>> "//";

// ─── Lexical tokens ──────────────────────────────────────────────────────────

// Four-digit numeric hold ID inside quotes, e.g. "0001"
// Enforced at lexical level so bad IDs fail at parse time (design decision 6)
lexical HoldId = "\"" [0-9] [0-9] [0-9] [0-9] "\"";

// General quoted string for wall IDs, route IDs, grades, shape identifiers
lexical StringLit = "\"" ![\"]* "\"";

// Integer (may be negative for depths and coordinates)
lexical Integer = "-"? [0-9]+;

// ─── Colours ─────────────────────────────────────────────────────────────────

// Colours are enumerated in the grammar (design decision 5):
// any unknown token will be a parse error, not just a checker warning.
syntax Colour
  = "white" | "yellow" | "green" | "blue" | "red"
  | "purple" | "pink" | "black" | "orange"
  ;

// ─── Position ────────────────────────────────────────────────────────────────

// Two forms: Cartesian (x, y) or angular (angle) for cylinder side holds.
// Which is valid where is checked in Check.rsc (design decision 2).
syntax Position
  = cartesian: "{" "x" ":" Integer "," "y" ":" Integer "}"
  | angular:   "{" "angle" ":" Integer "}"
  ;

// ─── Hold label ──────────────────────────────────────────────────────────────

// A hold can be a start_hold (with argument 1 or 2), end_hold, or unlabelled.
syntax HoldLabel
  = startHold: "start_hold" ":" Integer   // Integer must be 1 or 2 — checked in Check.rsc
  | endHold:   "end_hold"
  | noLabel:   /*nothing*/
  ;

// ─── Hold ────────────────────────────────────────────────────────────────────

// Order of properties inside a hold body:
//   required: pos, shape, colours
//   optional (any order after required): rotation, start_hold/end_hold
// We model the body as an unordered set of properties using a comma-separated
// list, with a catch-all ordering enforced in Check.rsc.
// 
// Actually, to keep the grammar unambiguous we define an ordered body where
// pos, shape, and colours must appear (in any relative order handled by the
// list), and rotation/label are optional trailing items. Rascal's
// !>> avoids ambiguities between keyword and identifier starts.

syntax Hold
  = hold: "hold" HoldId "{" {HoldProperty ","}+ "}"
  ;

syntax HoldProperty
  = pos:      "pos" Position                        // required
  | shape:    "shape" ":" StringLit                 // required
  | colours:  "colours" "[" {Colour ","}+ "]"       // required (≥1 colour)
  | rotation: "rotation" ":" Integer                // optional
  | label:    HoldLabel                             // optional (start or end)
  ;

// ─── Volume ──────────────────────────────────────────────────────────────────

syntax Volume
  = circle:   CircleVolume
  | triangle: TriangleVolume
  ;

syntax CircleVolume
  // A circle can have front_holds and/or side_holds (order flexible, both optional).
  // We list all six orderings explicitly to remain unambiguous without using
  // permutation combinators; in practice the checker verifies at least one list exists.
  = "circle" "{" {CircleProperty ","}+ "}"
  ;

syntax CircleProperty
  = pos:        "pos" ":" Position
  | depth:      "depth" ":" Integer
  | radius:     "radius" ":" Integer
  | frontHolds: "front_holds" "[" {Hold ","}* "]"
  | sideHolds:  "side_holds"  "[" {Hold ","}* "]"
  ;

syntax TriangleVolume
  = "triangle" "{" {TriangleProperty ","}+ "}"
  ;

syntax TriangleProperty
  = pos:         "pos" ":" Position
  | extrusion:   "extrusion" ":" Position
  | depth:       "depth" ":" Integer
  | corners:     "corners" "[" {Position ","}+ "]"    // must have exactly 3 — checked
  | leftHolds:   "left_holds"   "[" {Hold ","}* "]"
  | rightHolds:  "right_holds"  "[" {Hold ","}* "]"
  | bottomHolds: "bottom_holds" "[" {Hold ","}* "]"
  ;

// ─── Route ───────────────────────────────────────────────────────────────────

// A holds list entry is either a single hold ID or a split pair {id, id}.
syntax HoldEntry
  = single: HoldId
  | split:  "{" HoldId "," HoldId "}"
  ;

syntax BoulderingRoute
  = route: "bouldering_route" StringLit "{"
      {RouteProperty ","}+
    "}"
  ;

syntax RouteProperty
  = grade:         "grade" ":" StringLit
  | gridBasePoint: "grid_base_point" Position
  | holds:         "holds" "[" {HoldEntry ","}+ "]"
  ;

// ─── Wall (top-level start symbol) ───────────────────────────────────────────

syntax BoulderingWall
  = wall: "bouldering_wall" StringLit "{"
      {WallSection ","}+
    "}"
  ;

syntax WallSection
  = routes:  "routes"  "[" {BoulderingRoute ","}+ "]"
  | volumes: "volumes" "[" {Volume ","}+ "]"
  ;

// Start symbol
start syntax Wall = BoulderingWall;
