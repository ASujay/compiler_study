const std = @import("std");
const Io = std.Io;

const TokenType = enum {
    left_paran,
    right_paran,
    left_brace,
    right_brace,
    semi_colon,
    comma,
    // operators
    plus, // +
    star, // *
    equ, // =
    // compound types
    identifier,
    number,
    // keyword
    function, // function
    let, // let
    ret, // ret
    //eof, // eof

    const Self = @This();
    fn toString(self: Self) []const u8 {
        return switch (self) {
            .left_paran => "left_paran",
            .right_paran => "right_paran",
            .left_brace => "left_brace",
            .right_brace => "right_brace",
            .semi_colon => "semi_colon",
            .comma => "comma",
            .plus => "plus",
            .star => "star",
            .equ => "equ",
            .identifier => "identifier",
            .number => "number",
            .function => "function",
            .let => "let",
            .ret => "ret",
        };
    }
};

const Value = union(enum) {
    num_val: f64,
    identifier: []const u8,
};

const Token = struct {
    line_number: usize,
    line_start_offset: usize,
    start: usize,
    end: usize,
    token_type: TokenType,
    value: ?Value,

    const Self = @This();
    fn print(self: Self) void {
        std.debug.print("{c}\n", .{'{'});
        std.debug.print("\tline_number: {}\n", .{self.line_number});
        std.debug.print("\tline_start_offset: {}\n", .{self.line_start_offset});
        std.debug.print("\tstart: {}\n", .{self.start});
        std.debug.print("\tend: {}\n", .{self.end});
        std.debug.print("\ttoken_type: {s}\n", .{self.token_type.toString()});
        if (self.value) |value| {
            switch (value) {
                .num_val => |num| std.debug.print("\tvalue: {}\n", .{num}),
                .identifier => |lexeme| std.debug.print("\tvalue: {s}\n", .{lexeme}),
            }
        } else {
            std.debug.print("\tvalue: {s}\n", .{"..."});
        }
        std.debug.print("{c}\n", .{'}'});
    }
};

const LexerError = error{
    UnknownCharacter,
};

const Lexer = struct {
    src: []const u8,
    start: usize,
    current: usize,
    allocator: std.mem.Allocator,
    line_number: usize,
    line_start_offset: usize,
    keywords: std.StringHashMap(TokenType),
    has_error: bool,

    const Self = @This();

    fn init(src: []const u8, allocator: std.mem.Allocator) !Lexer {
        var keywords: std.StringHashMap(TokenType) = .init(allocator);
        try keywords.put("function", .function);
        try keywords.put("let", .let);
        try keywords.put("return", .ret);

        return Lexer{
            .src = src,
            .start = 0,
            .current = 0,
            .allocator = allocator,
            .line_number = 1,
            .line_start_offset = 0,
            .keywords = keywords,
            .has_error = false,
        };
    }

    fn is_at_end(self: *Self) bool {
        return self.current >= self.src.len;
    }

    fn advance(self: *Self) ?u8 {
        if (self.is_at_end()) return null;
        self.current += 1;
        return self.src[self.current - 1];
    }

    fn peek(self: *Self) ?u8 {
        if (self.is_at_end()) return null;
        return self.src[self.current];
    }

    fn skip_whitespace(self: *Self) void {
        while (!self.is_at_end() and std.ascii.isWhitespace(self.peek().?)) {
            if (self.advance()) |ch| {
                if (ch == '\n') {
                    self.line_number += 1;
                    self.line_start_offset = self.current;
                }
            }
        }
    }

    fn emit_token(self: *Self, token_type: TokenType) Token {
        return Token{
            .token_type = token_type,
            .line_number = self.line_number,
            .value = null,
            .line_start_offset = self.line_start_offset,
            .start = self.start,
            .end = self.current,
        };
    }

    fn report_error(self: *Self, ch: u8, err: LexerError) void {
        // we get the line where the offending character
        const line = self.src[self.line_start_offset..self.current];
        std.debug.print("{any}: {c}\n", .{ err, ch });
        std.debug.print("Line: {} Column: {}\n", .{ self.line_number, self.current - self.line_start_offset });
        std.debug.print("{s}\n", .{line});
        var i: usize = 0;
        while (i < line.len) : (i += 1) {
            if (i == line.len - 1) {
                std.debug.print("^\n", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
    }

    fn emit_tokens(self: *Self) !std.ArrayList(Token) {
        var token_list: std.ArrayList(Token) = .empty;
        while (!self.is_at_end()) {
            self.skip_whitespace();
            self.start = self.current;
            if (self.advance()) |ch| {
                switch (ch) {
                    '(' => try token_list.append(self.allocator, self.emit_token(.left_paran)),
                    ')' => try token_list.append(self.allocator, self.emit_token(.right_paran)),
                    '{' => try token_list.append(self.allocator, self.emit_token(.left_brace)),
                    '}' => try token_list.append(self.allocator, self.emit_token(.right_brace)),
                    ';' => try token_list.append(self.allocator, self.emit_token(.semi_colon)),
                    ',' => try token_list.append(self.allocator, self.emit_token(.comma)),
                    '=' => try token_list.append(self.allocator, self.emit_token(.equ)),
                    '+' => try token_list.append(self.allocator, self.emit_token(.plus)),
                    '*' => try token_list.append(self.allocator, self.emit_token(.star)),
                    else => {
                        if (std.ascii.isAlphabetic(ch) or ch == '_') {
                            while (!self.is_at_end() and (std.ascii.isAlphanumeric(self.peek().?) or self.peek().? == '_')) {
                                _ = self.advance();
                            }

                            // we have either a indentifier, keyword here
                            // check what we have
                            const lexeme = self.src[self.start..self.current];
                            if (self.keywords.get(lexeme)) |token_type| {
                                try token_list.append(self.allocator, Token{
                                    .token_type = token_type,
                                    .start = self.start,
                                    .end = self.current,
                                    .line_number = self.line_number,
                                    .line_start_offset = self.line_start_offset,
                                    .value = null,
                                });
                            } else {
                                try token_list.append(self.allocator, Token{
                                    .token_type = .identifier,
                                    .start = self.start,
                                    .end = self.current,
                                    .line_number = self.line_number,
                                    .line_start_offset = self.line_start_offset,
                                    .value = Value{ .identifier = lexeme },
                                });
                            }
                        } else if (std.ascii.isDigit(ch)) {
                            while (!self.is_at_end() and std.ascii.isDigit(self.peek().?)) {
                                _ = self.advance();
                            }

                            // we are going to try and convert the string to a f64
                            const result = try std.fmt.parseFloat(f64, self.src[self.start..self.current]);
                            try token_list.append(self.allocator, Token{
                                .token_type = .number,
                                .start = self.start,
                                .end = self.current,
                                .line_number = self.line_number,
                                .line_start_offset = self.line_start_offset,
                                .value = Value{ .num_val = result },
                            });
                        } else {
                            self.has_error = true;
                            self.report_error(ch, error.UnknownCharacter);
                        }
                    },
                }
            } else {
                return token_list;
            }
        }
        return token_list;
    }
};

// GRAMMAER:
//
//program:
//    statement*
//
//statement:
//    function_def
//    | let_statement
//    | expression ;
//
//function_def:
//    function <name> ( param_list ) { statement* }
//
//param_list:
//    empty
//    | <name> ( , <name> )*
//
//let_statement:
//    let <name> = expression ;
//
//expression:
//    term ( + term )*
//
//term:
//    primary ( * primary )*
//
//primary:
//    <number>
//    | <name>
//    | function_call
//    | ( expression )
//
//function_call:
//    <name> ( arg_list )
//
//arg_list:
//    empty
//    | expression ( , expression )*

const ParserError = error{
    ExpectedLeftParan,
    ExpectedRightParan,
    ExpectedLeftBrace,
    ExpectedRightBrace,
    ExpectedFunctionKeyword,
    ExpectedReturnKeyword,
    ReturnOnlyInsideFunction,
    ExpectedLet,
    ExpectedExpression,
    ExpectedIdentifier,
    ExpectedNumber,
    ExpectedEqu,
    ExpectedSemiColon,
    OutOfMemory,
};

const Identifier = struct {
    name: []const u8,
};

const Number = struct {
    num_val: f64,
};

const Primary = union(enum) {
    identifier: *Identifier,
    number: *Number,
    expr: *Expression,
    fn_call_expr: *FnCallExpression,
};

const Term = struct {
    first: *Primary,
    rest: std.ArrayList(*Primary),
};

const Expression = struct {
    first: *Term,
    rest: std.ArrayList(*Term),
};

const FnCallExpression = struct {
    name: *Identifier,
    args: std.ArrayList(*Expression),
};

const ReturnStatement = struct {
    return_expr: *Expression,
};

const FnDefStatement = struct {
    name: *Identifier,
    params: std.ArrayList(*Identifier),
    body: std.ArrayList(*Statement),
};

const LetStatement = struct {
    name: *Identifier,
    expr: *Expression,
};

const ExpressionStatement = struct {
    expr: *Expression,
};

const Statement = union(enum) {
    let_statement: *LetStatement,
    expr_statement: *ExpressionStatement,
    fn_def_statement: *FnDefStatement,
    return_statement: *ReturnStatement,
};

const Program = struct {
    statements: std.ArrayList(*Statement),
};

const Parser = struct {
    current: usize,
    token_list: std.ArrayList(Token),
    has_error: bool,
    allocator: std.mem.Allocator,
    is_fn_being_parsed: bool,
    const Self = @This();

    fn init(allocator: std.mem.Allocator, token_list: std.ArrayList(Token)) Parser {
        return Parser{
            .current = 0,
            .token_list = token_list,
            .allocator = allocator,
            .has_error = false,
            .is_fn_being_parsed = false,
        };
    }

    fn peek(self: *Self) Token {
        return self.token_list.items[self.current];
    }

    fn peek_next(self: *Self) ?Token {
        if (self.current >= self.token_list.items.len - 1) return null;
        return self.token_list.items[self.current + 1];
    }

    fn check_type(self: *Self, token_type: TokenType) bool {
        if (self.is_at_end()) return false;
        return self.peek().token_type == token_type;
    }

    fn advance(self: *Self) Token {
        const tkn = self.peek();
        self.current += 1;
        return tkn;
    }

    fn expect_type(self: *Self, token_type: TokenType) bool {
        if (self.is_at_end()) return false;
        const tkn = self.advance();
        return tkn.token_type == token_type;
    }

    fn is_at_end(self: *Self) bool {
        return self.current >= self.token_list.items.len;
    }

    fn parse_identifier(self: *Self) ParserError!*Identifier {
        if (self.is_at_end() or self.peek().token_type != .identifier) return error.ExpectedIdentifier;
        switch (self.peek().value.?) {
            .identifier => |value| {
                _ = self.advance();
                const identifier = try self.allocator.create(Identifier);
                identifier.* = Identifier{ .name = value };
                return identifier;
            },
            else => unreachable,
        }
    }

    fn parse_number(self: *Self) ParserError!*Number {
        if (self.is_at_end() or self.peek().token_type != .number) return error.ExpectedNumber;
        switch (self.peek().value.?) {
            .num_val => |value| {
                _ = self.advance();
                const number = try self.allocator.create(Number);
                number.* = Number{ .num_val = value };
                return number;
            },
            else => unreachable,
        }
    }

    fn parse_fn_call_expression(self: *Self) ParserError!*FnCallExpression {
        const name = try self.parse_identifier();
        if (!self.expect_type(.left_paran)) return error.ExpectedLeftParan;
        var args: std.ArrayList(*Expression) = .empty;
        //std.debug.print("{any}\n", .{self.peek()});
        while (!self.is_at_end() and !self.check_type(.right_paran)) {
            const expr = try self.parse_expression();
            try args.append(self.allocator, expr);
            if (!self.check_type(.comma)) break;
            _ = self.advance();
        }

        if (!self.expect_type(.right_paran)) return error.ExpectedRightParan;
        const fn_call_expr = try self.allocator.create(FnCallExpression);
        fn_call_expr.* = FnCallExpression{ .name = name, .args = args };
        return fn_call_expr;
    }

    fn parse_primary(self: *Self) ParserError!*Primary {
        if (self.is_at_end()) return error.ExpectedExpression;
        const primary = try self.allocator.create(Primary);
        switch_label: switch (self.peek().token_type) {
            .number => primary.* = Primary{ .number = try self.parse_number() },
            .identifier => {
                // we
                if (self.peek_next()) |tkn| {
                    if (tkn.token_type == .left_paran) {
                        primary.* = Primary{ .fn_call_expr = try self.parse_fn_call_expression() };
                        break :switch_label;
                    }
                }
                primary.* = Primary{ .identifier = try self.parse_identifier() };
            },
            .left_paran => {
                _ = self.advance();
                const expr = try self.parse_expression();
                if (!self.expect_type(.right_paran)) return error.ExpectedRightParan;
                primary.* = Primary{ .expr = expr };
            },
            else => unreachable,
        }

        return primary;
    }

    fn parse_term(self: *Self) ParserError!*Term {
        if (self.is_at_end()) return error.ExpectedExpression;
        const first = try self.parse_primary();
        var rest: std.ArrayList(*Primary) = .empty;
        while (self.check_type(.star)) {
            _ = self.advance();
            const primary = try self.parse_primary();
            try rest.append(self.allocator, primary);
        }
        const term = try self.allocator.create(Term);
        term.* = Term{ .first = first, .rest = rest };
        return term;
    }

    fn parse_expression(self: *Self) ParserError!*Expression {
        if (self.is_at_end()) return error.ExpectedExpression;
        const first = try self.parse_term();
        var rest: std.ArrayList(*Term) = .empty;
        while (self.check_type(.plus)) {
            _ = self.advance();
            const term = try self.parse_term();
            try rest.append(self.allocator, term);
        }
        const expression = try self.allocator.create(Expression);
        expression.* = Expression{ .first = first, .rest = rest };
        return expression;
    }

    //fn parse_fn_call_expression(self: *Self) ParserError!FnCallExpression {}

    fn parse_fn_def_statement(self: *Self) ParserError!*FnDefStatement {
        self.is_fn_being_parsed = true;
        if (!self.expect_type(.function)) return error.ExpectedFunctionKeyword;
        const function_name = try self.parse_identifier();
        if (!self.expect_type(.left_paran)) return error.ExpectedLeftParan;
        var params: std.ArrayList(*Identifier) = .empty;
        if (!self.check_type(.right_paran)) {
            while (self.check_type(.identifier)) {
                const identifier = try self.parse_identifier();
                try params.append(self.allocator, identifier);
                if (!self.check_type(.comma)) break;
                _ = self.advance();
            }
        }
        // now we have parsed the param names
        // we should assert that the token is clsosing paranthesis
        if (!self.expect_type(.right_paran)) return error.ExpectedRightParan;
        if (!self.expect_type(.left_brace)) return error.ExpectedLeftBrace;
        var statements: std.ArrayList(*Statement) = .empty;
        while (!self.is_at_end() and !self.check_type(.right_brace)) {
            const statement = try self.parse_statement();
            try statements.append(self.allocator, statement);
        }

        if (!self.expect_type(.right_brace)) return error.ExpectedRightBrace;
        const fn_def_statement = try self.allocator.create(FnDefStatement);
        fn_def_statement.* = FnDefStatement{ .name = function_name, .params = params, .body = statements };
        self.is_fn_being_parsed = false;
        return fn_def_statement;
    }

    fn parse_let_statement(self: *Self) ParserError!*LetStatement {
        if (!self.expect_type(.let)) return error.ExpectedLet;
        const variable_name = try self.parse_identifier();
        if (!self.expect_type(.equ)) return error.ExpectedEqu;
        const expression = try self.parse_expression();
        if (!self.expect_type(.semi_colon)) return error.ExpectedSemiColon;
        const let_statement = try self.allocator.create(LetStatement);
        let_statement.* = LetStatement{
            .name = variable_name,
            .expr = expression,
        };
        return let_statement;
    }

    fn parse_expression_statement(self: *Self) ParserError!*ExpressionStatement {
        const expr = try self.parse_expression();
        if (!self.expect_type(.semi_colon)) return error.ExpectedSemiColon;
        const statement = ExpressionStatement{ .expr = expr };
        const expr_statement = try self.allocator.create(ExpressionStatement);
        expr_statement.* = statement;
        return expr_statement;
    }

    fn parse_return_statement(self: *Self) ParserError!*ReturnStatement {
        if (!self.expect_type(.ret)) return error.ExpectedReturnKeyword;
        // check if we are inside a function or not
        // if not then we have to output the error
        if (!self.is_fn_being_parsed) return error.ReturnOnlyInsideFunction;
        const expr = try self.parse_expression();
        if (!self.expect_type(.semi_colon)) return error.ExpectedSemiColon;
        const stmt = try self.allocator.create(ReturnStatement);
        stmt.* = ReturnStatement{ .return_expr = expr };
        return stmt;
    }

    fn parse_statement(self: *Self) ParserError!*Statement {
        const statement = try self.allocator.create(Statement);
        switch (self.peek().token_type) {
            .let => statement.* = Statement{ .let_statement = try self.parse_let_statement() },
            .function => statement.* = Statement{ .fn_def_statement = try self.parse_fn_def_statement() },
            .ret => statement.* = Statement{ .return_statement = try self.parse_return_statement() },
            else => statement.* = Statement{ .expr_statement = try self.parse_expression_statement() },
        }
        return statement;
    }

    fn parse_program(self: *Self) ParserError!*Program {
        var statements: std.ArrayList(*Statement) = .empty;
        while (!self.is_at_end()) {
            const result = self.parse_statement();
            if (result) |statement| {
                try statements.append(self.allocator, statement);
            } else |err| {
                self.has_error = true;
                std.debug.print("{any}\n", .{err});
                std.debug.print("{any}\n", .{self.token_list.items[self.current]});
            }
        }
        const program = try self.allocator.create(Program);
        program.* = Program{ .statements = statements };
        return program;
    }
};

const ASTPrettyPrinter = struct {
    const Self = @This();

    fn print_indent(_: Self, level: usize) void {
        var indent_count = level * 4;
        while (indent_count > 0) : (indent_count -= 1) {
            std.debug.print(" ", .{});
        }
    }

    fn print_identifier(self: Self, identifier: *Identifier, level: usize) void {
        self.print_indent(level);
        std.debug.print("identifier: {s}\n", .{identifier.name});
    }

    fn print_let_statement(self: Self, statement: *LetStatement, level: usize) void {
        self.print_indent(level);
        std.debug.print("let statement\n", .{});
        self.print_identifier(statement.name, level + 1);
        self.print_expression(statement.expr, level + 1);
    }

    fn print_expr_statement(self: Self, statement: *ExpressionStatement, level: usize) void {
        self.print_indent(level);
        std.debug.print("expr statement\n", .{});
        self.print_expression(statement.expr, level + 1);
    }

    fn print_number(self: Self, number: *Number, level: usize) void {
        self.print_indent(level);
        std.debug.print("number: {}\n", .{number.num_val});
    }

    fn print_fn_call_expression(self: Self, fn_call_expr: *FnCallExpression, level: usize) void {
        self.print_indent(level);
        std.debug.print("function call: {s}\n", .{fn_call_expr.name.name});
        for (fn_call_expr.args.items) |expr| {
            self.print_expression(expr, level + 1);
        }
    }

    fn print_primary(self: Self, primary: *Primary, level: usize) void {
        switch (primary.*) {
            .identifier => |ident| self.print_identifier(ident, level),
            .number => |num| self.print_number(num, level),
            .fn_call_expr => |fn_call_expr| self.print_fn_call_expression(fn_call_expr, level),
            .expr => |expression| self.print_expression(expression, level),
        }
    }

    fn print_term(self: Self, term: *Term, level: usize) void {
        self.print_indent(level);
        std.debug.print("term\n", .{});
        // print the first
        self.print_primary(term.first, level + 1);
        for (term.rest.items) |item| {
            self.print_indent(level + 1);
            std.debug.print("operator: [*]\n", .{});
            self.print_primary(item, level + 1);
        }
    }

    fn print_expression(self: Self, expression: *Expression, level: usize) void {
        self.print_indent(level);
        std.debug.print("expression\n", .{});
        // print the first
        self.print_term(expression.first, level + 2);
        for (expression.rest.items) |item| {
            self.print_indent(level + 1);
            std.debug.print("operator: [+]\n", .{});
            self.print_term(item, level + 1);
        }
    }

    fn print_fn_def_statement(self: Self, statement: *FnDefStatement, level: usize) void {
        self.print_indent(level);
        std.debug.print("function: \n", .{});
        self.print_indent(level + 1);
        std.debug.print("params:\n", .{});
        for (statement.params.items) |param| {
            self.print_identifier(param, level + 2);
        }
        self.print_indent(level + 1);
        std.debug.print("body:\n", .{});
        for (statement.body.items) |stmt| {
            self.print_statement(stmt, level + 1);
        }
    }

    fn print_ret_statement(self: Self, statement: *ReturnStatement, level: usize) void {
        self.print_indent(level);
        std.debug.print("return:\n", .{});
        self.print_expression(statement.return_expr, level + 1);
    }

    fn print_statement(self: Self, statement: *Statement, level: usize) void {
        switch (statement.*) {
            .let_statement => |stmt| self.print_let_statement(stmt, level + 1),
            .fn_def_statement => |stmt| self.print_fn_def_statement(stmt, level + 1),
            .return_statement => |stmt| self.print_ret_statement(stmt, level + 1),
            .expr_statement => |stmt| self.print_expr_statement(stmt, level + 1),
        }
    }

    fn print_ast(self: Self, program: *Program, level: usize) void {
        for (program.statements.items) |statement| {
            self.print_statement(statement, level);
        }
    }
};

// This struct generates code for MASM assembler
// TODO(Aniket): Add support for multiple backends
const CodeGenerator = struct {};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const content = try std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        io,
        "test.cy",
        init.arena.allocator(),
        .unlimited,
    );
    const allocator = init.arena.allocator();
    var lexer = try Lexer.init(content, allocator);
    const tokens = try lexer.emit_tokens();
    var parser = Parser.init(allocator, tokens);
    const ast = try parser.parse_program();
    const printer = ASTPrettyPrinter{};
    if (!parser.has_error) {
        printer.print_ast(ast, 0);
    }
}

test "single character token" {
    const source = "(){}*+;=,";
    var lexer = try Lexer.init(source, std.testing.allocator);
    const tokens = try lexer.emit_tokens();
    const expected_tokens: [9]TokenType = .{
        .left_paran,
        .right_paran,
        .left_brace,
        .right_brace,
        .star,
        .plus,
        .semi_colon,
        .equ,
        .comma,
    };
    for (tokens.items, 0..) |token, idx| {
        std.debug.assert(token.token_type == expected_tokens[idx]);
    }
}
