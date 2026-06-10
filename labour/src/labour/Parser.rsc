module labour::Parser

/*
 * Parser for LaBouR
 *
 * Provides a single public function parseLaBouR(loc) that reads the file at
 * the given location and returns the concrete parse tree (CST) rooted at the
 * start symbol Wall.
 *
 * DESIGN DECISION:
 * We import the start symbol Wall from Syntax and call Rascal's built-in
 * parse/2. The function signature takes a loc (file location) so callers
 * can point it at a .labour file on disk. We also expose a convenience
 * overload that accepts a string literal for unit-testing grammar rules
 * without touching the file system.
 */

import labour::Syntax;
import ParseTree;

// Parse a .labour file on disk.
public start[Wall] parseLaBouR(loc input) {
    return parse(#start[Wall], input);
}

// Convenience overload for testing: parse a LaBouR program from a string.
public start[Wall] parseLaBouR(str src) {
    return parse(#start[Wall], src);
}
