import 'package:llama/expr.dart';

class TraceSolver extends Solver {
  TraceSolver(Expr expr) : super(expr);

  solve() async {
    bool contStep = true;
    bool forceDown = false;
    var complexity = 0;
    var ops = 0;
    var de = 0;
    Expr step(Expr e) {
      complexity++;
      if (e is Lambda) {
        if (forceDown) return e;
        e.body = step(e.body);
        return e;
      } else if (e is Application) {
        return e;
      } else if (e is Variable) {
        if (e.bound == null) {
          throw "die";
        }
        return e;
      } else if (e is Deferred) {
        if (e.value == null) de++;
        if (de > 100) {
          print("force");
          contStep = true;
          return e;
        }
        return e.re;
      } else throw "Unknown type";
    }

    while (contStep && !forceDown) {
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
