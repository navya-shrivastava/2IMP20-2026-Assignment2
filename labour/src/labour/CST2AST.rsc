module labour::CST2AST

/*
 * CST to AST transformation for LaBouR
 *
 * each function converts one parse tree node (from Syntax.rsc) into the
 * corresponding AST node (from AST.rsc). every mapping is explicit —
 * no use of rascal's built-in implode.
 *
 * HoldId and StringLit tokens include their surrounding quotes;
 * unquote() strips them.
 */

import labour::Syntax;
import labour::AST;
import String;
import List;
import IO;

public BoulderingWall cst2ast(start[Wall] pt) = cst2ast(pt.top);

public BoulderingWall cst2ast((Wall)`<BoulderingWall w>`) = cst2ast(w);

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

public BoulderingRoute cst2ast((BoulderingRoute)`bouldering_route <StringLit routeId> { <{RouteProperty ","}+ props> }`) {
    str             grade = "";
    Position        gbp   = cartesianPos(0, 0);
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

public HoldEntry cst2ast((HoldEntry)`<HoldId hid>`) =
    singleEntry(unquote("<hid>"));

public HoldEntry cst2ast((HoldEntry)`{ <HoldId h1> , <HoldId h2> }`) =
    splitEntry(unquote("<h1>"), unquote("<h2>"));

public Volume cst2ast((Volume)`<CircleVolume c>`)   = cst2ast(c);
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

public Hold cst2ast((Hold)`hold <HoldId hid> { <{HoldProperty ","}+ props> }`) {
    Position     pos      = cartesianPos(0, 0);
    str          shape    = "";
    list[Colour] colours  = [];
    int          rotation = -1;   // -1 means not specified
    HoldLabel    label    = noLabel();

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

public HoldLabel cst2ast((HoldLabel)`start_hold : <Integer n>`) = startHold(toInt("<n>"));
public HoldLabel cst2ast((HoldLabel)`end_hold`)                  = endHold();
public HoldLabel cst2ast((HoldLabel)` `)                         = noLabel();  // empty alternative

public Position cst2ast((Position)`{ x : <Integer x> , y : <Integer y> }`) =
    cartesianPos(toInt("<x>"), toInt("<y>"));

public Position cst2ast((Position)`{ angle : <Integer a> }`) =
    angularPos(toInt("<a>"));

public Colour cst2ast((Colour)`white`)  = "white";
public Colour cst2ast((Colour)`yellow`) = "yellow";
public Colour cst2ast((Colour)`green`)  = "green";
public Colour cst2ast((Colour)`blue`)   = "blue";
public Colour cst2ast((Colour)`red`)    = "red";
public Colour cst2ast((Colour)`purple`) = "purple";
public Colour cst2ast((Colour)`pink`)   = "pink";
public Colour cst2ast((Colour)`black`)  = "black";
public Colour cst2ast((Colour)`orange`) = "orange";

// strips surrounding double quotes from a string token
private str unquote(str s) = substring(s, 1, size(s) - 1);
