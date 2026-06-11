module labour::Syntax

/*
 * concrete syntax for LaBouR (Language for Bouldering Routes)
 *
 * a few things the grammar can't enforce on its own are left to Check.rsc:
 * - which position form (cartesian vs angular) is valid in which context
 * - at most two start holds per route
 * - at most one split per route
 * - exactly 3 corners per triangle
 *
 * colours are enumerated here so unknown colour names are parse errors,
 * not just checker warnings. hold IDs are four-digit strings for the same
 * reason — purely structural, no context needed.
 */

layout Whitespace = [\t\n\r\ ]* !>> [\t\n\r\ ];

lexical Comment
  = "/*" (![\*] | Asterisks !>> [/])* Asterisks "/"
  | "//" ![\n]* [\n]
  ;

lexical Asterisks = [\*]+;

layout Layout = ([\t\n\r\ ] | Comment)* !>> [\t\n\r\ ] !>> "/*" !>> "//";

// four-digit hold ID in quotes, e.g. "0001" — bad IDs fail at parse time
lexical HoldId = "\"" [0-9] [0-9] [0-9] [0-9] "\"";

// general quoted string for wall/route IDs, grades, shape identifiers
lexical StringLit = "\"" ![\"]* "\"";

// may be negative (depths, coordinates)
lexical Integer = "-"? [0-9]+;

syntax Colour
  = "white" | "yellow" | "green" | "blue" | "red"
  | "purple" | "pink" | "black" | "orange"
  ;

// cartesian for most holds; angular only for side_holds in circle volumes
syntax Position
  = cartesian: "{" "x" ":" Integer "," "y" ":" Integer "}"
  | angular:   "{" "angle" ":" Integer "}"
  ;

// integer must be 1 or 2 — checked in Check.rsc
syntax HoldLabel
  = startHold: "start_hold" ":" Integer
  | endHold:   "end_hold"
  | noLabel:   /*nothing*/
  ;

syntax Hold
  = hold: "hold" HoldId "{" {HoldProperty ","}+ "}"
  ;

syntax HoldProperty
  = pos:      "pos" Position                       // required
  | shape:    "shape" ":" StringLit                // required
  | colours:  "colours" "[" {Colour ","}+ "]"      // required (≥1 colour)
  | rotation: "rotation" ":" Integer               // optional
  | label:    HoldLabel                            // optional
  ;

syntax Volume
  = circle:   CircleVolume
  | triangle: TriangleVolume
  ;

syntax CircleVolume
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
  | corners:     "corners" "[" {Position ","}+ "]"   // must have exactly 3, checked in Check.rsc
  | leftHolds:   "left_holds"   "[" {Hold ","}* "]"
  | rightHolds:  "right_holds"  "[" {Hold ","}* "]"
  | bottomHolds: "bottom_holds" "[" {Hold ","}* "]"
  ;

// a holds list entry is either a single hold ID or a split pair {id, id}
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

syntax BoulderingWall
  = wall: "bouldering_wall" StringLit "{"
      {WallSection ","}+
    "}"
  ;

syntax WallSection
  = routes:  "routes"  "[" {BoulderingRoute ","}+ "]"
  | volumes: "volumes" "[" {Volume ","}+ "]"
  ;

start syntax Wall = BoulderingWall;
