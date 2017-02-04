#include "lisp.h"

/* Support functions */
struct cell* findsym(char *name)
{
	struct cell* symlist;
	for(symlist = all_symbols; nil != symlist; symlist = symlist->cdr)
	{
		if(!strcmp(name, symlist->car->string))
		{
			return symlist;
		}
	}
	return nil;
}

struct cell* make_sym(char* name);

struct cell* intern(char *name)
{
	struct cell* op = findsym(name);
	if(nil != op) return op->car;
	op = make_sym(name);
	all_symbols = make_cons(op, all_symbols);
	return op;
}

/*** Environment ***/
struct cell* extend(struct cell* env, struct cell* symbol, struct cell* value)
{
	return make_cons(make_cons((symbol), (value)), (env));
}

struct cell* multiple_extend(struct cell* env, struct cell* syms, struct cell* vals)
{
	if(nil == syms)
	{
		return env;
	}
	return multiple_extend(extend(env, syms->car, vals->car), syms->cdr, vals->cdr);
}

struct cell* extend_top(struct cell* sym, struct cell* val)
{
	top_env->cdr = make_cons(make_cons(sym, val), top_env->cdr);
	return val;
}

struct cell* assoc(struct cell* key, struct cell* alist)
{
	if(nil == alist) return nil;
	for(; nil != alist; alist = alist->cdr)
	{
		if(alist->car->car == key) return alist->car;
	}
	return nil;
}

/*** Evaluator (Eval/Apply) ***/
struct cell* eval(struct cell* exp, struct cell* env);
struct cell* make_proc(struct cell* a, struct cell* b, struct cell* env);
struct cell* evlis(struct cell* exps, struct cell* env)
{
	if(exps == nil) return nil;
	return make_cons(eval(exps->car, env), evlis(exps->cdr, env));
}

struct cell* progn(struct cell* exps, struct cell* env)
{
	if(exps == nil) return nil;
	for(;;)
	{
		if(exps->cdr == nil) return eval(exps->car, env);
		eval(exps->car, env);
		exps = exps->cdr;
	}
}

struct cell* apply(struct cell* proc, struct cell* vals)
{
	struct cell* temp = nil;
	if(proc->type == PRIMOP)
	{
		temp = (*(proc->function))(vals);
	}
	else if(proc->type == PROC)
	{
		temp = progn(proc->cdr, multiple_extend(proc->env, proc->car, vals));
	}
	else
	{
		fprintf(stderr, "Bad argument to apply\n");
		exit(EXIT_FAILURE);
	}
	return temp;
}

struct cell* evcond(struct cell* exp, struct cell* env)
{
	if(tee == eval(exp->car->car, env))
	{
		return eval(exp->car->cdr->car, env);
	}

	return evcond(exp->cdr, env);
}

struct cell* prim_begin(struct cell* exp, struct cell* env)
{
	struct cell* ret;
	ret = eval(exp->car, env);
	if(nil != exp->cdr)
	{
		ret = prim_begin(exp->cdr, env);
	}
	return ret;
}

struct cell* eval(struct cell* exp, struct cell* env)
{
	if(exp == nil) return nil;

	switch(exp->type)
	{
		case INT: return exp;
		case SYM:
		{
			struct cell* tmp = assoc(exp, env);
			if(tmp == nil)
			{
				fprintf(stderr,"Unbound symbol\n");
				exit(EXIT_FAILURE);
			}
			return tmp->cdr;
		}
		case CONS:
		{
			if(exp->car == s_if)
			{
				if(eval(exp->cdr->car, env) != nil)
				{
					return eval(exp->cdr->cdr->car, env);
				}
				return eval(exp->cdr->cdr->cdr->car, env);
			}
			if(exp->car == s_cond) return evcond(exp->cdr, env);
			if(exp->car == s_begin) return prim_begin(exp->cdr, env);
			if(exp->car == s_lambda) return make_proc(exp->cdr->car, exp->cdr->cdr, env);
			if(exp->car == quote) return exp->cdr->car;
			if(exp->car == s_define) return(extend_top(exp->cdr->car, eval(exp->cdr->cdr->car, env)));
			if(exp->car == s_setb)
			{
				struct cell* pair = assoc(exp->cdr->car, env);
				struct cell* newval = eval(exp->cdr->cdr->car, env);
				pair->cdr = newval;
				return newval;
			}
			return apply(eval(exp->car, env), evlis(exp->cdr, env));
		}
		case PRIMOP: return exp;
		case PROC: return exp;
		default: return exp;
	}
	/* Not reached */
	return exp;
}

/*** Primitives ***/
struct cell* make_int(int a);
struct cell* prim_sum(struct cell* args)
{
	int sum;
	for(sum = 0; nil != args; args = args->cdr)
	{
		sum = sum + args->car->value;
	}
	return make_int(sum);
}

struct cell* prim_sub(struct cell* args)
{
	int sum = args->car->value;
	for(args = args->cdr; nil != args; args = args->cdr)
	{
		 sum = sum - args->car->value;
	}
	return make_int(sum);
}

struct cell* prim_prod(struct cell* args)
{
	int prod;
	for(prod = 1; nil != args; args = args->cdr)
	{
		prod = prod * args->car->value;
	}
	return make_int(prod);
}

struct cell* prim_div(struct cell* args)
{
	int div = args->car->value;
	for(args = args->cdr; nil != args; args = args->cdr)
	{
		div = div / args->car->value;
	}
	return make_int(div);
}

struct cell* prim_mod(struct cell* args)
{
	int mod = args->car->value % args->cdr->car->value;
	if(nil != args->cdr->cdr)
	{
		printf("wrong number of arguments to mod\n");
		exit(EXIT_FAILURE);
	}
	return make_int(mod);
}

struct cell* prim_and(struct cell* args)
{
	for(; nil != args; args = args->cdr)
	{
		if(tee != args->car) return nil;
	}
	return tee;
}

struct cell* prim_or(struct cell* args)
{
	for(; nil != args; args = args->cdr)
	{
		if(tee == args->car) return tee;
	}
	return nil;
}

struct cell* prim_not(struct cell* args)
{
	if(tee != args->car) return tee;
	return nil;
}

struct cell* prim_numgt(struct cell* args)
{
	int temp = args->car->value;
	for(args = args->cdr; nil != args; args = args->cdr)
	{
		if(temp <= args->car->value)
		{
			return nil;
		}
		temp = args->car->value;
	}
	return tee;
}

struct cell* prim_numge(struct cell* args)
{
	int temp = args->car->value;
	for(args = args->cdr; nil != args; args = args->cdr)
	{
		if(temp < args->car->value)
		{
			return nil;
		}
		temp = args->car->value;
	}
	return tee;
}

struct cell* prim_numeq(struct cell* args)
{
	int temp = args->car->value;
	for(args = args->cdr; nil != args; args = args->cdr)
	{
		if(temp != args->car->value)
		{
			return nil;
		}
	}
	return tee;
}

struct cell* prim_numle(struct cell* args)
{
	int temp = args->car->value;
	for(args = args->cdr; nil != args; args = args->cdr)
	{
		if(temp > args->car->value)
		{
			return nil;
		}
		temp = args->car->value;
	}
	return tee;
}

struct cell* prim_numlt(struct cell* args)
{
	int temp = args->car->value;
	for(args = args->cdr; nil != args; args = args->cdr)
	{
		if(temp >= args->car->value)
		{
			return nil;
		}
		temp = args->car->value;
	}
	return tee;
}

struct cell* prim_listp(struct cell* args)
{
	if(CONS == args->car->type)
	{
		return tee;
	}
	return nil;
}

struct cell* prim_display(struct cell* args)
{
	for(; nil != args; args = args->cdr)
	{
		if(INT == args->car->type)
		{
			printf("%d", args->car->value);
		}
		else if(ASCII == args->car->type)
		{
			printf("%c", args->car->value);
		}
		else if(CONS == args->car->type)
		{
			prim_display(args->car);
		}
		else
		{
			printf("%s", args->car->string);
		}
	}
	return tee;
}

int64_t cells_remaining();
struct cell* prim_freecell(struct cell* args)
{
	if(nil == args)
	{
		printf("Remaining Cells: ");
	}
	return make_int(cells_remaining());
}

struct cell* prim_ascii(struct cell* args)
{
	struct cell* temp;
	for(temp = args; nil != temp; temp = temp->cdr)
	{
		if(INT == temp->car->type)
		{
			temp->car->type = ASCII;
		}
	}
	return args;
}

struct cell* prim_list(struct cell* args) {return args;}
struct cell* prim_cons(struct cell* args) { return make_cons(args->car, args->cdr->car); }
struct cell* prim_car(struct cell* args) { return args->car->car; }
struct cell* prim_cdr(struct cell* args) { return args->car->cdr; }

/*** Initialization ***/
struct cell* intern(char *name);
struct cell* make_prim(void* fun);
struct cell* make_sym(char* name);
void init_sl3()
{
	nil = make_sym("nil");
	all_symbols = make_cons(nil, nil);
	top_env = make_cons(make_cons(nil, nil), nil);
	tee = intern("#t");
	extend_top(tee, tee);
	quote = intern("quote");
	s_if = intern("if");
	s_cond = intern("cond");
	s_lambda = intern("lambda");
	s_define = intern("define");
	s_setb = intern("set!");
	s_begin = intern("begin");
	extend_top(intern("+"), make_prim(prim_sum));
	extend_top(intern("-"), make_prim(prim_sub));
	extend_top(intern("*"), make_prim(prim_prod));
	extend_top(intern("/"), make_prim(prim_div));
	extend_top(intern("mod"), make_prim(prim_mod));
	extend_top(intern("and"), make_prim(prim_and));
	extend_top(intern("or"), make_prim(prim_or));
	extend_top(intern("not"), make_prim(prim_not));
	extend_top(intern(">"), make_prim(prim_numgt));
	extend_top(intern(">="), make_prim(prim_numge));
	extend_top(intern("="), make_prim(prim_numeq));
	extend_top(intern("<="), make_prim(prim_numle));
	extend_top(intern("<"), make_prim(prim_numlt));
	extend_top(intern("display"), make_prim(prim_display));
	extend_top(intern("free_mem"), make_prim(prim_freecell));
	extend_top(intern("ascii!"), make_prim(prim_ascii));
	extend_top(intern("list?"), make_prim(prim_listp));
	extend_top(intern("list"), make_prim(prim_list));
	extend_top(intern("cons"), make_prim(prim_cons));
	extend_top(intern("car"), make_prim(prim_car));
	extend_top(intern("cdr"), make_prim(prim_cdr));
}
