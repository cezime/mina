open Core
open Util

type curve = MNT4 | MNT6

let param_name name curve_scope =
  let s = (match curve_scope with MNT4 -> "MNT4" | MNT6 -> "MNT6") ^ "753" in
  Name.in_scope s name

let param name curve_scope = param_name name curve_scope |> Name.to_markdown

let q = param "q"

let r = param "r"

let preamble _pages =
  ksprintf Html.markdown
    {md|## Background
The basic operations needed for the SNARK prover algorithm are
multiplication and addition of integers.

Usually when programming we're used to working with 32-bit or 64-bit
integers and addition and multiplication mod $2^{32}$ or $2^{64}$) respectively.

For the SNARK prover though, the integers involved are a lot bigger.
For our purposes, the integers are 753 bits and are represented using
arrays of native integers. For example, we could represent them using
an array of 12 64-bit integers (since $12 \cdot 64 = 768 > 753$) or
an array of 24 32-bit integers (since $24 \cdot 32 = 768 > 753$).
And instead of computing mod $2^{753}$, we'll compute mod $q$ where
$q$ is either %s or %s.

Each element of such an array is called a "limb". For example, we would say
that we can represent a $2^{768}$ bit integer using 12 64-bit limbs.

We call the set of numbers $0, \dots, q - 1$ by the name $\mathbb{F}_q$.
This set forms a field, which means we can add, multiply, and divide numbers in
the set. Addition and multiplication happen mod q. It might seem weird that we can
divide, but it turns out for any $a, b$ in $\mathbb{F}_q$, there is a number $c$ 
in $\mathbb{F}_q$ such that $(c b) \mod q = a$.
In this case we say $a / b = c$ so that $(a / b) b \mod q = c b \mod q = a$
as you'd expect.

### Montgomery representation
Montgomery representation is an alternative way of representing elements of $\mathbb{F}_q$ so that
multiplication mod $q$ can be computed more efficiently.

Let $q$ be one of %s or %s and let $R = 2^{768}$.
The Montgomery representation of the nubmer $x$ is $(x R) \mod q$. So for example,
when $q$ is %s, the number 5 is represented as $(5 \cdot 2^{768}) \mod q$ which
happens to be
```
15141386232259939182423724568694911114488003694957216858820448966622494022908702997737632032507442391226452946698823665470952711443326537357991482811741996884665155234620507693793230633117754640516203527639390490866666926222409
```
This number then is represented as a little-endian length 12 array of 64-bit integers.

In summary, we represent the number `x` as an array `a` with
```python
a.map((ai, i) => (2**i) * ai).sum() == (x * R) %% q
```

Let us see how multplication works in this setting. We'll
use pseudocode with `%%` for $\mathrm{mod}$.

Given the Montgomery representation
`X = (x * R) %% q` of `x` and
`Y = (y * R) %% q` of `y`,
we want to compute the
Montgomery representation of `(x * y) %% q`,
which is `(x * y * R) %% q`.

We have
```javascript
X * Y
== ((x * R) %% q) * ((y * R) %% q)
== (x * y * R * R) %% q
```
So, if we had a function `div_R` for letting
us divide by `R` mod `q`, we would be able to compute
the Montgomery representation of `x * y` from `X`
and `Y` as `div_R(X * Y)`.

To recap, to implement multiplication mod $q$, we need to implement two functions:

1. Big integer multiplication, which takes two `k` limb integers and returns the `2 * k`-limb integer which
    is their product.
2. `div_R`, which takes a `2 * k`-limb integer `Z` and returns the `k`-limb integer equal to
    `(Z * r) %% q`, where `r` is the inverse of `R`. That is, the number with `(R * r) %% q = 1`.

We will then have
```
div_R(X * Y)
== div_R((x * y * R * R) %% q)
== (x * y * R * R * r) %% q
== (x * y * R * 1) %% q
== (x * y * R) %% q
```
which is the Montgomery representation of the product of the inputs, exactly as we wanted.

### Resources

- Algorithms for big-integer multiplication and `div_R` (often called Montgomery reduction)
are given [here](http://cacr.uwaterloo.ca/hac/about/chap14.pdf), where our $q$ is called $m$.
- A C++ implementation of Montgomery reduction can be found [here](https://github.com/scipr-lab/libff/blob/master/libff/algebra/fields/fp.tcc#L161).
- [These slides](https://cryptojedi.org/peter/data/pairing-20131122.pdf) may have useful insights for squeezing out extra performance.
- This problem is sometimes called big integer multiplication, multi-precision multiplication,
  or more specifically "modular multiplication". You can find lots of great resources by
  searching for these terms along with "GPU".|md}
    (q MNT4) (q MNT6) (q MNT4) (q MNT6) (q MNT4)

let html_to_string x =
  Async.Thread_safe.block_on_async_exn (fun () -> Html.to_string x)

let interface : Html.t Problem.Interface.t =
  let open Problem.Interface in
  let open Let_syntax in
  (*
  let%bind [q] =
    def ["q"]
      (List.map ["MNT4753"; "MNT6753"] ~f:(fun c ->
           Vec.[Name (Name.in_scope c "q")] ))
  in *)
  let q = param_name "q" in
  let fq name = Type.field (Type.Field.prime (Name (q name))) in
  let%bind n = !Input "n" (Literal UInt64) in
  let arr field =
    Literal (Type.Array {element= field; length= Some (Name n)})
  in
  let%map _x =
    ( ! ) Input "x"
      (arr (fq MNT4))
      ~note:
        (Html.markdown
           "The elements of `x` are represented using the montgomery\n\
            representation as described above.")
  and _y =
    ( ! ) Input "y"
      (arr (fq MNT6))
      ~note:
        (Html.markdown
           "The elements of `y` are represented using the montgomery\n\
            representation as described above.")
  and _ = !Output "out_x" (fq MNT4)
  and _ = !Output "out_y" (fq MNT6) in
  ksprintf Html.markdown
    {md|The output `out_x` should be `x[0] * x[1] * ... * x[n - 1]`
where `*` is multiplication in the field %s.

The output `out_y` should be `y[0] * y[1] * ... * y[n - 1]`
where `*` is multiplication in the field %s.
|md}
    (html_to_string (Type.render (fq MNT4)))
    (html_to_string (Type.render (fq MNT6)))

let problem : Problem.t =
  { title= "Field arithmetic"
  ; quick_details=
      { description=
          Html.text
            "Multiply together an array of elements of a prime-order field."
      ; prize= Prize.stage1 50 }
  ; preamble
  ; interface
  ; reference_implementation_url= ""
  ; postamble= Fn.const (Html.text "TODO") }