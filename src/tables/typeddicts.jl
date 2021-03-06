import Base: getindex

export @f_str, TypedDict, with

# Fields

type Field{K} end

Base.convert{K}(::Type{Symbol}, ::Field{K}) = K
Base.convert(::Type{Field}, s::Symbol) = Field{s}()

macro f_str(s)
  :(Field{$(Expr(:quote, symbol(s)))}())
end

typealias FieldPair{F<:Field, T} Pair{F, T}

# Type info storage

const typeinfo = Dict()

function contradicts(a, b)
  for (k, v) in b
    if haskey(a, k) && a[k] != v
      return true
    end
  end
  return false
end

function storeinfo(info)
  for (key, existing) in typeinfo
    if !contradicts(existing, info)
      merge!(existing, info)
      return key
    end
  end
  key = gensym("ti")
  typeinfo[key] = info
  return key
end

# Typed Dict

type TypedDict{I}
  values::Dict{Symbol, Any}
end

function TypedDict_(ps...)
  I = storeinfo(Dict{Symbol, DataType}([Symbol(k)=>typeof(v) for (k, v) in ps]))
  TypedDict{I}(Dict{Symbol, Any}([Symbol(k)=>v for (k, v) in ps]))
end

@generated function TypedDict(ps::Pair...)
  all([p.parameters[1]<:Field for p in ps]) || return :(TypedDict_(ps...))
  I = storeinfo(Dict{Symbol, Any}([(Symbol(p.parameters[1]())=>p.parameters[2]) for p in ps]...))
  :(TypedDict{$(Expr(:quote, I))}(Dict(ps...)))
end

# API

Base.copy{I}(d::TypedDict{I}) = TypedDict{I}(copy(d.values))

@generated function getindex{I, K}(d::TypedDict{I}, f::Field{K})
  T = typeinfo[I][K]
  :(d.values[K]::$T)
end

getindex(d::TypedDict, f::Symbol) = d.values[f]

@generated function getindex{N}(d::TypedDict, fs::NTuple{N, Field})
  :($(map(f -> :(d[$f()]), fs.parameters)...,))
end

getindex(d::TypedDict, fs::NTuple) = map(f -> d[f], fs)

@generated function with{I}(d::TypedDict{I}, p::FieldPair)
  K = p.parameters[1].parameters[1]
  I′ = storeinfo(merge(typeinfo[I], Dict(K => p.parameters[2])))
  :(TypedDict{$(Expr(:quote, I′))}(merge(d.values, Dict($(Expr(:quote, K))=>p.second))))
end

for nargs = 1:5
  args = [symbol("p$i") for i = 1:nargs]
  @eval with(x, $([:($p::FieldPair) for p = args]...), p::FieldPair) =
      with(with(x, $(args...)), p)
end

@generated function Base.merge{I, J}(d::TypedDict{I}, e::TypedDict{J})
  I′ = storeinfo(merge(typeinfo[I], typeinfo[J]))
  :(TypedDict{$(Expr(:quote, I′))}(merge(d.values, e.values)))
end

dissoc!(d::TypedDict, f::Symbol) = (delete!(d.values, f); d)

dissoc!(d::TypedDict, f::Field) = dissoc!(d, Symbol(f))

dissoc(d::TypedDict, f) = dissoc!(copy(d), f)

@forward TypedDict.values Base.start, Base.next, Base.done

# Similar API for immutable types

@generated function with{F, T}(x, p::Pair{Field{F}, T})
  :($(x.name.primary)($([name == F ? :(p.second) : :(x.$name)
                         for name in fieldnames(x)]...)))
end
