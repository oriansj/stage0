/* Copyright (C) 2016 Jeremiah Orians
 * Copyright (C) 2018 Jan (janneke) Nieuwenhuizen <janneke@gnu.org>
 * This file is part of stage0.
 *
 * stage0 is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * stage0 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with stage0.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "cc.h"
#include "gcc_req.h"
#include <stdint.h>

/* Global lists */
struct token_list* global_symbol_list;
struct token_list* global_function_list;
struct token_list* global_constant_list;

/* Core lists for this file */
struct token_list* function;
struct token_list* out;

/* What we are currently working on */
struct type* current_target;
char* break_target_head;
char* break_target_func;
char* break_target_num;
struct token_list* break_frame;
int current_count;
struct type* last_type;
int Address_of;

/* Imported functions */
char* parse_string(char* string);
int escape_lookup(char* c);
char* numerate_number(int a);


struct token_list* emit(char *s, struct token_list* head)
{
	struct token_list* t = calloc(1, sizeof(struct token_list));
	t->next = head;
	t->s = s;
	return t;
}

void emit_out(char* s)
{
	out = emit(s, out);
}

struct token_list* uniqueID(char* s, struct token_list* l, char* num)
{
	l = emit(s, l);
	l = emit("_", l);
	l = emit(num, l);
	l = emit("\n", l);
	return l;
}

void uniqueID_out(char* s, char* num)
{
	out = uniqueID(s, out, num);
}

struct token_list* sym_declare(char *s, struct type* t, struct token_list* list)
{
	struct token_list* a = calloc(1, sizeof(struct token_list));
	a->next = list;
	a->s = s;
	a->type = t;
	return a;
}

struct token_list* sym_lookup(char *s, struct token_list* symbol_list)
{
	struct token_list* i;
	for(i = symbol_list; NULL != i; i = i->next)
	{
		if(match(i->s, s)) return i;
	}
	return NULL;
}

void line_error()
{
	file_print(global_token->filename, stderr);
	file_print(":", stderr);
	file_print(numerate_number(global_token->linenumber), stderr);
	file_print(":", stderr);
}

void require_match(char* message, char* required)
{
	if(!match(global_token->s, required))
	{
		line_error();
		file_print(message, stderr);
		exit(EXIT_FAILURE);
	}
	global_token = global_token->next;
}

void expression();
void function_call(char* s, int bool)
{
	require_match("ERROR in process_expression_list\nNo ( was found\n", "(");
	int passed = 0;
	emit_out("{R11} PUSH_ALWAYS\t# Prevent overwriting in recursion\n");
	emit_out("{BP} PUSH_ALWAYS\t# Protect the old base pointer\n");
	emit_out("'0' SP R11 NO_SHIFT MOVE_ALWAYS\t# Copy new base pointer\n");

	if(global_token->s[0] != ')')
	{
		expression();
		emit_out("{R0} PUSH_ALWAYS\t#_process_expression1\n");
		passed = 1;

		while(global_token->s[0] == ',')
		{
			global_token = global_token->next;
			expression();
			emit_out("{R0} PUSH_ALWAYS\t#_process_expression2\n");
			passed = passed + 1;
		}
	}

	require_match("ERROR in process_expression_list\nNo ) was found\n", ")");

	if(TRUE == bool)
	{
		emit_out("!");
		emit_out(s);
		emit_out(" R0 SUB BP ARITH_ALWAYS\n");
		emit_out("!0 R0 LOAD32 R0 MEMORY\n");
		emit_out("{LR} PUSH_ALWAYS\t# Protect the old link register\n");
		emit_out("'0' R11 BP NO_SHIFT MOVE_ALWAYS\n");
		emit_out("'3' R0 CALL_REG_ALWAYS\n");
		emit_out("{LR} POP_ALWAYS\t# Prevent overwrite\n");
	}
	else
	{
		emit_out("{LR} PUSH_ALWAYS\t# Protect the old link register\n");
		emit_out("'0' R11 BP NO_SHIFT MOVE_ALWAYS\n");
		emit_out("^~FUNCTION_");
		emit_out(s);
		emit_out(" CALL_ALWAYS\n");
		emit_out("{LR} POP_ALWAYS\t# Restore the old link register\n");
	}

	for(; passed > 0; passed = passed - 1)
	{
		emit_out("{R1} POP_ALWAYS\t# _process_expression_locals\n");
	}
	emit_out("{BP} POP_ALWAYS\t# Restore old base pointer\n");
	emit_out("{R11} POP_ALWAYS\t# Prevent overwrite\n");
}

void constant_load(struct token_list* a)
{
	emit_out("!0 R0 LOAD32 R15 MEMORY\n~0 JUMP_ALWAYS\n%");
	emit_out(a->arguments->s);
	emit_out("\n");
}

void variable_load(struct token_list* a)
{
	if(match("FUNCTION", a->type->name) && match("(", global_token->s))
	{
		function_call(numerate_number(a->depth), TRUE);
		return;
	}
	current_target = a->type;
	emit_out("!");
	emit_out(numerate_number(a->depth));
	emit_out(" R0 SUB BP ARITH_ALWAYS\n");

	if(TRUE == Address_of) return;
	if(match("=", global_token->s)) return;

	emit_out("!0 R0 LOAD32 R0 MEMORY\n");
}

void function_load(struct token_list* a)
{
	if(match("(", global_token->s))
	{
		function_call(a->s, FALSE);
		return;
	}

	emit_out("!0 R0 LOAD32 R15 MEMORY\n~0 JUMP_ALWAYS\n&FUNCTION_");
	emit_out(a->s);
	emit_out("\n");
}

void global_load(struct token_list* a)
{
	current_target = a->type;
	emit_out("!0 R0 LOAD32 R15 MEMORY\n~0 JUMP_ALWAYS\n&GLOBAL_");
	emit_out(a->s);
	emit_out("\n");
	if(!match("=", global_token->s)) emit_out("!0 R0 LOAD32 R0 MEMORY\n");
}

/*
 * primary-expr:
 * FAILURE
 * "String"
 * 'Char'
 * [0-9]*
 * [a-z,A-Z]*
 * ( expression )
 */

void primary_expr_failure()
{
	line_error();
	file_print("Recieved ", stderr);
	file_print(global_token->s, stderr);
	file_print(" in primary_expr\n", stderr);
	exit(EXIT_FAILURE);
}

void primary_expr_string()
{
	char* number_string = numerate_number(current_count);
	current_count = current_count + 1;
	emit_out("!0 R0 LOAD32 R15 MEMORY\n~0 JUMP_ALWAYS\n&STRING_");
	uniqueID_out(function->s, number_string);

	/* The target */
	strings_list = emit(":STRING_", strings_list);
	strings_list = uniqueID(function->s, strings_list, number_string);

	/* Parse the string */
	strings_list = emit(parse_string(global_token->s), strings_list);
	global_token = global_token->next;
}

void primary_expr_char()
{
	emit_out("!");
	emit_out(numerate_number(escape_lookup(global_token->s + 1)));
	emit_out(" R0 LOADI8_ALWAYS\n");
	global_token = global_token->next;
}

void primary_expr_number()
{
	emit_out("!0 R0 LOAD32 R15 MEMORY\n~0 JUMP_ALWAYS\n%");
	emit_out(global_token->s);
	emit_out("\n");
	global_token = global_token->next;
}

void primary_expr_variable()
{
	char* s = global_token->s;
	global_token = global_token->next;
	struct token_list* a = sym_lookup(s, global_constant_list);
	if(NULL != a)
	{
		constant_load(a);
		return;
	}

	a= sym_lookup(s, function->locals);
	if(NULL != a)
	{
		variable_load(a);
		return;
	}

	a = sym_lookup(s, function->arguments);
	if(NULL != a)
	{
		variable_load(a);
		return;
	}

	a= sym_lookup(s, global_function_list);
	if(NULL != a)
	{
		function_load(a);
		return;
	}

	a = sym_lookup(s, global_symbol_list);
	if(NULL != a)
	{
		global_load(a);
		return;
	}

	line_error();
	file_print(s ,stderr);
	file_print(" is not a defined symbol\n", stderr);
	exit(EXIT_FAILURE);
}

void primary_expr();
struct type* promote_type(struct type* a, struct type* b)
{
	if(NULL == b)
	{
		return a;
	}
	if(NULL == a)
	{
		return b;
	}

	struct type* i;
	for(i = global_types; NULL != i; i = i->next)
	{
		if(a->name == i->name) break;
		if(b->name == i->name) break;
		if(a->name == i->indirect->name) break;
		if(b->name == i->indirect->name) break;
	}
	return i;
}

void common_recursion(FUNCTION f)
{
	last_type = current_target;
	global_token = global_token->next;
	emit_out("{R0} PUSH_ALWAYS\t#_common_recursion\n");
	f();
	current_target = promote_type(current_target, last_type);
	emit_out("{R1} POP_ALWAYS\t# _common_recursion\n");
}

void general_recursion( FUNCTION f, char* s, char* name, FUNCTION iterate)
{
	if(match(name, global_token->s))
	{
		common_recursion(f);
		emit_out(s);
		iterate();
	}
}

int ceil_log2(int a)
{
	int result = 0;
	if((a & (a - 1)) == 0)
	{
		result = -1;
	}

	while(a > 0)
	{
		result = result + 1;
		a = a >> 1;
	}

	return (result >> 1);
}

/*
 * postfix-expr:
 *         primary-expr
 *         postfix-expr [ expression ]
 *         postfix-expr ( expression-list-opt )
 *         postfix-expr -> member
 */
struct type* lookup_member(struct type* parent, char* name);
void postfix_expr_arrow()
{
	emit_out("# looking up offset\n");
	global_token = global_token->next;

	struct type* i = lookup_member(current_target, global_token->s);
	current_target = i->type;
	global_token = global_token->next;

	if(0 != i->offset)
	{
		emit_out("# -> offset calculation\n");
		emit_out("!0 R1 LOAD32 R15 MEMORY\n~0 JUMP_ALWAYS\n%");
		emit_out(numerate_number(i->offset));
		emit_out("\n'0' R0 R0 ADD R1 ARITH2_ALWAYS\n");
	}

	if(!match("=", global_token->s) && (4 == i->size))
	{
		emit_out("!0 R0 LOAD32 R0 MEMORY\n");
	}
}

void postfix_expr_array()
{
	struct type* array = current_target;
	common_recursion(expression);
	current_target = array;
	char* assign = "!0 R0 LOAD32 R0 MEMORY\n";

	/* Add support for Ints */
	if(match("char*",  current_target->name))
	{
		assign = "!0 R0 LOAD8 R0 MEMORY\n";
	}
	else
	{
		emit_out("'0' R0 R0 '");
		emit_out(numerate_number(ceil_log2(current_target->indirect->size)));
		emit_out("' MOVE_ALWAYS\n");
	}

	emit_out("'0' R0 R0 ADD R1 ARITH2_ALWAYS\n");
	require_match("ERROR in postfix_expr\nMissing ]\n", "]");

	if(match("=", global_token->s))
	{
		assign = "";
	}

	emit_out(assign);
}

/*
 * unary-expr:
 *         postfix-expr
 *         - postfix-expr
 *         !postfix-expr
 *         sizeof ( type )
 */
struct type* type_name();
void unary_expr_sizeof()
{
	global_token = global_token->next;
	require_match("ERROR in unary_expr\nMissing (\n", "(");
	struct type* a = type_name();
	require_match("ERROR in unary_expr\nMissing )\n", ")");

	emit_out("!");
	emit_out(numerate_number(a->size));
	emit_out(" R0 LOADI8_ALWAYS\n");
}

void postfix_expr_stub()
{
	if(match("[", global_token->s))
	{
		postfix_expr_array();
		postfix_expr_stub();
	}

	if(match("->", global_token->s))
	{
		postfix_expr_arrow();
		postfix_expr_stub();
	}
}

void postfix_expr()
{
	primary_expr();
	postfix_expr_stub();
}

/*
 * additive-expr:
 *         postfix-expr
 *         additive-expr * postfix-expr
 *         additive-expr / postfix-expr
 *         additive-expr % postfix-expr
 *         additive-expr + postfix-expr
 *         additive-expr - postfix-expr
 *         additive-expr << postfix-expr
 *         additive-expr >> postfix-expr
 */
void additive_expr_stub()
{
	general_recursion(postfix_expr, "'0' R0 R0 ADD R1 ARITH2_ALWAYS\n", "+", additive_expr_stub);
	general_recursion(postfix_expr, "'0' R0 R0 SUB R1 ARITH2_ALWAYS\n", "-", additive_expr_stub);
	general_recursion(postfix_expr, "'9' R0 '0' R1 MULS R0 ARITH2_ALWAYS\n", "*", additive_expr_stub);
	general_recursion(postfix_expr, "{LR} PUSH_ALWAYS\n^~divide CALL_ALWAYS\n{LR} POP_ALWAYS\n", "/", additive_expr_stub);
	general_recursion(postfix_expr, "{LR} PUSH_ALWAYS\n^~modulus CALL_ALWAYS\n{LR} POP_ALWAYS\n", "%", additive_expr_stub);
	general_recursion(postfix_expr, "LEFT R1 R0 R0 SHIFT AUX_ALWAYS\n", "<<", additive_expr_stub);
	general_recursion(postfix_expr, "RIGHT R1 R0 R0 SHIFT AUX_ALWAYS\n", ">>", additive_expr_stub);
}


void additive_expr()
{
	postfix_expr();
	additive_expr_stub();
}


/*
 * relational-expr:
 *         additive_expr
 *         relational-expr < additive_expr
 *         relational-expr <= additive_expr
 *         relational-expr >= additive_expr
 *         relational-expr > additive_expr
 */

void relational_expr_stub()
{
	general_recursion(additive_expr, "'0' R0 CMP R1 AUX_ALWAYS\n!0 R0 LOADI8_ALWAYS\n!1 R0 LOADI8_L\n", "<", relational_expr_stub);
	general_recursion(additive_expr, "'0' R0 CMP R1 AUX_ALWAYS\n!0 R0 LOADI8_ALWAYS\n!1 R0 LOADI8_LE\n", "<=", relational_expr_stub);
	general_recursion(additive_expr, "'0' R0 CMP R1 AUX_ALWAYS\n!0 R0 LOADI8_ALWAYS\n!1 R0 LOADI8_GE\n", ">=", relational_expr_stub);
	general_recursion(additive_expr, "'0' R0 CMP R1 AUX_ALWAYS\n!0 R0 LOADI8_ALWAYS\n!1 R0 LOADI8_G\n", ">", relational_expr_stub);
	general_recursion(additive_expr, "'0' R0 CMP R1 AUX_ALWAYS\n!0 R0 LOADI8_ALWAYS\n!1 R0 LOADI8_EQUAL\n", "==", relational_expr_stub);
	general_recursion(additive_expr, "'0' R0 CMP R1 AUX_ALWAYS\n!0 R0 LOADI8_ALWAYS\n!1 R0 LOADI8_NE\n", "!=", relational_expr_stub);
}

void relational_expr()
{
	additive_expr();
	relational_expr_stub();
}

/*
 * bitwise-expr:
 *         relational-expr
 *         bitwise-expr & bitwise-expr
 *         bitwise-expr && bitwise-expr
 *         bitwise-expr | bitwise-expr
 *         bitwise-expr || bitwise-expr
 *         bitwise-expr ^ bitwise-expr
 */
void bitwise_expr_stub()
{
	general_recursion(relational_expr, "NO_SHIFT R0 R0 AND R1 ARITH2_ALWAYS\n", "&", bitwise_expr_stub);
	general_recursion(relational_expr, "NO_SHIFT R0 R0 AND R1 ARITH2_ALWAYS\n", "&&", bitwise_expr_stub);
	general_recursion(relational_expr, "NO_SHIFT R0 R0 OR R1 AUX_ALWAYS\n", "|", bitwise_expr_stub);
	general_recursion(relational_expr, "NO_SHIFT R0 R0 OR R1 AUX_ALWAYS\n", "||", bitwise_expr_stub);
	general_recursion(relational_expr, "'0' R0 R0 XOR R1 ARITH2_ALWAYS\n", "^", bitwise_expr_stub);
}


void bitwise_expr()
{
	relational_expr();
	bitwise_expr_stub();
}

/*
 * expression:
 *         bitwise-or-expr
 *         bitwise-or-expr = expression
 */

void primary_expr()
{
	if(match("&", global_token->s))
	{
		Address_of = TRUE;
		global_token = global_token->next;
	}
	else
	{
		Address_of = FALSE;
	}

	if(match("sizeof", global_token->s)) unary_expr_sizeof();
	else if('-' == global_token->s[0])
	{
		emit_out("!0 R0 LOADI8_ALWAYS\n");
		common_recursion(primary_expr);
		emit_out("'0' R0 R0 SUB R1 ARITH2_ALWAYS\n");
	}
	else if('!' == global_token->s[0])
	{
		emit_out("!1 R0 LOADI8_ALWAYS\n");
		common_recursion(postfix_expr);
		emit_out("'0' R0 R0 XOR R1 ARITH2_ALWAYS\n");
	}
	else if(global_token->s[0] == '(')
	{
		global_token = global_token->next;
		expression();
		require_match("Error in Primary expression\nDidn't get )\n", ")");
	}
	else if(global_token->s[0] == '\'') primary_expr_char();
	else if(global_token->s[0] == '"') primary_expr_string();
	else if(in_set(global_token->s[0], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")) primary_expr_variable();
	else if(in_set(global_token->s[0], "0123456789")) primary_expr_number();
	else primary_expr_failure();
}

void expression()
{
	bitwise_expr();
	if(match("=", global_token->s))
	{
		char* store;
		if(!match("]", global_token->prev->s) || !match("char*", current_target->name))
		{
			store = "!0 R0 STORE32 R1 MEMORY\n";
		}
		else
		{
			store = "!0 R0 STORE8 R1 MEMORY\n";
		}

		common_recursion(expression);
		emit_out(store);
		current_target = NULL;
	}
}


/* Process local variable */
void collect_local()
{
	struct type* type_size = type_name();
	struct token_list* a = sym_declare(global_token->s, type_size, function->locals);
	if(match("main", function->s) && (NULL == function->locals))
	{
		a->depth = 16;
	}
	else if((NULL == function->arguments) && (NULL == function->locals))
	{
		a->depth = 8;
	}
	else if(NULL == function->locals)
	{
		a->depth = function->arguments->depth + 8;
	}
	else
	{
		a->depth = function->locals->depth + 4;
	}

	function->locals = a;

	emit_out("# Defining local ");
	emit_out(global_token->s);
	emit_out("\n");

	global_token = global_token->next;

	if(match("=", global_token->s))
	{
		global_token = global_token->next;
		expression();
	}

	require_match("ERROR in collect_local\nMissing ;\n", ";");

	emit_out("{R0} PUSH_ALWAYS\t#");
	emit_out(a->s);
	emit_out("\n");
}

void statement();

/* Evaluate if statements */
void process_if()
{
	char* number_string = numerate_number(current_count);
	current_count = current_count + 1;

	emit_out("# IF_");
	uniqueID_out(function->s, number_string);

	global_token = global_token->next;
	require_match("ERROR in process_if\nMISSING (\n", "(");
	expression();

	emit_out("!0 CMPI8 R0 IMM_ALWAYS\n^~ELSE_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_EQUAL\n");

	require_match("ERROR in process_if\nMISSING )\n", ")");
	statement();

	emit_out("^~_END_IF_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_ALWAYS\n:ELSE_");
	uniqueID_out(function->s, number_string);

	if(match("else", global_token->s))
	{
		global_token = global_token->next;
		statement();
	}
	emit_out(":_END_IF_");
	uniqueID_out(function->s, number_string);
}

void process_for()
{
	struct token_list* nested_locals = break_frame;
	char* nested_break_head = break_target_head;
	char* nested_break_func = break_target_func;
	char* nested_break_num = break_target_num;

	char* number_string = numerate_number(current_count);
	current_count = current_count + 1;

	break_target_head = "FOR_END_";
	break_target_num = number_string;
	break_frame = function->locals;
	break_target_func = function->s;

	emit_out("# FOR_initialization_");
	uniqueID_out(function->s, number_string);

	global_token = global_token->next;

	require_match("ERROR in process_for\nMISSING (\n", "(");
	if(!match(";",global_token->s))
	{
		expression();
	}

	emit_out(":FOR_");
	uniqueID_out(function->s, number_string);

	require_match("ERROR in process_for\nMISSING ;1\n", ";");
	expression();

	emit_out("!0 CMPI8 R0 IMM_ALWAYS\n^~FOR_END_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_EQUAL\n^~FOR_THEN_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_ALWAYS\n:FOR_ITER_");
	uniqueID_out(function->s, number_string);

	require_match("ERROR in process_for\nMISSING ;2\n", ";");
	expression();

	emit_out("^~FOR_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_ALWAYS\n:FOR_THEN_");
	uniqueID_out(function->s, number_string);

	require_match("ERROR in process_for\nMISSING )\n", ")");
	statement();

	emit_out("^~FOR_ITER_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_ALWAYS\n:FOR_END_");
	uniqueID_out(function->s, number_string);

	break_target_head = nested_break_head;
	break_target_func = nested_break_func;
	break_target_num = nested_break_num;
	break_frame = nested_locals;
}

/* Process Assembly statements */
void process_asm()
{
	global_token = global_token->next;
	require_match("ERROR in process_asm\nMISSING (\n", "(");
	while(34 == global_token->s[0])
	{/* 34 == " */
		emit_out((global_token->s + 1));
		emit_out("\n");
		global_token = global_token->next;
	}
	require_match("ERROR in process_asm\nMISSING )\n", ")");
	require_match("ERROR in process_asm\nMISSING ;\n", ";");
}

/* Process do while loops */
void process_do()
{
	struct token_list* nested_locals = break_frame;
	char* nested_break_head = break_target_head;
	char* nested_break_func = break_target_func;
	char* nested_break_num = break_target_num;

	char* number_string = numerate_number(current_count);
	current_count = current_count + 1;

	break_target_head = "DO_END_";
	break_target_num = number_string;
	break_frame = function->locals;
	break_target_func = function->s;

	emit_out(":DO_");
	uniqueID_out(function->s, number_string);

	global_token = global_token->next;
	statement();

	require_match("ERROR in process_do\nMISSING while\n", "while");
	require_match("ERROR in process_do\nMISSING (\n", "(");
	expression();
	require_match("ERROR in process_do\nMISSING )\n", ")");
	require_match("ERROR in process_do\nMISSING ;\n", ";");

	emit_out("!0 CMPI8 R0 IMM_ALWAYS\n^~DO_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_NE\n:DO_END_");
	uniqueID_out(function->s, number_string);

	break_frame = nested_locals;
	break_target_head = nested_break_head;
	break_target_func = nested_break_func;
	break_target_num = nested_break_num;
}


/* Process while loops */
void process_while()
{
	struct token_list* nested_locals = break_frame;
	char* nested_break_head = break_target_head;
	char* nested_break_func = break_target_func;
	char* nested_break_num = break_target_num;

	char* number_string = numerate_number(current_count);
	current_count = current_count + 1;

	break_target_head = "END_WHILE_";
	break_target_num = number_string;
	break_frame = function->locals;
	break_target_func = function->s;

	emit_out(":WHILE_");
	uniqueID_out(function->s, number_string);

	global_token = global_token->next;
	require_match("ERROR in process_while\nMISSING (\n", "(");
	expression();

	emit_out("!0 CMPI8 R0 IMM_ALWAYS\n^~END_WHILE_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_EQUAL\t# THEN_while_");
	uniqueID_out(function->s, number_string);

	require_match("ERROR in process_while\nMISSING )\n", ")");
	statement();

	emit_out("^~WHILE_");
	uniqueID_out(function->s, number_string);
	emit_out(" JUMP_ALWAYS\n:END_WHILE_");
	uniqueID_out(function->s, number_string);

	break_target_head = nested_break_head;
	break_target_func = nested_break_func;
	break_target_num = nested_break_num;
	break_frame = nested_locals;
}

/* Ensure that functions return */
void return_result()
{
	global_token = global_token->next;
	if(global_token->s[0] != ';') expression();

	require_match("ERROR in return_result\nMISSING ;\n", ";");

	struct token_list* i;
	for(i = function->locals; NULL != i; i = i->next)
	{
		emit_out("{R1} POP_ALWAYS\t# _return_result_locals\n");
	}
	emit_out("'1' LR RETURN\n");
}

void process_break()
{
	if(NULL == break_target_head)
	{
		line_error();
		file_print("Not inside of a loop or case statement", stderr);
		exit(EXIT_FAILURE);
	}
	struct token_list* i = function->locals;
	while(i != break_frame)
	{
		if(NULL == i) break;
		emit_out("{R1} POP_ALWAYS\t# break_cleanup_locals\n");
		i = i->next;
	}
	global_token = global_token->next;
	emit_out("^~");
	emit_out(break_target_head);
	emit_out(break_target_func);
	emit_out("_");
	emit_out(break_target_num);
	emit_out(" JUMP_ALWAYS\n");
	require_match("ERROR in break statement\nMissing ;\n", ";");
}

void recursive_statement()
{
	global_token = global_token->next;
	struct token_list* frame = function->locals;

	while(!match("}", global_token->s))
	{
		statement();
	}
	global_token = global_token->next;

	/* Clean up any locals added */
	if(!match("'1' LR RETURN\n", out->s))
	{
		struct token_list* i;
		for(i = function->locals; frame != i; i = i->next)
		{
			emit_out( "{R1} POP_ALWAYS\t# _recursive_statement_locals\n");
		}
	}
	function->locals = frame;
}

/*
 * statement:
 *     { statement-list-opt }
 *     type-name identifier ;
 *     type-name identifier = expression;
 *     if ( expression ) statement
 *     if ( expression ) statement else statement
 *     do statement while ( expression ) ;
 *     while ( expression ) statement
 *     for ( expression ; expression ; expression ) statement
 *     asm ( "assembly" ... "assembly" ) ;
 *     goto label ;
 *     label:
 *     return ;
 *     break ;
 *     expr ;
 */

struct type* lookup_type(char* s, struct type* start);
void statement()
{
	if(global_token->s[0] == '{')
	{
		recursive_statement();
	}
	else if(':' == global_token->s[0])
	{
		emit_out(global_token->s);
		emit_out("\t#C goto label\n");
		global_token = global_token->next;
	}
	else if((NULL != lookup_type(global_token->s, prim_types)) ||
	          match("struct", global_token->s))
	{
		collect_local();
	}
	else if(match("if", global_token->s))
	{
		process_if();
	}
	else if(match("do", global_token->s))
	{
		process_do();
	}
	else if(match("while", global_token->s))
	{
		process_while();
	}
	else if(match("for", global_token->s))
	{
		process_for();
	}
	else if(match("asm", global_token->s))
	{
		process_asm();
	}
	else if(match("goto", global_token->s))
	{
		global_token = global_token->next;
		emit_out("^~");
		emit_out(global_token->s);
		emit_out(" JUMP_ALWAYS\n");
		global_token = global_token->next;
		require_match("ERROR in statement\nMissing ;\n", ";");
	}
	else if(match("return", global_token->s))
	{
		return_result();
	}
	else if(match("break", global_token->s))
	{
		process_break();
	}
	else if(match("continue", global_token->s))
	{
		global_token = global_token->next;
		emit_out("\n#continue statement\n");
		require_match("ERROR in statement\nMissing ;\n", ";");
	}
	else
	{
		expression();
		require_match("ERROR in statement\nMISSING ;\n", ";");
	}
}

/* Collect function arguments */
void collect_arguments()
{
	global_token = global_token->next;

	while(!match(")", global_token->s))
	{
		struct type* type_size = type_name();
		if(global_token->s[0] == ')')
		{
			/* foo(int,char,void) doesn't need anything done */
			continue;
		}
		else if(global_token->s[0] != ',')
		{
			/* deal with foo(int a, char b) */
			struct token_list* a = sym_declare(global_token->s, type_size, function->arguments);
			if(NULL == function->arguments)
			{
				a->depth = 4;
			}
			else
			{
				a->depth = function->arguments->depth + 4;
			}

			global_token = global_token->next;
			function->arguments = a;
		}

		/* ignore trailing comma (needed for foo(bar(), 1); expressions*/
		if(global_token->s[0] == ',') global_token = global_token->next;
	}
	global_token = global_token->next;
}

void declare_function()
{
	current_count = 0;
	function = sym_declare(global_token->prev->s, NULL, global_function_list);

	/* allow previously defined functions to be looked up */
	global_function_list = function;
	collect_arguments();

	/* If just a prototype don't waste time */
	if(global_token->s[0] == ';') global_token = global_token->next;
	else
	{
		emit_out("# Defining function ");
		emit_out(function->s);
		emit_out("\n");
		emit_out(":FUNCTION_");
		emit_out(function->s);
		emit_out("\n");
		statement();

		/* Prevent duplicate RETURNS */
		if(!match("'1' LR RETURN\n", out->s))
		{
			emit_out("'1' LR RETURN\n");
		}
	}
}

/*
 * program:
 *     declaration
 *     declaration program
 *
 * declaration:
 *     CONSTANT identifer value
 *     type-name identifier ;
 *     type-name identifier ( parameter-list ) ;
 *     type-name identifier ( parameter-list ) statement
 *
 * parameter-list:
 *     parameter-declaration
 *     parameter-list, parameter-declaration
 *
 * parameter-declaration:
 *     type-name identifier-opt
 */
struct token_list* program()
{
	Address_of = FALSE;
	out = NULL;
	function = NULL;
	struct type* type_size;

new_type:
	if (NULL == global_token) return out;
	if(match("enum", global_token->s))
	{
		global_token = global_token->next;
		require_match("ERROR in enum\nExpected {\n", "{");

		do
		{
			global_constant_list = sym_declare(global_token->s, NULL, global_constant_list);
			global_token = global_token->next;

			require_match("ERROR in enum\nExpected =\n", "=");

			global_constant_list->arguments = global_token;
			global_token = global_token->next;

			if(match(global_token->s, ","))
			{
				global_token = global_token->next;
			}
		}
		while(!match(global_token->s, "}"));

		require_match("ERROR in enum\nExpected }\n", "}");
		require_match("ERROR in enum\nExpected ;\n", ";");
	}
	else if(match("CONSTANT", global_token->s))
	{
		global_token = global_token->next;
		global_constant_list = sym_declare(global_token->s, NULL, global_constant_list);
		global_constant_list->arguments = global_token->next;
		global_token = global_token->next->next;
	}
	else
	{
		type_size = type_name();
		if(NULL == type_size)
		{
			goto new_type;
		}
		/* Add to global symbol table */
		global_symbol_list = sym_declare(global_token->s, type_size, global_symbol_list);
		global_token = global_token->next;
		if(match(";", global_token->s))
		{
			/* Ensure 4 bytes are allocated for the global */
			globals_list = emit(":GLOBAL_", globals_list);
			globals_list = emit(global_token->prev->s, globals_list);
			globals_list = emit("\nNULL\n", globals_list);

			global_token = global_token->next;
		}
		else if(match("(", global_token->s)) declare_function();
		else if(match("=",global_token->s))
		{
			/* Store the global's value*/
			globals_list = emit(":GLOBAL_", globals_list);
			globals_list = emit(global_token->prev->s, globals_list);
			globals_list = emit("\n", globals_list);
			global_token = global_token->next;
			if(in_set(global_token->s[0], "0123456789"))
			{ /* Assume Int */
				globals_list = emit("%", globals_list);
				globals_list = emit(global_token->s, globals_list);
				globals_list = emit("\n", globals_list);
			}
			else if(('"' == global_token->s[0]))
			{ /* Assume a string*/
				globals_list = emit(parse_string(global_token->s), globals_list);
			}
			else
			{
				line_error();
				file_print("Recieved ", stderr);
				file_print(global_token->s, stderr);
				file_print(" in program\n", stderr);
				exit(EXIT_FAILURE);
			}

			global_token = global_token->next;
			require_match("ERROR in Program\nMissing ;\n", ";");
		}
		else
		{
			line_error();
			file_print("Recieved ", stderr);
			file_print(global_token->s, stderr);
			file_print(" in program\n", stderr);
			exit(EXIT_FAILURE);
		}
	}
	goto new_type;
}

void recursive_output(struct token_list* i, FILE* out)
{
	if(NULL == i) return;
	recursive_output(i->next, out);
	file_print(i->s, out);
}
