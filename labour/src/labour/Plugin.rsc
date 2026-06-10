module labour::Plugin

/*
 * Plugin entry point for LaBouR in VS Code via Rascal's language server.
 *
 * Calling main() registers .labour files with VS Code so that:
 *   - Syntax highlighting activates when a .labour file is opened.
 *   - Parse errors are shown inline if the file does not conform to the grammar.
 *
 * checkWellformedness(str path) parses and checks a single .labour file,
 * returning true if it is valid and printing any errors to the console.
 */

import labour::Syntax;
import labour::Parser;
import labour::CST2AST;
import labour::Check;
import ParseTree;
import util::LanguageServer;
import util::IDEServices;
import Set;
import IO;

public void main() {
    registerLanguage(
        language(
            pathConfig(srcs = [|project://labour/src|]),
            "LaBouR",
            "labour",
            "labour::Plugin",
            "contribution"
        )
    );
}

public set[Message] contribution(start[Wall] pt) {
    return checkBoulderRouteConfiguration(cst2ast(pt));
}

public bool checkWellformedness(str path) {
    loc fileLoc = toLocation(path);
    try {
        start[Wall] pt = parseLaBouR(fileLoc);
        set[Message] msgs = checkBoulderRouteConfiguration(cst2ast(pt));
        if (isEmpty(msgs)) {
            println("OK: <path> is a valid LaBouR specification.");
            return true;
        } else {
            println("ERRORS in <path>:");
            for (Message m <- msgs)
                println("  <m>");
            return false;
        }
    } catch ParseError(loc l): {
        println("Parse error in <path> at <l>");
        return false;
    }
}
