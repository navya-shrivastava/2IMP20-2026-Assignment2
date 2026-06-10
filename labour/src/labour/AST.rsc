module labour::AST

/*
 * Abstract Syntax for LaBouR
 *
 * This mirrors the Ecore metamodel from Assignment 1 (labour.ecore) but expressed
 * as Rascal algebraic data types. Each concept gets one data declaration.
 *
 * DESIGN DECISIONS:
 *
 * 1. POSITION: We keep a single Position type with two constructors, matching the
 *    Ecore model which used one class with x/y/angle fields. cartesianPos carries
 *    x and y; angularPos carries an angle. The checker enforces which constructor
 *    is valid in which context.
 *
 * 2. HOLD LABEL: Rather than separate boolean flags (isEndHold) and an int
 *    (startHold 0/1/2) as in the Ecore model, we use an algebraic type HoldLabel
 *    with three constructors. This is more idiomatic Rascal and avoids the "0 means
 *    no label" sentinel anti-pattern.
 *
 * 3. HOLD SEQUENCE ENTRIES: The route's holds list contains HoldEntry values which
 *    are either a singleEntry (one hold ID) or a splitEntry (two hold IDs). This
 *    maps directly to SingleHoldReference and SplitHoldReference in the Ecore model.
 *    Note: in the Ecore model SplitHoldReference had full branch sequences; here we
 *    keep it simpler — just two IDs per split — because the grammar only allows
 *    exactly two IDs inside {}, and sub-routes are resolved by the checker/transformation.
 *
 * 4. VOLUME HOLDS: Rather than separate constructors per face list, each volume
 *    carries named lists (frontHolds, sideHolds, etc.) as list[Hold]. Missing lists
 *    default to empty ([]) in CST2AST. The checker verifies that holds only appear
 *    in valid face lists for their volume type.
 *
 * 5. COLOUR: Modelled as a string rather than an enum. The checker validates that
 *    the string is one of the nine legal values. This avoids needing a separate
 *    data type for a simple enumeration.
 *
 * 6. OPTIONAL FIELDS: Rascal does not have null/optional natively. We use sentinel
 *    values: rotation = -1 means "no rotation specified", which the checker then
 *    ignores for range validation. An alternative would be Maybe[int] but that
 *    complicates CST2AST with no real benefit at this scale.
 *
 * 7. SOURCE LOCATIONS: All AST nodes carry an optional src field (type loc) set
 *    during CST2AST. This enables precise error reporting in the checker. We use
 *    keyword parameters (anno-style) rather than positional so the field is truly
 *    optional and callers that don't need locations can omit it.
 */

// ─── Colour ──────────────────────────────────────────────────────────────────

// Represented as a plain string; legal values validated in Check.rsc.
alias Colour = str;

// ─── Position ────────────────────────────────────────────────────────────────

data Position
  = cartesianPos(int x, int y)        // used by most holds and all volume positions
  | angularPos(int angle)             // used only by side_holds inside circle volumes
  ;

// ─── Hold label ──────────────────────────────────────────────────────────────

data HoldLabel
  = startHold(int n)   // n must be 1 or 2 — checked in Check.rsc
  | endHold()
  | noLabel()
  ;

// ─── Hold ────────────────────────────────────────────────────────────────────

data Hold
  = hold(
      str        id,           // four-character digit string, e.g. "0001"
      Position   position,
      str        shape,
      list[Colour] colours,    // at least one colour
      int        rotation,     // -1 means absent (design decision 6)
      HoldLabel  label         // startHold(n), endHold(), or noLabel()
    )
  ;

// ─── Volume ──────────────────────────────────────────────────────────────────

data Volume
  = circleVolume(
      Position   pos,
      int        depth,
      int        radius,
      list[Hold] frontHolds,
      list[Hold] sideHolds
    )
  | triangleVolume(
      Position     pos,
      Position     extrusion,
      int          depth,
      list[Position] corners,   // must have exactly 3 — checked
      list[Hold]   leftHolds,
      list[Hold]   rightHolds,
      list[Hold]   bottomHolds
    )
  ;

// ─── Route ───────────────────────────────────────────────────────────────────

// An entry in the route's holds sequence.
data HoldEntry
  = singleEntry(str holdId)
  | splitEntry(str holdId1, str holdId2)
  ;

data BoulderingRoute
  = boulderingRoute(
      str            id,
      str            grade,
      Position       gridBasePoint,
      list[HoldEntry] holds
    )
  ;

// ─── Wall (root) ─────────────────────────────────────────────────────────────

data BoulderingWall
  = boulderingWall(
      str                    id,
      list[BoulderingRoute]  routes,
      list[Volume]           volumes
    )
  ;
