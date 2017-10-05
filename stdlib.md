#Standard Library

###Util
```
null // the identity function \null null
return // is \x x
if b t f // is \b\t\f b t f
for start end iv l // equivalent to fold (vGenerateRange start end) iv l
while st lb l
    // st = l(st) while lb(st) is true
until st lb l
    // st = l(st) until lb(st) is true
    // equivalent to while (l st) (\b bNot (lb b)) l
```

###Tuple
```
tPair a b // makes a pair with a and b
(t) tFirst // gets the first value of a pair
tSetFirst t v // sets the first value of a pair to v
(t) tSecond // gets the second value of a pair
tSetSecond t v // sets the second value of a pair to v
tVararg i f ... // reads a variable number of arguments to a vector and return f(v)
tTuple i ... // makes a tuple with i length
(t) (tGet i p) // gets the value at p from a tuple with i length
tSet t i n v // sets t[n] of tuple length i to v 
tVector i t // turns a tuple into a vector
```

###Bool
```
true // is \t\f t
false // is \t\f f
bNot x // returns !x
bOr x y // returns x || y
bAnd x y // returns x && y
bXor x y // returns x ^ y
```

###Int
```
iSucc x // returns x + 1
iPred x // returns x - 1
iAdd x y // returns x + y
iSub x y // returns x - y
iMul x y // returns x * y
iDiv x y // returns x / y
iExp x y // returns exp(x, y)
iIsZero x // returns x == 0
iIsGT x y // return x > y
iIsLT x y // return x < y
iIsGE x y // return x >= y
iIsLE x y // return x <= y
iIsEQ x y // return x == y
iSigned x // converts x to signed
```

###Signed Int
```
sSucc x // returns x + 1
sPred x // returns x - 1
sNeg x // returns -x
sAdd x y // returns x + y
sSub x y // returns x - y
sMul x y // returns x * y
sDiv x y // returns x / y
sIsZero x // returns x == 0
sIsGT x y // return x > y
sIsLT x y // return x < y
sIsGE x y // return x >= y
sIsLE x y // return x <= y
sIsEQ x y // return x == y
sIsNEQ x y // return x != y
sNormalize x // normalizes x so that at least one side is zero
sUnsigned x // converts x to unsigned number
```

###Vector

```
vGet v i d // returns v[i] or d if out of bounds (zero indexed)
vSet v i e // returns v where v[i] = e
vLast v d // returns the last value in v or d if empty
vFirst v d // returns the first value in v or d if empty
vLength v // returns v.length
vReverse v // returns the reverse of v
vTake v i // returns the first i values of the vector
vTakeWhile v l // returns the values of v until l(v[i]) is false
vSkip v i // returns the vector but skips the first i elements
vSkipWhile v l // returns the values of v starting when l(v[i]) is truevFirstWhere v l d // returns the first element where l(e) returns true, d if none are found
vMap v l
    // returns v.map(l) where l is a llama that takes an element and returns the replacement
    // so that out[n] = l(v[n])
vFoldMap v iv lf
    // same as map but keeps a state so that out[n], st = l(st, v[n])
vWhere v l
    // returns v.where(l) where l is a llama that takes an element and returns a boolean
    // the output is an array where l returned true
vReduce v l d
    // reduces v to a single value by combining them with l(e1, e2) or d if v is empty
vFold v iv l
    // reduces a vector to a single value where iv is the initial value
    // l is a lambda that takes the previous value (iv if first element) and the current element
    // and returns the next value to pass to the callback or return value if its the last element
vExpand v l
    // expand function like dart's Iterable.expand
vIndexify v // returns an array where out[i] = mkTuple(i, out[i])
vGenerate j e // generates a Vector with j elements and filling it with e
vGenerateRange i j // generates a Vector of integers starting at i and ending before j
vIsEmpty v // returns true if v is empty, else returns false
vRemoveLast v // removes the last element
vRemoveFirst v // removes the first element
vRemoveAt v i // removes element at i
vRemoveRange v start end // removes range of elements
vInsertEnd v e // inserts e at the end of v
vInsertStart v e // inserts e at the start of v
vInsertAt v i e // inserts e into v at i
vConcat va vb // appends vb to va
vSlice v start end // returns a slice of v from start to before end
vEquals cmp a b // returns true if both vectors have the same contents using cmp
```

~\ded (\code\input
    ~\jmp (getjmp code)

    ~\jmpFwd (jmp (tGet 3 1))
    ~\jmpBack (jmp (tGet 3 2))

    ~\indexMap (\v\i
        (vFirstWhere v (\e iIsEq (e tFirst) i) 0) tSecond
    )

    ~\codeLength (vLength code)

    ~\pc (tGet 5 0)
    ~\setPc (\st\v tSet st 5 0 v)
    ~\ptr (tGet 5 1)
    ~\setPtr (\st\v tSet st 5 1 v)
    ~\mem (tGet 5 2)
    ~\setMem (\st\v tSet st 5 2 v)
    ~\out (tGet 5 3)
    ~\setOut (\st\v tSet st 5 3 v)
    ~\inputIndex (tGet 5 4)
    ~\setInputIndex (\st\v tSet st 5 4 v)

    ~\byteSucc (\n
        (iIsEQ n 255) 0 (iSucc n)
    )

    ~\bytePred (\n
        (iIsEQ n 0) 255 (iPred n)
    )

    (while (mkTuple 5
        0 // pc
        0 // ptr
        [0] // mem
        [] // out
        0 // inputIndex
    ) (\st iIsLT (st pc) codeLength) (\st
        ~\st (
            ~\inst (vGet code (st pc) null)
            if (iIsEQ inst '>') (
                ~\st (setPtr st (iSucc~st ptr))
                (if (iIsEQ (st ptr) (vLength~st mem))
                    return setMem st~vInsertEnd (st mem) 0
                ) (return st)
            ) if (iIsEQ inst '<') (
                if (iIsZero~st ptr) (
                    return setMem st~vInsertStart (st mem) 0
                ) (
                    return setPtr st~iPred~st ptr
                )
            ) if (iIsEQ inst '+') (
                return setMem st~vSet (st mem) (st ptr)~byteSucc~vGet (st mem) (st ptr) null
            ) if (iIsEQ inst '-') (
                return setMem st~vSet (st mem) (st ptr)~bytePred~vGet (st mem) (st ptr) null
            ) if (iIsEQ inst '[') (
                if (iIsZero~vGet (st mem) (st ptr) 0) (
                    return setPc st~indexMap jmpFwd (st pc)
                ) (
                    return st
                )
            ) if (iIsEQ inst ']') (
                return setPc st~indexMap jmpBack (st pc)
            ) if (iIsEQ inst ',') (
                ~\st (setMem st~vSet (st mem) (st ptr)~vGet input (st inputIndex) 0)
                return setInputIndex st~iSucc~st inputIndex
            ) if (iIsEQ inst '.') (
                setOut st~vInsertEnd (st out)~vGet (st mem) (st ptr) 0
            ) st
        )
        return setPc st~iSucc (st pc)
    )) out
)"++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++." ""