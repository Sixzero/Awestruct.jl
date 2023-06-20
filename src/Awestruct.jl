module Awestruct
using OrderedCollections

greet() = print("Hello World!")


mutable struct DynArray{SizeT, Eltype}
  size::SizeT
  vec::Vector{Eltype}
end
mutable struct VectReader
  size_path
  eltype
end
struct HoleyArray
  size_path
  pointers_path
  eltype
end
mutable struct DescriptorWithContextFn
  param_path
  fn::Function
end
mutable struct Descriptor
  descriptor::Vector
end
mutable struct StructDescriptor
  type_factory
  descriptor::Descriptor
end
mutable struct FixString{T}
  value::AbstractString
end
mutable struct DynString{T}
  value::AbstractString
end


get_path(d, path::T) where T<:AbstractString = startswith(path, "../") ? get_path(d["parent"], path[4:end]) : d[path]
descriptor(path::String, fn::Function) = DescriptorWithContextFn(path, fn)
descriptor(t::DataType, v::Vector) = StructDescriptor(t, Descriptor(v))
descriptor(v::Vector) = Descriptor(v)
condition(value_path::String, desc) = context -> begin
  if (get_path(context, value_path)==1 || get_path(context, value_path)==true)
    return desc
  end
  nothing
end
condition(cond::Function, desc) = context -> begin
  if (cond(context))
    return desc
  end
  nothing
end
easy_read(io, reader::HoleyArray, context) = begin
  size = get_path(context, reader.size_path)
  pointers = get_path(context, reader.pointers_path)
  @assert size == length(pointers) "Should be equal? $size == $(length(pointers)) but sum: $(sum(pointers))"
  # for i in 1:size
  #     if h.pointers[i] != 0
  #         cast_obj = h.vec[i]
  #         deserialize!(cast_obj)
  #     end
  # end
  [easy_read(io, reader.eltype, context) for i in 1:size if pointers[i] != 0]
end
easy_read(io, reader::VectReader, context=[]) = begin
  size = get_path(context, reader.size_path)
  # if size>500
    # @info "VectReader: Probably too long string! We cut it down."
    # size = 500
  # end
  [easy_read(io, reader.eltype, context) for i in 1:size]
end
# SVector
easy_read(io, v::Vector{T}) where T = begin
  for i in eachindex(v)
    v[i] = easy_read(io, Val(T))
  end
  v
end
easy_read(io, ::Val{DynArray{S, Eltype}}) where {Eltype, S} = begin
  s = read(io, S)
  vec = [easy_read(io, Eltype) for i in 1:s]
  DynArray(s, vec)
end
easy_read(io, ::Val{FixString{size_type}}) where {size_type} = begin
  s = size_type
  if s>10000
    @info "Probably too long string! We cut it down. $s"
    @assert s<10000
    s = 10000
  end
  chars = Vector{UInt8}(undef, s)
  readbytes!(io, chars, s)
  # chars = read(io, Cchar(s))
  String(chars)
end
easy_read(io, ::Val{DynString{size_type}}) where {size_type} = begin
  s = read(io, size_type)
  if s>10000
    @info "Probably too long string! We cut it down. $s"
    @assert s<10000
    s = 10000
  end
  chars = Vector{UInt8}(undef, s)
  readbytes!(io, chars, s)
  str = StringView(chars)
  if Main.allow_print
    @show length(str), str
  end
  DynString{size_type}(str)
end
easy_read(io, ::Val{NTuple{SIZE, T}}) where {SIZE, T} = begin
  vec = Tuple(easy_read(io, T) for i in 1:SIZE)
end
easy_read(io, ::Val{T}) where T = begin
  if isprimitivetype(T)
    return read(io, T)
  end
  read_args = (easy_read(io, t) for t in Tuple(T.types))
  T(read_args...)
end
handle_descriptor!(io, context, descriptor::Tuple) = begin
  key, value = descriptor
  res = easy_read(io, value, context)
  context[key] = res
  res
end
allow_print = false
handle_descriptor!(io, context, descriptor::Vector) = begin
  key, value = descriptor
  if context["parent"] == nothing
    # @show key
  end
  res = easy_read(io, value, context)
  context[key] = res
  if key == "civilizations"
    # Main.allow_print = true
  end 
  if Main.allow_print #&& key ∉ ["offsetY", "offsetX"]
    @show key
    easy_print((key, res), ending="\n")
  end
  # @assert key != "TerrainPassGraphics"
  # res |> display
  res
end
handle_descriptor!(io, context, T::DataType) = begin
  res = easy_read(io, T, context)
  context["$T"] = res
  res
end
handle_descriptor!(io, context, descr::DescriptorWithContextFn) = begin
  desc = descr.fn(context, descr.param_path)
  if desc !== nothing
    handle_descriptor!(context, desc)
  end
end
handle_descriptor!(io, context, descriptor_fn::Function) = begin
  # @show "$descriptor_fn"
  desc = descriptor_fn(context)
  if desc !== nothing
    res = handle_descriptor!(io, context, desc)
  end
end
handle_descriptor!(io, parent_context, desc::Descriptor) = begin
  context = OrderedDict{String, Any}("parent" => parent_context)
  for descriptor in desc.descriptor
    res = handle_descriptor!(io, context, descriptor)
  end
  delete!(context, "parent")
  context
end
easy_print(desc::NTuple{2,Any}; ending="\n") = begin
  for d in desc 
    easy_print(d, ending="") 
  end
  print(ending)
end
easy_print(desc::Tuple; ending="\n") = (print(length(desc)); print(ending))
easy_print(desc::DynArray; ending="\n") = (print("$(length(desc.vec))/$(desc.size)"); print(ending))
easy_print(desc::String; ending="\n") = (show(desc))
easy_print(desc::Char; ending="\n") = (show(desc))
easy_print(desc::UInt32; ending="\n") = (show(desc))
easy_print(desc::Int32; ending="\n") = (show(desc))
easy_print(desc::UInt8; ending="\n") = (show(desc))
easy_print(desc::Int8; ending="\n") = (show(desc))
easy_print(desc::UInt16; ending="\n") = (show(desc))
easy_print(desc::Int16; ending="\n") = (show(desc))
easy_print(desc::Float32; ending="\n") = (show(desc))
easy_print(desc::OrderedDict; ending="\n") = (show(desc))
# easy_print(desc::TerrainPassGraphic; ending="\n") = nothing# (show(desc))
easy_print(desc; ending="\n") = @assert false "Unknown type: $(typeof(desc)) " # Len: $(length(desc))
easy_print(desc::Vector; ending="\n") = (print(length(desc)); print(ending))
easy_read(io, descr::DescriptorWithContextFn, parent_context=nothing) = begin
  context = OrderedDict{String, Any}("parent" => parent_context)
  desc = descr.fn(context, descr.param_path)
  res = easy_read(io, desc, context)
  delete!(context, "parent")
  res
end
easy_read(io, struct_descriptor::Descriptor, parent_context=nothing) = begin
  handle_descriptor!(io, parent_context, struct_descriptor)
end
easy_read(io, struct_descriptor::StructDescriptor, parent_context=nothing) = begin
  context = easy_read(io, struct_descriptor.descriptor, parent_context)
  struct_descriptor.type_factory(values(context)...)
end
easy_read(io, v::DataType, parent_ctx=nothing) = begin
  easy_read(io, Val(v))
end
easy_read(io, type, opts) = easy_read(io, type)
#%%


end # module Awestruct
