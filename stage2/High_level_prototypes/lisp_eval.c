#include "lisp.h"

/* Support functions */
struct cell* car(struct cell* a)
{
	return a->car;
}

struct cell* cdr(struct cell* a)
{
	return a->cdr;
}


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
	return multiple_extend(extend(env, car(syms), car(vals)), cdr(syms), cdr(vals));
}

struct cell* extend_top(struct cell* sym, struct cell* val)
{
	top_env->cdr = make_cons(make_cons(sym, val), cdr(top_env));
	return val;
}

struct cell* assoc(struct cell* key, struct cell* alist)
{
	if(nil == alist) return nil;
	if(car(car(alist)) == key) return car(alist);
	return assoc(key, cdr(alist));
}

/*** Evaluator (Eval/Apply) ***/
struct cell* eval(struct cell* exp, struct cell* env);
struct cell* make_proc(struct cell* a, struct cell* b, struct cell* env);
struct cell* evlis(struct cell* exps, struct cell* env)
{
	if(exps == nil) return nil;
	return make_cons(eval(car(exps), env), evlis(cdr(exps), env));
}

struct cell* progn(struct cell* exps, struct cell* env)
{
	if(exps == nil) return nil;
	for(;;)
	{
		if(cdr(exps) == nil) return eval(car(exps), env);
		eval(car(exps), env);
		exps = cdr(exps);
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
			return cdr(tmp);
		}
		case CONS:
		{
			if(car(exp) == s_if)
			{
				if(eval(car(cdr(exp)), env) != nil)
				{
					return eval(car(cdr(cdr(exp))), env);
				}
				return eval(car(cdr(cdr(cdr(exp)))), env);
			}
			if(car(exp) == s_lambda) return make_proc(car(cdr(exp)), cdr(cdr(exp)), env);
			if(car(exp) == quote) return car(cdr(exp));
			if(car(exp) == s_define) return(extend_top(car(cdr(exp)), eval(car(cdr(cdr(exp))), env)));
			if(car(exp) == s_setb)
			{
				struct cell* pair = assoc(car(cdr(exp)), env);
				struct cell* newval = eval(car(cdr(cdr(exp))), env);
				pair->cdr = newval;
				return newval;
			}
			return apply(eval(car(exp), env), evlis(cdr(exp), env));
		}
		case PRIMOP: return exp;
		case PROC: return exp;
	}
	/* Not reached */
	return exp;
}

/*** Primitives ***/
struct cell* make_int(int a);
struct cell* prim_sum(struct cell* args)
{
	int sum;
	for(sum = 0; nil != args; args = cdr(args))
	{
		sum = sum + car(args)->value;
	}
	return make_int(sum);
}

struct cell* prim_sub(struct cell* args)
{
	int sum = car(args)->value;
	for(args = cdr(args); nil != args; args = cdr(args))
	{
		 sum = sum - car(args)->value;
	}
	return make_int(sum);
}

struct cell* prim_prod(struct cell* args)
{
	int prod;
	for(prod = 1; nil != args; args = cdr(args))
	{
		prod = prod * car(args)->value;
	}
	return make_int(prod);
}

struct cell* prim_numeq(struct cell* args)
{
	return car(args)->value == car(cdr(args))->value ? tee : nil;
}

struct cell* prim_cons(struct cell* args) { return make_cons(car(args), car(cdr(args))); }
struct cell* prim_car(struct cell* args) { return car(car(args)); }
struct cell* prim_cdr(struct cell* args) { return cdr(car(args)); }

/*** Initialization ***/
struct cell* intern(char *name);
struct cell* make_prim(void* fun);
struct cell* make_sym(char* name);
void init_sl3()
{
	nil = make_sym("nil");
	all_symbols = make_cons(nil, nil);
	top_env = make_cons(make_cons(nil, nil), nil);
	tee = intern("t");
	extend_top(tee, tee);
	quote = intern("quote");
	s_if = intern("if");
	s_lambda = intern("lambda");
	s_define = intern("define");
	s_setb = intern("set!");
	extend_top(intern("+"), make_prim(prim_sum));
	extend_top(intern("-"), make_prim(prim_sub));
	extend_top(intern("*"), make_prim(prim_prod));
	extend_top(intern("="), make_prim(prim_numeq));
	extend_top(intern("cons"), make_prim(prim_cons));
	extend_top(intern("car"), make_prim(prim_car));
	extend_top(intern("cdr"), make_prim(prim_cdr));
}
