module labour::CST2AST

/*
 * CST to AST transformation for LaBouR
 *
 * Each function converts one concrete syntax tree node (from Syntax.rsc)
 * into the corresponding AST node (from AST.rsc).
 *
 * DESIGN DECISIONS:
 *
 * 1. ONE MAPPING PER LANGUAGE CONSTRUCT: Each syntax rule gets exactly one
 *    cst2ast function. We never use Rascal's built-in implode — every mapping
 *    is written explicitly so the transformation is fully understood.
 *
 * 2. STRING UNQUOTING: HoldId and StringLit tokens include their surrounding
 *    double-quotes. We strip them with unquote() which just slices [1..-1].
 *
 * 3. MISSING OPTIONAL PROPERTIES: The hold body properties (pos, shape, colours,
 *    rotation, label) may appear in any order and some are optional. We collect
 *    them into a map keyed by property type and then extract each field with a
 *    default. This is cleaner than trying to pattern-match every permutation.
 *
 * 4. VOLUME PROPERTIES: Same approach as holds — collect into a map, extract
 *    with defaults (empty list for hold lists, etc.).
 *
 * 5. INTEGER PARSING: Rascal parse trees carry integer tokens as strings.
 *    We convert them with toInt(). The negation sign is part of the Integer
 *    lexical so toInt handles it correctly.
 *
 * 6. LOCATION PROPAGATION: We do not attach src locations in this submission
 *    for brevity, but the checker can still produce useful error messages by
 *    identifying the violating AST node by its field values.
 */

import labour::Syntax;
import labour::AST;
import String;
import List;
import IO;

// ─── Entry point ─────────────────────────────────────────────────────────────

public BoulderingWall cst2ast(start[Wall] pt) = cst2ast(pt.top);

public BoulderingWall cst2ast((Wall)`<BoulderingWall w>`) = cst2ast(w);

// ─── Wall ────────────────────────────────────────────────────────────────────

public BoulderingWall cst2ast((BoulderingWall)`bouldering_wall <StringLit wallId> { <{WallSection ","}+ sections> }`) {
    list[BoulderingRoute] routes = [];
    list[Volume]          vols   = [];

    for (WallSection s <- sections) {
        switch (s) {
            case (WallSection)`routes [ <{BoulderingRoute ","}+ rs> ]`:
                routes = [cst2ast(r) | BoulderingRoute r <- rs];
            case (WallSection)`volumes [ <{Volume ","}+ vs> ]`:
                vols = [cst2ast(v) | Volume v <- vs];
        }
    }

    return boulderingWall(unquote("<wallId>"), routes, vols);
}

// ─── Route ───────────────────────────────────────────────────────────────────

public BoulderingRoute cst2ast((BoulderingRoute)`bouldering_route <StringLit routeId> { <{RouteProperty ","}+ props> }`) {
    str            grade  = "";
    Position       gbp    = cartesianPos(0, 0);
    list[HoldEntry] holds = [];

    for (RouteProperty p <- props) {
        switch (p) {
            case (RouteProperty)`grade : <StringLit g>`:
                grade = unquote("<g>");
            case (RouteProperty)`grid_base_point <Position pos>`:
                gbp = cst2ast(pos);
            case (RouteProperty)`holds [ <{HoldEntry ","}+ entries> ]`:
                holds = [cst2ast(e) | HoldEntry e <- entries];
        }
    }

    return boulderingRoute(unquote("<routeId>"), grade, gbp, holds);
}

// ─── Hold entry (route sequence element) ─────────────────────────────────────

public HoldEntry cst2ast((HoldEntry)`<HoldId hid>`) =
    singleEntry(unquote("<hid>"));

public HoldEntry cst2ast((HoldEntry)`{ <HoldId h1> , <HoldId h2> }`) =
    splitEntry(unquote("<h1>"), unquote("<h2>"));

// ─── Volume ───────────────────────────────────────────────────────────────────

public Volume cst2ast((Volume)`<CircleVolume c>`) = cst2ast(c);
public Volume cst2ast((Volume)`<TriangleVolume t>`) = cst2ast(t);

public Volume cst2ast((CircleVolume)`circle { <{CircleProperty ","}+ props> }`) {
    Position   pos        = cartesianPos(0, 0);
    int        depth      = 0;
    int        radius     = 0;
    list[Hold] frontHolds = [];
    list[Hold] sideHolds  = [];

    for (CircleProperty p <- props) {
        switch (p) {
            case (CircleProperty)`pos : <Position pos2>`:
                pos = cst2ast(pos2);
            case (CircleProperty)`depth : <Integer d>`:
                depth = toInt("<d>");
            case (CircleProperty)`radius : <Integer r>`:
                radius = toInt("<r>");
            case (CircleProperty)`front_holds [ <{Hold ","}* hs> ]`:
                frontHolds = [cst2ast(h) | Hold h <- hs];
            case (CircleProperty)`side_holds [ <{Hold ","}* hs> ]`:
                sideHolds = [cst2ast(h) | Hold h <- hs];
        }
    }

    return circleVolume(pos, depth, radius, frontHolds, sideHolds);
}

public Volume cst2ast((TriangleVolume)`triangle { <{TriangleProperty ","}+ props> }`) {
    Position       pos         = cartesianPos(0, 0);
    Position       extrusion   = cartesianPos(0, 0);
    int            depth       = 0;
    list[Position] corners     = [];
    list[Hold]     leftHolds   = [];
    list[Hold]     rightHolds  = [];
    list[Hold]     bottomHolds = [];

    for (TriangleProperty p <- props) {
        switch (p) {
            case (TriangleProperty)`pos : <Position pos2>`:
                pos = cst2ast(pos2);
            case (TriangleProperty)`extrusion : <Position e>`:
                extrusion = cst2ast(e);
            case (TriangleProperty)`depth : <Integer d>`:
                depth = toInt("<d>");
            case (TriangleProperty)`corners [ <{Position ","}+ cs> ]`:
                corners = [cst2ast(c) | Position c <- cs];
            case (TriangleProperty)`left_holds [ <{Hold ","}* hs> ]`:
                leftHolds = [cst2ast(h) | Hold h <- hs];
            case (TriangleProperty)`right_holds [ <{Hold ","}* hs> ]`:
                rightHolds = [cst2ast(h) | Hold h <- hs];
            case (TriangleProperty)`bottom_holds [ <{Hold ","}* hs> ]`:
                bottomHolds = [cst2ast(h) | Hold h <- hs];
        }
    }

    return triangleVolume(pos, extrusion, depth, corners, leftHolds, rightHolds, bottomHolds);
}

// ─── Hold ────────────────────────────────────────────────────────────────────

public Hold cst2ast((Hold)`hold <HoldId hid> { <{HoldProperty ","}+ props> }`) {
    Position      pos      = cartesianPos(0, 0);
    str           shape    = "";
    list[Colour]  colours  = [];
    int           rotation = -1;    // sentinel: not specified
    HoldLabel     label    = noLabel();

    for (HoldProperty p <- props) {
        switch (p) {
            case (HoldProperty)`pos <Position pos2>`:
                pos = cst2ast(pos2);
            case (HoldProperty)`shape : <StringLit s>`:
                shape = unquote("<s>");
            case (HoldProperty)`colours [ <{Colour ","}+ cs> ]`:
                colours = [cst2ast(c) | Colour c <- cs];
            case (HoldProperty)`rotation : <Integer r>`:
                rotation = toInt("<r>");
            case (HoldProperty)`<HoldLabel l>`:
                label = cst2ast(l);
        }
    }

    return hold(unquote("<hid>"), pos, shape, colours, rotation, label);
}

// ─── Hold label ──────────────────────────────────────────────────────────────

public HoldLabel cst2ast((HoldLabel)`start_hold : <Integer n>`) = startHold(toInt("<n>"));
public HoldLabel cst2ast((HoldLabel)`end_hold`)                  = endHold();
public HoldLabel cst2ast((HoldLabel)` `)                         = noLabel();  // empty alternative

// ─── Position ────────────────────────────────────────────────────────────────

public Position cst2ast((Position)`{ x : <Integer x> , y : <Integer y> }`) =
    cartesianPos(toInt("<x>"), toInt("<y>"));

public Position cst2ast((Position)`{ angle : <Integer a> }`) =
    angularPos(toInt("<a>"));

// ─── Colour ──────────────────────────────────────────────────────────────────

// Each colour keyword maps to a plain string in the AST.
public Colour cst2ast((Colour)`white`)  = "white";
public Colour cst2ast((Colour)`yellow`) = "yellow";
public Colour cst2ast((Colour)`green`)  = "green";
public Colour cst2ast((Colour)`blue`)   = "blue";
public Colour cst2ast((Colour)`red`)    = "red";
public Colour cst2ast((Colour)`purple`) = "purple";
public Colour cst2ast((Colour)`pink`)   = "pink";
public Colour cst2ast((Colour)`black`)  = "black";
public Colour cst2ast((Colour)`orange`) = "orange";

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Remove surrounding double quotes from a string token.
private str unquote(str s) = substring(s, 1, size(s) - 1);
