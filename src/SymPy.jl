__precompile__() 

## TODO:
## * tidy up code

module SymPy

using Compat

"""

SymPy package to interface with Python's [SymPy package](http://www.sympy.org) through `PyCall`.

The basic idea is that a new type -- `Sym` -- is made to hold symbolic
objects.  For this type, the basic operators and appropriate functions
of `Julia` are overloaded for `Sym` objects so that the expressions
are treated symbolically and not evaluated immediately. Instances of
this type are created by the constructor `Sym` or `symbols` or the macro
`@vars`.

As well, many -- but not all -- of the SymPy functions are ported to
allow them to be called on `Sym` objects. Mostly these are implemented
through metaprogramming, so adding missing functions is not hard. They
are not generated automatically though, rather added by hand.

To find documentation on SymPy functions, one should refer to
SymPy's [website](http://docs.sympy.org/latest/index.html).

Plotting is provided through the `Plots` interface. For details, see the help page for `sympy_plotting`.

The package tutorial provides many examples. This can be read on
[GitHub](https://github.com/jverzani/SymPy.jl/blob/master/examples/tutorial.ipynb).

"""
SymPy


using Compat

using PyCall

import Base: show
import Base: convert, promote_rule
import Base: getindex
import Base: start, next, done
import Base: complex
import Base: sin, cos, tan, sinh, cosh, tanh, asin, acos,
       atan, asinh, acosh, atanh, sec, csc, cot, asec,
       acsc, acot, sech, csch, coth, asech, acsch, acoth,
       sinc, cosc, cosd, cotd, cscd, secd, sind, tand,
       acosd, acotd, acscd, asecd, asind, atand, atan2,
       sinpi, cospi,
       log, log2,
       log10, log1p, exponent, exp, exp2, expm1, cbrt, sqrt,
       erf, erfc, erfcx, erfi, erfinv, erfcinv, dawson, ceil, floor,
       trunc, round, significand,
       abs, max, min, maximum, minimum,
       sign, dot,
       besseli, besselj, besselk, bessely,
       airyai, airybi,
       zero, one
import Base: transpose
import Base: diff
import Base: factorial, gcd, lcm, isqrt
import Base: gamma, beta
import Base: length,  size
import Base: factor, expand, collect
import Base: !=, ==
import Base:  inv, conj,
              cross, eigvals, eigvecs, trace, norm
import Base: promote_rule
import Base: match, replace, round
import Base: +, -, *, /, //, \
import Base: ^, .^
import Base: &, |, !, >, >=, ==, <=, <
## poly.jl
import Base: div
import Base: trunc
import Base: isinf, isnan
import Base: real, imag
import Base: expm
import Base: nullspace



export sympy, sympy_meth, object_meth, call_matrix_meth
export Sym, @syms, @vars, @osyms, symbols
export pprint,  jprint
export SymFunction, @symfuns,
       SymMatrix,
       evalf, N,  subs,
       simplify, nsimplify,
       expand, factor, trunc,
       collect, separate,
       fraction,
       primitive, sqf, resultant, cancel,
       together, square,
       solve,
       limit,
       series, integrate,
       summation,
       dsolve,
       poly,  nroots, real_roots, polyroots,
       ∨, ∧, ¬,
       rhs, lhs, args,
       jacobian, hessian,
       Max, Min,
       rref
export PI, E, IM, oo
export relation, piecewise, Piecewise, piecewise_fold
export members, doc, _str


## Following PyPlot, we initialize our variables outside _init_
const sympy  = PyCall.PyNULL()
const mpmath = PyCall.PyNULL()


include("types.jl")
include("utils.jl")
include("mathops.jl")
include("core.jl")
include("logical.jl")
include("math.jl")
include("mpmath.jl")
include("specialfuns.jl")
include("solve.jl")
include("dsolve.jl")
include("subs.jl")
include("patternmatch.jl")
include("simplify.jl")
include("series.jl")
include("integrate.jl")
include("assumptions.jl")
include("poly.jl")
include("matrix.jl")
include("ntheory.jl")
include("sets.jl")
include("display.jl")
include("lambdify.jl")

## add call interface depends on version
VERSION >= v"0.5.0-" && include("call.jl")
v"0.4.0" <= VERSION < v"0.5.0-" && include("call-0.4.jl")

include("plot_recipes.jl") # hook into Plots

## create some methods

for meth in union(core_sympy_methods,
                  simplify_sympy_meths,
                  expand_sympy_meths,
                  functions_sympy_methods,
                  series_sympy_meths,
                  integrals_sympy_methods,
                  summations_sympy_methods,
                  logic_sympy_methods,
                  polynomial_sympy_methods,
                  ntheory_sympy_methods
                  )

    meth_name = string(meth)
    @eval begin
        @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth){T<:SymbolicObject}(ex::T, args...; kwargs...) = sympy_meth($meth_name, ex, args...; kwargs...)
        
    end
    eval(Expr(:export, meth))
end

for meth in union(core_object_methods,
                  integrals_instance_methods,
                  summations_instance_methods,
                  polynomial_instance_methods
                  )

    meth_name = string(meth)
    @eval begin
        @doc """
`$($meth_name)`: a SymPy function.
The SymPy documentation can be found through: http://docs.sympy.org/latest/search.html?q=$($meth_name)
""" ->
        ($meth)(ex::SymbolicObject, args...; kwargs...) = object_meth(ex, $meth_name, args...; kwargs...)
    end
    eval(Expr(:export, meth))
end



for prop in union(core_object_properties,
                  summations_object_properties,
                  polynomial_predicates)

    prop_name = string(prop)
    @eval ($prop)(ex::Sym) = ex[@compat(Symbol($prop_name))]
    eval(Expr(:export, prop))
end


## For precompilation we must put PyCall instances in __init__:
function __init__()
    
    ## Define sympy, mpmath, ...
    copy!(sympy, PyCall.pyimport_conda("sympy", "sympy"))

    ## mappings from PyObjects to types.
    basictype = sympy[:basic]["Basic"]
    pytype_mapping(basictype, Sym)

    polytype = sympy[:polys]["polytools"]["Poly"]
    pytype_mapping(polytype, Sym)

    try
        matrixtype = sympy[:matrices]["MatrixBase"]
        pytype_mapping(matrixtype, SymMatrix)
        pytype_mapping(sympy[:Matrix], SymMatrix)
    catch e
    end


    ## Makes it possible to call in a sympy method, witout worrying about Sym objects

    global call_sympy_fun(fn::Function, args...; kwargs...) = fn(args...; kwargs...) 
    global call_sympy_fun(fn::PyCall.PyObject, args...; kwargs...) = call_sympy_fun(convert(Function, fn), args...; kwargs...)

    ## Main interface to methods in sympy
    ## sympy_meth(:name, ars, kwars...)
    global sympy_meth(meth, args...; kwargs...) = begin
        ans = call_sympy_fun(convert(Function, sympy[@compat(Symbol(meth))]), args...; kwargs...)
        ## make nicer...
        try
            if isa(ans, Vector)
                ans = Sym[i for i in ans]
            end
        catch err
        end
        ans
    end
    global object_meth(object::SymbolicObject, meth, args...; kwargs...)  =  begin
        call_sympy_fun(project(object)[@compat(Symbol(meth))],  args...; kwargs...)
    end
    global call_matrix_meth(object::SymbolicObject, meth, args...; kwargs...) = begin
        out = object_meth(object, meth, args...; kwargs...)
        if isa(out, SymMatrix) 
            convert(Array{Sym}, out)
        elseif  length(out) == 1
            out 
        else
            map(u -> isa(u, SymMatrix) ? convert(Array{Sym}, u) : u, out)
        end
    end

    ##
    init_logical()
    init_math()
    init_mpmath()
    init_sets()
    init_lambdify()
end

end
