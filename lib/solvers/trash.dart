import 'package:llama/expr.dart';

class TrashSolver extends Solver {
  TrashSolver(Expr expr) : super(expr);

  solve() async {
    bool contStep = true;
    var complexity = 0;
    var ops = 0;
    var de = 0;
    Expr step(Expr e) {
      complexity++;
      if (e is Lambda) {
        e.body = step(e.body);
        return e;
      } else if (e is Application) {
        var oc = contStep;
        var ac = false;
        while (true) {
          contStep = false;
          e.lambda = step(e.lambda);
          ac = contStep;
          if (!contStep) break;
        }
        contStep = oc || ac;

        if (e.lambda is Lambda) {
          Expr param;
          contStep = true;
          List<Lambda> stack = [];
          Expr rcrCopy(Expr te) {
            if (te is Lambda) {
              stack.add(te);
              te.body = rcrCopy(te.body);
              stack.removeLast();
            } else if (te is Application) {
              te.param = rcrCopy(te.param);
              te.lambda = rcrCopy(te.lambda);
            } else if (te is Variable) {
              if (te.bound == stack.length) {
                ops++;
                return copyShift(param ?? (param = e.param), stack.length);
              } else if (te.bound != null && te.bound > stack.length) {
                te.bound--;
              }
            }
            return te;
          }
          return rcrCopy((e.lambda as Lambda).body);
        } else {
          e.param = step(e.param);
        }
        return e;
      } else if (e is Variable) {
        return e;
      } else if (e is Deferred) {
        return e.re;
      } else throw "Unknown type";
    }

    while (contStep) {
      contStep = false;
      complexity = 0;
      ops = 0;
      try {
        expr = step(expr);
      } on StackOverflowError catch(e) {
        print("Stack overflow!");
        contStep = true;
      }
    }
  }
}