module labour::AST

/*
 * abstract syntax for LaBouR — mirrors the ecore metamodel but as
 * rascal algebraic data types.
 *
 * a few things worth noting:
 * - angularPos is only valid for side_holds inside circle volumes;
 *   the checker enforces this, not the grammar.
 * - rotation = -1 is a sentinel meaning "not specified".
 * - HoldLabel replaces the ecore boolean/int flags with three clean constructors.
 */

// colour is just a string; valid values are checked in Check.rsc
alias Colour = str;

data Position
  = cartesianPos(int x, int y)
  | angularPos(int angle)
  ;

data HoldLabel
  = startHold(int n)   // n must be 1 or 2, checked in Check.rsc
  | endHold()
  | noLabel()
  ;

data Hold
  = hold(
      str          id,
      Position     position,
      str          shape,
      list[Colour] colours,    // at least one required
      int          rotation,   // -1 means absent
      HoldLabel    label
    )
  ;

data Volume
  = circleVolume(
      Position   pos,
      int        depth,
      int        radius,
      list[Hold] frontHolds,
      list[Hold] sideHolds
    )
  | triangleVolume(
      Position       pos,
      Position       extrusion,
      int            depth,
      list[Position] corners,   // must be exactly 3, checked in Check.rsc
      list[Hold]     leftHolds,
      list[Hold]     rightHolds,
      list[Hold]     bottomHolds
    )
  ;

// a single entry is one hold id; a split entry is a parallel pair
data HoldEntry
  = singleEntry(str holdId)
  | splitEntry(str holdId1, str holdId2)
  ;

data BoulderingRoute
  = boulderingRoute(
      str             id,
      str             grade,
      Position        gridBasePoint,
      list[HoldEntry] holds
    )
  ;

data BoulderingWall
  = boulderingWall(
      str                   id,
      list[BoulderingRoute] routes,
      list[Volume]          volumes
    )
  ;
