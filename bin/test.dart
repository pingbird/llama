// Copyright (c) 2017, pixel. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'package:lambdafuck/llama.dart';
import 'package:worker/worker.dart';

const Map<String, String> tests = const {
  //'while 0 (\\i uIsNEQ (uMul i 2) 8) (\\i uSucc i)': '4',
  
  '[(true 1 2) (false 1 2)]': '[1 2]',
  '[(bNot false) (bNot true)]': '[true false]',
  '[(bAnd false false) (bAnd false true) (bAnd true false) (bAnd true true)]': '[false false false true]',
  '[(bOr false false) (bOr false true) (bOr true false) (bOr true true)]': '[false true true true]',
  '[(bXor false false) (bXor false true) (bXor true false) (bXor true true)]': '[false true true false]',
  
  '[(uSucc 0) (uSucc 7)]': '[1 8]',
  '[(uPred 0) (uPred 1) (uPred 8)]': '[0 0 7]',
  '[(uAdd 0 0) (uAdd 0 5) (uAdd 6 9)]': '[0 5 15]',
  '[(uSub 0 0) (uSub 0 5) (uSub 13 6)]': '[0 0 7]',
  '[(uMul 0 0) (uMul 1 7) (uMul 20 21)]': '[0 7 420]',
  //'[(uDiv 0 0) (uDiv 1 7) (uDiv 10 2)]': '[0 0 5]',
  '[(uPow 0 0) (uPow 2 8) (uPow 10 3)]': '[1 256 1000]',
  '[(uIsZero 0) (uIsZero 1) (uIsZero 2)]': '[true false false]',
  '[(uEQ 0 0) (uEQ 1 2) (uEQ 3 3)]': '[true false true]',
  '[(uNEQ 0 0) (uNEQ 1 2) (uNEQ 3 3)]': '[false true false]',
  '[(uGT 0 0) (uGT 6 9) (uGT 9 6)]': '[false false true]',
  '[(uLT 0 0) (uLT 6 9) (uLT 9 6)]': '[false true false]',
  '[(uGE 0 0) (uGE 6 9) (uGE 9 6)]': '[true false true]',
  '[(uLE 0 0) (uLE 6 9) (uLE 9 6)]': '[true true false]',
  '[(uSigned 0) (uSigned 6) (uSigned 9)]': '[+0 +6 +9]',
  
  '[(iSucc +0) (iSucc +6) (iSucc -9)]': '[+1 +7 -8]',
  '[(iPred +0) (iPred +6) (iPred -9)]': '[-1 +5 -10]',
  '[(iAdd +10 +4) (iAdd +0 -5) (iAdd +6 -9)]': '[+14 -5 -3]',
  '[(iSub -10 +4) (iSub +0 -5) (iSub +6 -9)]': '[-14 +5 +15]',
  '[(iMul -6 +4) (iMul -7 -7) (iMul -20 +21)]': '[-24 +49 -420]',
  '[(iIsZero +0) (iIsZero +1) (iIsZero -1)]': '[true false false]',
  '[(iIsPos +0) (iIsPos +1) (iIsPos -1)]': '[false true false]',
  '[(iIsNeg +0) (iIsNeg +1) (iIsNeg -1)]': '[false false true]',
  '[(iEQ +0 +0) (iEQ +1 +2) (iEQ +3 -3) (iEQ +1 +1)]': '[true false false true]',
  '[(iNEQ +0 +0) (iNEQ +1 +2) (iNEQ +3 -3) (iNEQ +1 +1)]': '[false true true false]',
  '[(iGT +0 +0) (iGT +6 -9) (iGT +9 +6) (iGT -9 -6)]': '[false true true false]',
  '[(iLT +0 +0) (iLT +6 -9) (iLT +9 +6) (iLT -9 -6)]': '[false false false true]',
  '[(iGE +0 +0) (iGE +6 -9) (iGE +9 +6) (iGE -9 -6)]': '[true true true false]',
  '[(iLE +0 +0) (iLE +6 -9) (iLE +9 +6) (iLE -9 -6)]': '[true false false true]',
  '[(iUnsigned +0) (iUnsigned +20) (iUnsigned -20)]': '[0 20 0]',
  
  '[(tTuple 4 a b c d) (tTuple 2 a b) (tTuple 0)]': '[<a b c d> <a b> <>]',
  '[(tVector 0 <>) (tVector 1 <a>) (tVector 3 <a b c>)]': '[[] [a] [a b c]]',
  '[\n'
    '(tGet 4 0 a b c d)\n'
    '(tGet 3 2 a b c)\n'
    '(tGet 1 0 a)\n'
    ']' : '[a c a]',
  '[\n'
    '(tVararg 4 (\\v v) a b c d)\n'
    '(tVararg 0 (\\v v))\n'
    '(tVararg 3 (\\v vMap v uSucc) 2 3 4)\n'
    ']' : '[[a b c d] [] [3 4 5]]',
  '[\n'
    '(tSet 3 <0 1 2> 0 1)\n'
    '(tSet 4 <0 1 2 3> 4 1)\n'
    '(tSet 5 <0 1 2 3 4> 4 5)\n'
    ']' : '[<1 1 2> <0 1 2 3> <0 1 2 3 5>]',
  
  '[\n'
    '(vFold [] 0 uAdd)\n'
    '(vFold [1 2 3] 0 uAdd)\n'
    '(vFold [1 2 3] 2 uMul)\n'
    ']' : '[0 6 12]',
  '[\n'
    '(vConcat [] [])\n'
    '(vConcat [0 1 2] [3 4 5])\n'
    '(vConcat [] [4 2 0])\n'
    ']' : '[[] [0 1 2 3 4 5] [4 2 0]]',
  '[\n'
    '(vExpand [] (\\e []))\n'
    '(vExpand [0 1 2 3 4 5] (\\e uGT e 3 [e] []))\n'
    '(vExpand [1 5 9] (\\e [e (uSucc e)]))\n'
    ']' : '[[] [4 5] [1 2 5 6 9 10]]',
  '[\n'
    '(vInsertStart [] 0)\n'
    '(vInsertStart [1 2] 0)\n'
    '(vInsertStart [2 4 0] 0)\n'
    ']' : '[[0] [0 1 2] [0 2 4 0]]',
  '[\n'
    '(vInsertEnd [] 0)\n'
    '(vInsertEnd [1 2] 0)\n'
    '(vInsertEnd [2 4 0] 0)\n'
    ']' : '[[0] [1 2 0] [2 4 0 0]]',
  '[\n'
    '(vLength [])\n'
    '(vLength [1 2])\n'
    '(vLength [2 4 0 3 1])\n'
    ']' : '[0 2 5]',
  '[\n'
    '(vFirstWhere [] (\\e true) 0)\n'
    '(vFirstWhere [1 2 3] (\\e true) 0)\n'
    '(vFirstWhere [1 2 3 4 5] (\\e uGT e 3) 0)\n'
    ']' : '[0 1 4]',
  '[\n'
    '(vTake [] 1)\n'
    '(vTake [1 2 3] 6)\n'
    '(vTake [1 2 3 4 5] 4)\n'
    ']' : '[[] [1 2 3] [1 2 3 4]]',
  '[\n'
    '(vSkip [] 1)\n'
    '(vSkip [1 2 3] 6)\n'
    '(vSkip [1 2 3 4 5] 2)\n'
    ']' : '[[] [] [3 4 5]]',
  '[\n'
    '(vGet [] 1 0)\n'
    '(vGet [1 2 3] 0 0)\n'
    '(vGet [1 2 3 4 5] 4 0)\n'
    ']' : '[0 1 5]',
  '[\n'
    '(vWhere [0 1 2] (\\e false))\n'
    '(vWhere [1 2 3 4 5 6] (\\e uGT e 3))\n'
    '(vWhere [0 1 0 3 5 0] uIsZero)\n'
    ']' : '[[] [4 5 6] [0 0 0]]',
  '[\n'
    '(vRemoveWhere [0 1 2] (\\e true))\n'
    '(vRemoveWhere [1 2 3 4 5 6] (\\e uGT e 3))\n'
    '(vRemoveWhere [0 1 0 3 5 0] uIsZero)\n'
    ']' : '[[] [1 2 3] [1 3 5]]',
  '[\n'
    '(vFoldMap [2 1 2 1] 0 \\st\\e <(uSucc st) (uAdd st e)>)\n'
    '(vFoldMap [4 5 6 7] 1 \\st\\e <e (uAdd st e)>)\n'
    '(vFoldMap [4 5 6 7] 1 \\st\\e <e (uMul st e)>)\n'
    ']' : '[[2 2 4 4] [5 9 11 13] [4 20 30 42]]',
  '[\n'
    '(vIndexify [])\n'
    '(vIndexify [0 1 2])\n'
    '(vIndexify [4 1 2 0])\n'
    ']' : '[[] [<0 0> <1 1> <2 2>] [<0 4> <1 1> <2 2> <3 0>]]',
  '[\n'
    '(vSet [0 1 2] 0 1)\n'
    '(vSet [0 1 2 3] 4 1)\n'
    '(vSet [0 1 2 3 4] 4 5)\n'
    ']' : '[[1 1 2] [0 1 2 3] [0 1 2 3 5]]',
  '[\n'
    '(vReverse [])\n'
    '(vReverse [0 1 2])\n'
    '(vReverse [6 9 6 9])\n'
    ']' : '[[] [2 1 0] [9 6 9 6]]',
  '[\n'
    '(vGenerate 0 1)\n'
    '(vGenerate 1 2)\n'
    '(vGenerate 3 3)\n'
    ']' : '[[] [2] [3 3 3]]',
  '[\n'
    '(vIsEmpty [])\n'
    '(vIsEmpty [1])\n'
    '(vIsEmpty [1 2 3])\n'
    ']' : '[true false false]',
  '[\n'
    '(vRemoveLast [])\n'
    '(vRemoveLast [1])\n'
    '(vRemoveLast [1 2 3])\n'
    ']' : '[[] [] [1 2]]',
  '[\n'
    '(vRemoveFirst [])\n'
    '(vRemoveFirst [1])\n'
    '(vRemoveFirst [1 2 3])\n'
    ']' : '[[] [] [2 3]]',
  '[\n'
    '(vSlice [] 0 1)\n'
    '(vSlice [1 2 3] 0 2)\n'
    '(vSlice [1 2 3 4 5] 1 4)\n'
    ']' : '[[] [1 2] [2 3 4]]',
  '[\n'
    '(vLast [] 6)\n'
    '(vLast [1] 9)\n'
    '(vLast [1 2 3] 4)\n'
    ']' : '[6 1 3]',
  '[\n'
    '(vFirst [] 6)\n'
    '(vFirst [1] 9)\n'
    '(vFirst [1 2 3] 4)\n'
    ']' : '[6 1 1]',
  '[\n'
    '(vEQ uEQ [] [])\n'
    '(vEQ uEQ [1 2] [3 4])\n'
    '(vEQ uEQ [1 2 3] [1 2])\n'
    '(vEQ uEQ [1 2 3 4] [1 2 3 4])\n'
    ']' : '[true false false true]',
  '[\n'
    '(vTakeWhile [0 1 2] (\\e false))\n'
    '(vTakeWhile [0 1 2] (\\e true))\n'
    '(vTakeWhile [1 2 3 4 5 6] (\\e uLT e 4))\n'
    '(vTakeWhile [0 0 0 3 5 0] uIsZero)\n'
    ']' : '[[] [0 1 2] [1 2 3] [0 0 0]]',
  '[\n'
    '(vSkipWhile [0 1 2] (\\e true))\n'
    '(vSkipWhile [0 1 2] (\\e false))\n'
    '(vSkipWhile [1 2 3 4 5 6] (\\e uLT e 4))\n'
    '(vSkipWhile [0 0 0 3 5 0] (\\e uIsZero e))\n'
    ']' : '[[] [0 1 2] [4 5 6] [3 5 0]]',
  '[\n'
    '(vInsertAt [] 0 1)\n'
    '(vInsertAt [] 1 1)\n'
    '(vInsertAt [1] 0 2)\n'
    '(vInsertAt [1] 1 2)\n'
    '(vInsertAt [1 2 3 4] 2 9)\n'
    ']' : '[[1] [1] [2 1] [1 2] [1 2 9 3 4]]',
  '[\n'
    '(vReduce [] uAdd 0)\n'
    '(vReduce [0 1 2 3] uAdd 0)\n'
    '(vReduce [2 1 2 3] uMul 0)\n'
    ']' : '[0 6 12]',
  '[\n'
    '(vRemoveAt [] 0)\n'
    '(vRemoveAt [] 1)\n'
    '(vRemoveAt [1] 0)\n'
    '(vRemoveAt [1] 1)\n'
    '(vRemoveAt [1 2 3 4] 2)\n'
    ']' : '[[] [] [] [1] [1 2 4]]',
  '[\n'
    '(vAny [] uIsZero)\n'
    '(vAny [1] uIsZero)\n'
    '(vAny [0] uIsZero)\n'
    '(vAny [1 2 0 3] uIsZero)\n'
    ']' : '[false false true true]',
  '[\n'
    '(vFirstWhere [] (\\e uGT e 3) 0)\n'
    '(vFirstWhere [1 2 3] (\\e uGT e 3) 0)\n'
    '(vFirstWhere [1 2 3 4 5] (\\e uGT e 3) 0)\n'
    '(vFirstWhere [3 2 9 2] (\\e uGT e 3) 0)\n'
    ']' : '[0 0 4 9]',
  
  '[\n'
    '(mFromVec uEQ [] (\\e e) (\\e uMul e e))\n'
    '(mFromVec uEQ [1] (\\e e) (\\e uMul e e))\n'
    '(mFromVec uEQ [1 2 3 4] (\\e e) (\\e uMul e e))\n'
    ']' : '[[] [<1 1>] [<1 1> <2 4> <3 9> <4 16>]]',
  '[\n'
    '(mSet uEQ [] 0 1)\n'
    '(mSet uEQ [<1 2>] 0 1)\n'
    '(mSet uEQ [<1 2> <2 3>] 1 3)\n'
    ']' : '[[<0 1>] [<1 2> <0 1>] [<1 3> <2 3>]]',
  '[\n'
    '(mKeys [])\n'
    '(mKeys [<0 1>])\n'
    '(mKeys [<0 1> <1 2>])\n'
    ']' : '[[] [0] [0 1]]',
  '[\n'
    '(mValues [])\n'
    '(mValues [<0 1>])\n'
    '(mValues [<0 1> <1 2>])\n'
    ']' : '[[] [1] [1 2]]',
  '[\n'
    '(mGet uEQ [] 0 0)\n'
    '(mGet uEQ [<0 1>] 0 0)\n'
    '(mGet uEQ [<0 1> <3 2>] 3 0)\n'
    ']' : '[0 1 2]',
  '[\n'
    '(mExists uEQ [] 0)\n'
    '(mExists uEQ [<0 1>] 0)\n'
    '(mExists uEQ [<0 1> <3 2>] 2)\n'
    '(mExists uEQ [<0 1> <3 2> <2 3>] 2)\n'
    ']' : '[false true false true]',
  '[\n'
    '(mContains uEQ [] 0)\n'
    '(mContains uEQ [<0 1>] 0)\n'
    '(mContains uEQ [<0 1> <3 2>] 2)\n'
    '(mContains uEQ [<0 1> <3 2> <2 3>] 2)\n'
    ']' : '[false false true true]',
  '[\n'
    '(mRemove uEQ [] 0)\n'
    '(mRemove uEQ [<1 2>] 0)\n'
    '(mRemove uEQ [<1 2> <2 3>] 1)\n'
    '(mRemove uEQ [<1 2> <3 2> <2 3>] 3)\n'
    ']' : '[[] [<1 2>] [<2 3>] [<1 2> <2 3>]]',
  '[\n'
    '(mAddFromVec uEQ [] [] (\\e e) (\\e uMul e e))\n'
    '(mAddFromVec uEQ [<0 0>] [1] (\\e e) (\\e uMul e e))\n'
    '(mAddFromVec uEQ [<2 5>] [1 2 3] (\\e e) (\\e uMul e e))\n'
    ']' : '[[] [<0 0> <1 1>] [<2 4> <1 1> <3 9>]]',
  '[\n'
    '(mAddAll uEQ [] [<3 3>])\n'
    '(mAddAll uEQ [<0 0> <1 1> <2 2>] [<3 3>])\n'
    '(mAddAll uEQ [<0 0> <1 1> <2 2>] [<1 3> <3 3>])\n'
    ']' : '[[<3 3>] [<0 0> <1 1> <2 2> <3 3>] [<0 0> <1 3> <2 2> <3 3>]]',
};

class MyTask implements Task {
  final String code;

  MyTask(this.code);
  
  String execute() {
    //print("testing ${code}..");
    return (new TrashSolver(
      new Parser().parse("test", "~\\\"stdlib.lf\"\n${code}")
        ..bind())
      ..solve()).expr.toString();
  }
}

main() async {
  var t = new DateTime.now();
  var worker = new Worker(poolSize: 8, spawnLazily: false);
  await Future.wait(tests.keys.map((code) async {
    var f = worker.handle(new MyTask(code));
    String res = await f;
    if (res != tests[code]) {
      print("Mismatch!");
      print("code:\n$code");
      print("expected:\n${tests[code]}");
      print("got:\n${res}");
    }
  }));
  print("done");
  print("took ${(new DateTime.now().millisecondsSinceEpoch - t.millisecondsSinceEpoch) / 1000}");
  worker.close();
}
