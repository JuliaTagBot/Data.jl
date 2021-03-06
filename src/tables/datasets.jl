import Base: getindex, setindex!, ==, sub

export Table, DataSet

abstract Table

typealias Column Union{Field, Symbol}

immutable DataSet{I} <: Table
  cols::Vector{Symbol}
  data::TypedDict{I}
end

(==)(x) = true
(==)(x, y, z...) = x == y && ==(y, y...)

function DataSet(cols...)
  @assert ==([length(v) for (k, v) in cols]...)
  names = [Symbol(k) for (k, v) in cols]
  data = TypedDict(cols...)
  return DataSet(names, data)
end

getindex(d::DataSet, col::Column) = d.data[col]
getindex(d::DataSet, col::Column, i) = d[col][i]
setindex!(d::DataSet, val, col::Column, i) = d[col][i] = val

getindex(d::DataSet, cols::Tuple) =
  collect(zip(d.data[cols]...))

getindex{I, T<:Integer}(d::DataSet{I}, rows::AbstractVector{T}) =
  DataSet(names(d), TypedDict{I}(Dict([k => typeof(v)(v[rows]) for (k, v) in d.data])))

Base.names(d::DataSet) = copy(d.cols)
columns(d::DataSet) = map(c -> d[c], d.cols)
Base.length(d::DataSet) = length(columns(d)[1])

function sub{T<:Integer}(d::DataSet, rows::AbstractVector{T})
  DataSet(names(d), TypedDict([k => sub(v, rows) for (k, v) in d.data]...))
end
