module labour::Parser

/*
 * parses a .labour file and returns the CST rooted at Wall.
 * the string overload is handy for testing grammar rules without
 * touching the file system.
 */

import labour::Syntax;
import ParseTree;

public start[Wall] parseLaBouR(loc input) {
    return parse(#start[Wall], input);
}

public start[Wall] parseLaBouR(str src) {
    return parse(#start[Wall], src);
}
