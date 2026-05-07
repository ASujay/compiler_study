# GRAMMAER:
program:
    statement*
statement:
    function_def
    | let_statement
    | expression ;
function_def:
    function <name> ( param_list ) { statement* }
param_list:
    empty
    | <name> ( , <name> )*
let_statement:
    let <name> = expression ;
expression:
    term ( + term )*
term:
    primary ( * primary )*
primary:
    <number>
    | <name>
    | function_call
    | ( expression )
function_call:
    <name> ( arg_list )
arg_list:
    empty
    | expression ( , expression )*
