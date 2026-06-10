module labour::Check

/*
 * Well-formedness checker for LaBouR
 *
 * Implements checkBoulderRouteConfiguration(BoulderingWall w) which returns
 * a set of error messages. An empty set means the model is valid.
 *
 * Each check corresponds to a numbered rule from Section 2.2 of the assignment.
 *
 * DESIGN DECISIONS:
 *
 * 1. RETURN TYPE: We return set[Message] (using Rascal's Message type from the
 *    Message module). Each error is an error(str msg, loc src) value. Where we
 *    have no source location we use |unknown:///| as a placeholder.
 *
 * 2. HOLD LOOKUP: Several checks need to look up a hold by ID across all volumes.
 *    We build a map[str, Hold] once at the wall level and pass it through.
 *
 * 3. COLOUR INTERSECTION: Rule 11 says all holds in a route must share at least
 *    one colour. We compute the intersection of all colour sets and check it is
 *    non-empty.
 *
 * 4. SPLIT COUNTING: Rules 4 and 8 concern splits. We scan the holds list once,
 *    tracking whether we have seen a split and whether we have seen a merge after
 *    a split. A merge is detected when we see a singleEntry after a splitEntry.
 *
 * 5. SEPARATE CONCERNS: Checks that are structurally impossible to express in the
 *    grammar (colour intersection, split ordering, count constraints) are all here.
 *    The grammar already enforces: valid colour names (rule 15), four-digit hold IDs
 *    (rule 9), exactly two IDs per split group.
 */

import labour::AST;
import Set;
import List;
import String;
import Message;
import Map;
import IO;

// Valid colour names (rule 15) — also enforced by grammar, but kept here
// for completeness in case the AST is constructed programmatically.
set[str] VALID_COLOURS = {"white","yellow","green","blue","red","purple","pink","black","orange"};

// ─── Entry point ─────────────────────────────────────────────────────────────

public set[Message] checkBoulderRouteConfiguration(BoulderingWall w) {
    set[Message] msgs = {};

    // Build a flat map of all hold IDs to Hold AST nodes for lookup.
    map[str, Hold] holdMap = collectHolds(w);

    // Rule 1: every wall must have at least one volume and one route.
    if (isEmpty(w.routes))
        msgs += {error("Wall \"<w.id>\" must have at least one route.", |unknown:///|)};
    if (isEmpty(w.volumes))
        msgs += {error("Wall \"<w.id>\" must have at least one volume.", |unknown:///|)};

    // Check each route.
    for (BoulderingRoute r <- w.routes)
        msgs += checkRoute(r, holdMap);

    // Check each volume.
    for (Volume v <- w.volumes)
        msgs += checkVolume(v);

    return msgs;
}

// ─── Route checks ────────────────────────────────────────────────────────────

private set[Message] checkRoute(BoulderingRoute r, map[str, Hold] holdMap) {
    set[Message] msgs = {};
    str rid = "Route \"<r.id>\"";

    // Rule 5: every route must have a grade, grid_base_point, and identifier.
    // grade and id are strings; empty string means missing.
    if (r.grade == "")
        msgs += {error("<rid>: grade is missing.", |unknown:///|)};
    if (r.id == "")
        msgs += {error("A route is missing its identifier.", |unknown:///|)};
    // gridBasePoint always has a constructor so it can't be structurally absent.

    // Rule 6: grid_base_point must have x and y.
    if (angularPos(_) := r.gridBasePoint)
        msgs += {error("<rid>: grid_base_point must be a Cartesian position (x, y), not angular.", |unknown:///|)};

    // Rule 2: every route must have two or more holds.
    if (size(r.holds) < 2)
        msgs += {error("<rid>: must have at least 2 holds (found <size(r.holds)>).", |unknown:///|)};

    // Rules 3, 4, 7, 8 require scanning the holds list.
    msgs += checkHoldSequence(r, holdMap);

    // Rule 11: all holds in the route must share at least one colour.
    msgs += checkRouteColours(r, holdMap);

    return msgs;
}

// Checks rules 3, 4, 7, 8 by scanning the holds sequence once.
private set[Message] checkHoldSequence(BoulderingRoute r, map[str, Hold] holdMap) {
    set[Message] msgs = {};
    str rid = "Route \"<r.id>\"";

    int  splitCount  = 0;
    bool mergedAfterSplit = false;
    bool seenSplit   = false;
    int  startCount  = 0;
    int  endCount    = 0;

    for (HoldEntry e <- r.holds) {
        switch (e) {
            case singleEntry(str hid): {
                // After a split, a singleEntry is a merge point.
                if (seenSplit) mergedAfterSplit = true;

                // Count start/end holds.
                if (hid in holdMap) {
                    Hold h = holdMap[hid];
                    visit (h.label) {
                        case startHold(int n): startCount += 1;
                        case endHold():        endCount   += 1;
                    }
                }
            }
            case splitEntry(str h1, str h2): {
                splitCount += 1;

                // Rule 8: no new split after a merge.
                if (mergedAfterSplit)
                    msgs += {error("<rid>: a second split appears after a merge, which is not allowed.", |unknown:///|)};

                seenSplit = true;

                // Count end holds inside split branches.
                for (str hid <- [h1, h2]) {
                    if (hid in holdMap) {
                        Hold h = holdMap[hid];
                        if (endHold() := h.label) endCount += 1;
                    }
                }
            }
        }
    }

    // Rule 3: between zero and two hand start holds.
    if (startCount > 2)
        msgs += {error("<rid>: has <startCount> start holds; maximum is 2.", |unknown:///|)};

    // Rule 4: at most one split.
    if (splitCount > 1)
        msgs += {error("<rid>: has <splitCount> split points; at most one is allowed.", |unknown:///|)};

    // Rule 7: at most two end holds (if split) or one end hold (if no split).
    int maxEnd = seenSplit ? 2 : 1;
    if (endCount > maxEnd)
        msgs += {error("<rid>: has <endCount> end holds; maximum is <maxEnd> for this route.", |unknown:///|)};

    return msgs;
}

// Rule 11: all holds in the route share at least one colour.
private set[Message] checkRouteColours(BoulderingRoute r, map[str, Hold] holdMap) {
    set[Message] msgs = {};

    // Collect all hold IDs referenced by this route (flatten split entries).
    list[str] allIds = [];
    for (HoldEntry e <- r.holds) {
        switch (e) {
            case singleEntry(str hid):       allIds += [hid];
            case splitEntry(str h1, str h2): allIds += [h1, h2];
        }
    }

    // Only check holds that actually exist in the wall.
    list[set[str]] colourSets = [];
    for (str hid <- allIds) {
        if (hid in holdMap) {
            Hold h = holdMap[hid];
            colourSets += [toSet(h.colours)];
        }
    }

    if (!isEmpty(colourSets)) {
        set[str] intersection = colourSets[0];
        for (set[str] cs <- tail(colourSets))
            intersection = intersection & cs;

        if (isEmpty(intersection))
            msgs += {error("Route \"<r.id>\": not all holds share a common colour.", |unknown:///|)};
    }

    return msgs;
}

// ─── Hold checks ─────────────────────────────────────────────────────────────

private set[Message] checkHold(Hold h) {
    set[Message] msgs = {};
    str hid = "Hold \"<h.id>\"";

    // Rule 9: hold ID must be exactly four digits (grammar enforces this,
    // but we check here too for programmatically constructed ASTs).
    if (!(/^[0-9]{4}$/ := h.id))
        msgs += {error("<hid>: hold ID must be exactly four digits.", |unknown:///|)};

    // Rule 12: every hold must have a position, shape, and colour.
    if (isEmpty(h.colours))
        msgs += {error("<hid>: must have at least one colour.", |unknown:///|)};
    if (h.shape == "")
        msgs += {error("<hid>: shape is missing.", |unknown:///|)};

    // Rule 13: if position is angular, angle must be 0–359.
    if (angularPos(int a) := h.position) {
        if (a < 0 || a > 359)
            msgs += {error("<hid>: angular position <a> must be between 0 and 359.", |unknown:///|)};
    }

    // Rule 14: rotation must be 0–359 if present.
    if (h.rotation != -1) {
        if (h.rotation < 0 || h.rotation > 359)
            msgs += {error("<hid>: rotation <h.rotation> must be between 0 and 359.", |unknown:///|)};
    }

    // Rule 15: colour values must be valid.
    for (Colour c <- h.colours) {
        if (c notin VALID_COLOURS)
            msgs += {error("<hid>: \"<c>\" is not a valid colour.", |unknown:///|)};
    }

    // Rule 3 contribution: start_hold argument must be 1 or 2.
    if (startHold(int n) := h.label) {
        if (n != 1 && n != 2)
            msgs += {error("<hid>: start_hold argument must be 1 or 2 (got <n>).", |unknown:///|)};
    }

    return msgs;
}

// ─── Volume checks ───────────────────────────────────────────────────────────

private set[Message] checkVolume(Volume v) {
    set[Message] msgs = {};

    switch (v) {
        case circleVolume(Position pos, int depth, int radius, list[Hold] fh, list[Hold] sh): {
            // Rule 17: circular volume must have radius, depth and position.
            // All are always present structurally; we check they are sensible.
            // (pos is always set, depth/radius always parsed)

            // Rule 18: front_holds holds must use cartesian position.
            for (Hold h <- fh) {
                if (angularPos(_) := h.position)
                    msgs += {error("Hold \"<h.id>\" is in front_holds but uses an angular position; front_holds require (x,y).", |unknown:///|)};
                msgs += checkHold(h);
            }
            // side_holds must use angular position.
            for (Hold h <- sh) {
                if (cartesianPos(_,_) := h.position)
                    msgs += {error("Hold \"<h.id>\" is in side_holds but uses a Cartesian position; side_holds require an angle.", |unknown:///|)};
                msgs += checkHold(h);
            }
        }
        case triangleVolume(Position pos, Position extrusion, int depth,
                            list[Position] corners,
                            list[Hold] lh, list[Hold] rh, list[Hold] bh): {
            // Rule 19: triangular volume must have exactly 3 corners.
            if (size(corners) != 3)
                msgs += {error("A triangle volume must have exactly 3 corners (found <size(corners)>).", |unknown:///|)};

            // Check all holds in each face list.
            for (Hold h <- lh + rh + bh)
                msgs += checkHold(h);
        }
    }

    return msgs;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Build a flat map from hold ID to Hold covering all volumes' face lists.
private map[str, Hold] collectHolds(BoulderingWall w) {
    map[str, Hold] m = ();
    for (Volume v <- w.volumes) {
        list[Hold] allHolds = [];
        switch (v) {
            case circleVolume(_, _, _, list[Hold] fh, list[Hold] sh):
                allHolds = fh + sh;
            case triangleVolume(_, _, _, _, list[Hold] lh, list[Hold] rh, list[Hold] bh):
                allHolds = lh + rh + bh;
        }
        for (Hold h <- allHolds)
            m[h.id] = h;
    }
    return m;
}
