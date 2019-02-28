import haxe.macro.Type;
import vm.EVal;
import vm.Operator;

class VM
{
	public static function evalExpr(texpr:TypedExpr) : EVal
	{
		var context = new Map<Int, EVal>();

		// insert builtin trace
		context[0] = EFn(function (a) {
			var buf = [];

			for (e in a)
			{
				buf.push(EVal2str(e, context));
			}

			Sys.println(buf.join(" "));
			return EVoid;
		});

		return eval(texpr, context);
	}

	static function eval(texpr:TypedExpr, context:Map<Int, EVal>) : EVal
	{
		switch (texpr.expr)
		{
			case TConst(c):
				return switch (c)
				{
					case TInt(v): EInt(v);
					case TFloat(f): EFloat(Std.parseFloat(f));
					case TString(s): EString(s);
					case TBool(b): EBool(b);
					case TNull: ENull;
					case TSuper: throw "no super";
					case TThis: throw "no this";
				}

			case TArray(e1, e2):
				var val = eval(e1, context);

				switch (val)
				{
					case EArray(of, a):
						var idx = eval(e2, context);

						switch (idx)
						{
							case EInt(i):
								return a[i];

							default:
								throw "unexpected value, expected EInt, got " + idx;
						}

					default:
						throw "unexpected value, expected EArray, got " + val;
				}

			case TBinop(op, e1, e2):
				return Operator.binop(op, e1, e2, context, eval);

			case TField(e, field):
				//TODO class
				var field = switch (field)
				{
					case FAnon(_.get() => cf): cf.name;
					default: "field access type not supported";
				}

				switch (e.t)
				{
					case TAnonymous(_.get() => a):
						for (f in a.fields)
						{
							if (f.name == field)
							{
								return eval(f.expr(), context);
							}
						}

						throw 'Field "${field}" not found';

					default:
						throw 'Field access on non object "${e.t}"';
				}

			case TParenthesis(e):
				throw "TParenthesis unimplemented";

			case TObjectDecl(fields):
				return EObject(fields.map(f -> { name: f.name, val: eval(f.expr, context)}));

			case TArrayDecl(values):
				var value : Array<EVal> = [];

				for (v in values)
				{
					value.push(eval(v, context));
				}

				return EArray(texpr.t, value);

			case TCall(e, el):
				var v = eval(e, context);

				return switch (v)
				{
					case EIdent(id):
						return EVoid;

					case EFn(fn):
						var eargs = [];

						for (a in el)
						{
							eargs.push(eval(a, context));
						}

						fn(eargs);

					default: throw "unexpected value, expected EFunction, got " + v;
				}

			case TNew(c, params, el):
				throw "TNew unimplemented";

			case TUnop(op, postFix, e):
				return Operator.unop(op, postFix, e, context);

			case TFunction(tfunc):
				return EFn(function (a:Array<EVal>) {
					for (i in 0...tfunc.args.length)
					{
						context[tfunc.args[i].v.id] = a[i];
					}

					var ret = eval(tfunc.expr, context);

					for (i in 0...tfunc.args.length)
					{
						context.remove(tfunc.args[i].v.id);
					}

					return ret;
				});

			case TVar(v, expr):
				var val = eval(expr, context);
				context[v.id] = val;
				return val;

			case TBlock(exprs):
				var v = EVoid;

				for (e in exprs)
				{
					v = eval(e, context);
				}

				return v;

			case TFor(v, e1, e2):
				throw "TFor unimplemented";

			case TIf(econd, eif, eelse):
				return switch (eval(econd, context))
				{
					case EBool(b):
						if (b)
						{
							eval(eif, context);
						}
						else
						{
							eval(eelse, context);
						}

					default:
						throw "if condition is not bool";
				}

			case TWhile(econd, e, normalWhile):
				while (eval(econd, context).match(EBool(true)))
				{
					eval(e, context);
				}

				return EVoid;

			case TSwitch(e, cases, edef):
				throw "TSwitch unimplemented";

			case TTry(e, catches):
				throw "TTry unimplemented";

			case TReturn(e):
				throw "TReturn unimplemented";

			case TBreak:
				throw "TBreak unimplemented";

			case TContinue:
				throw "TContinue unimplemented";

			case TThrow(e):
				throw "TThrow unimplemented";

			case TCast(e, m):
				throw "TCast unimplemented";

			case TMeta(s, e):
				//TODO is there actually something to do at runtime?
				return eval(e, context);

			case TEnumIndex(e1):
				throw "TEnumIndex unimplemented";

			case TEnumParameter(e1, ef, index):
				throw "TEnumParameter unimplemented";

			case TTypeExpr(m):
				throw "TTypeExpr unimplemented";

			case TIdent(s):
				throw "TIdent unimplemented";

			case TLocal(v):
				if (!context.exists(v.id))
				{
					trace(context);
					throw "using unbound variable " + v.id;
				}

				return context[v.id];
		}
	}

	static function EVal2str(e:EVal, context:Map<Int, EVal>) : String
	{
		return switch (e)
		{
			case EBool(b): b ? "true" : "false";
			case ENull: "null";
			case EArray(_, a): "[" + a.join(", ") + "]";
			case EFloat(f): '$f';
			case EFn(_): 'function';
			case EInt(i): '$i';
			case EObject(fields):
				var buf = new StringBuf();
				buf.add("{");
				var fs = [];
				for (f in fields)
				{
					fs.push('${f.name}: ${EVal2str(f.val, context)}');
				}
				buf.add(fs.join(", "));
				buf.add("}");
				buf.toString();
			case ERegexp(r): throw "todo print ereg";
			case EString(s): s;
			case EVoid: "Void";
			case EIdent(id):
				if (!context.exists(id))
				{
					throw "using unbound variable";
				}
				EVal2str(context[id], context);
		}
	}
}
