module labour::Check

/*
 * well-formedness checker for LaBouR
 *
 * checkBoulderRouteConfiguration(BoulderingWall w) returns a set[Message].
 * an empty set means the model is valid. each check corresponds to a
 * numbered rule from section 2.2 of the assignment.
 *
 * things that can't be expressed in the grammar (colour intersection,
 * split ordering, count constraints) are all handled here. the grammar
 * already enforces: valid colour names (rule 15), four-digit hold IDs
 * (rule 9), exactly two IDs per split group.
 */

import labour::AST;
import Set;
import List;
import String;
import Message;
import Map;
import IO;

// also enforced by the grammar, but kept here for programmatically constructed ASTs
set[str] VALID_COLOURS = {"white","yellow","green","blue","red","purple","pink","black","orange"};

public set[Message] checkBoulderRouteConfiguration(BoulderingWall w) {
    set[Message] msgs = {};

    map[str, Hold] holdMap = collectHolds(w);

    // rule 1: at least one route and one volume
    if (isEmpty(w.routes))
        msgs += {error("Wall \"<w.id>\" must have at least one route.", |unknown:///|)};
    if (isEmpty(w.volumes))
        msgs += {error("Wall \"<w.id>\" must have at least one volume.", |unknown:///|)};

    for (BoulderingRoute r <- w.routes)
        msgs += checkRoute(r, holdMap);

    for (Volume v <- w.volumes)
        msgs += checkVolume(v);

    return msgs;
}

private set[Message] checkRoute(BoulderingRoute r, map[str, Hold] holdMap) {
    set[Message] msgs = {};
    str rid = "Route \"<r.id>\"";

    // rule 5: grade and id must be present (empty string means missing)
    if (r.grade == "")
        msgs += {error("<rid>: grade is missing.", |unknown:///|)};
    if (r.id == "")
        msgs += {error("A route is missing its identifier.", |unknown:///|)};

    // rule 6: grid_base_point must be cartesian
    if (angularPos(_) := r.gridBasePoint)
        msgs += {error("<rid>: grid_base_point must be a Cartesian position (x, y), not angular.", |unknown:///|)};

    // rule 2: at least 2 holds
    if (size(r.holds) < 2)
        msgs += {error("<rid>: must have at least 2 holds (found <size(r.holds)>).", |unknown:///|)};

    msgs += checkHoldSequence(r, holdMap);
    msgs += checkRouteColours(r, holdMap);

    return msgs;
}

// covers rules 3, 4, 7, 8 in a single pass over the holds list
private set[Message] checkHoldSequence(BoulderingRoute r, map[str, Hold] holdMap) {
    set[Message] msgs = {};
    str rid = "Route \"<r.id>\"";

    int  splitCount       = 0;
    bool mergedAfterSplit = false;
    bool seenSplit        = false;
    int  startCount       = 0;
    int  endCount         = 0;

    for (HoldEntry e <- r.holds) {
        switch (e) {
            case singleEntry(str hid): {
                if (seenSplit) mergedAfterSplit = true;

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

                // rule 8: no new split after a merge
                if (mergedAfterSplit)
                    msgs += {error("<rid>: a second split appears after a merge, which is not allowed.", |unknown:///|)};

                seenSplit = true;

                for (str hid <- [h1, h2]) {
                    if (hid in holdMap) {
                        Hold h = holdMap[hid];
                        if (endHold() := h.label) endCount += 1;
                    }
                }
            }
        }
    }

    // rule 3: max 2 start holds
    if (startCount > 2)
        msgs += {error("<rid>: has <startCount> start holds; maximum is 2.", |unknown:///|)};

    // rule 4: max 1 split
    if (splitCount > 1)
        msgs += {error("<rid>: has <splitCount> split points; at most one is allowed.", |unknown:///|)};

    // rule 7: max 2 end holds if there's a split, otherwise max 1
    int maxEnd = seenSplit ? 2 : 1;
    if (endCount > maxEnd)
        msgs += {error("<rid>: has <endCount> end holds; maximum is <maxEnd> for this route.", |unknown:///|)};

    return msgs;
}

// rule 11: all holds in the route must share at least one colour
private set[Message] checkRouteColours(BoulderingRoute r, map[str, Hold] holdMap) {
    set[Message] msgs = {};

    list[str] allIds = [];
    for (HoldEntry e <- r.holds) {
        switch (e) {
            case singleEntry(str hid):       allIds += [hid];
            case splitEntry(str h1, str h2): allIds += [h1, h2];
        }
    }

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

private set[Message] checkHold(Hold h) {
    set[Message] msgs = {};
    str hid = "Hold \"<h.id>\"";

    // grammar enforces four-digit IDs, but check again for programmatically built ASTs
    if (!(/^[0-9]{4}$/ := h.id))
        msgs += {error("<hid>: hold ID must be exactly four digits.", |unknown:///|)};

    // rule 12
    if (isEmpty(h.colours))
        msgs += {error("<hid>: must have at least one colour.", |unknown:///|)};
    if (h.shape == "")
        msgs += {error("<hid>: shape is missing.", |unknown:///|)};

    // rule 13
    if (angularPos(int a) := h.position) {
        if (a < 0 || a > 359)
            msgs += {error("<hid>: angular position <a> must be between 0 and 359.", |unknown:///|)};
    }

    // rule 14
    if (h.rotation != -1) {
        if (h.rotation < 0 || h.rotation > 359)
            msgs += {error("<hid>: rotation <h.rotation> must be between 0 and 359.", |unknown:///|)};
    }

    // rule 15
    for (Colour c <- h.colours) {
        if (c notin VALID_COLOURS)
            msgs += {error("<hid>: \"<c>\" is not a valid colour.", |unknown:///|)};
    }

    if (startHold(int n) := h.label) {
        if (n != 1 && n != 2)
            msgs += {error("<hid>: start_hold argument must be 1 or 2 (got <n>).", |unknown:///|)};
    }

    return msgs;
}

private set[Message] checkVolume(Volume v) {
    set[Message] msgs = {};

    switch (v) {
        case circleVolume(Position pos, int depth, int radius, list[Hold] fh, list[Hold] sh): {
            // rule 18: front_holds require cartesian, side_holds require angular
            for (Hold h <- fh) {
                if (angularPos(_) := h.position)
                    msgs += {error("Hold \"<h.id>\" is in front_holds but uses an angular position; front_holds require (x,y).", |unknown:///|)};
                msgs += checkHold(h);
            }
            for (Hold h <- sh) {
                if (cartesianPos(_,_) := h.position)
                    msgs += {error("Hold \"<h.id>\" is in side_holds but uses a Cartesian position; side_holds require an angle.", |unknown:///|)};
                msgs += checkHold(h);
            }
        }
        case triangleVolume(Position pos, Position extrusion, int depth,
                            list[Position] corners,
                            list[Hold] lh, list[Hold] rh, list[Hold] bh): {
            // rule 19: exactly 3 corners
            if (size(corners) != 3)
                msgs += {error("A triangle volume must have exactly 3 corners (found <size(corners)>).", |unknown:///|)};

            for (Hold h <- lh + rh + bh)
                msgs += checkHold(h);
        }
    }

    return msgs;
}

// builds a flat id -> Hold map across all volumes
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
