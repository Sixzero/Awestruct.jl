using Awestruct: descriptor, easy_read, easy_write


io = IOBuffer();

for i in 1:1000
  write(io, "asdf")
end

mutable struct TestSimpleStruct
  type::Int16
  amount::Float32
  usedMode::Int8
end

Coordinates = descriptor([
  ("x", Float32),
  ("y", Float32),
  ("z", Float32)
])

seek(io, 0)
@show read(io, 10)
@show easy_read(io, TestSimpleStruct)
seek(io, 0)
@show easy_write(io, TestSimpleStruct(1,1.2,1))
seek(io, 0)
simple = easy_read(io, TestSimpleStruct)
@show simple
seek(io, 0)
coord = easy_read(io, Coordinates)
@show coord
coord["x"] = 2; coord["y"] = 1.2
@show coord
seek(io, 0)
easy_write(io, coord)
seek(io, 0)
coord2 = easy_read(io, Coordinates)
@show coord2
;