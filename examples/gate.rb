#!ruby

require "stringio"
require "fattr"
require "suzuna"

class MyUnit
  include Suzuna::Template

  fattr(:mediasize) { @pool.size }
  fattr sectorsize: 512,
        timeout: 30,
        flags: 0 # or Suzuna::G_GATE_FLAG_READONLY

  def initialize
    #@pool = StringIO.new(String.alloc(80.MiB))
    @pool = File.open("testsuzuna.img", File::BINARY | File::RDWR | File::CREAT)
    @pool.truncate(80.MiB) unless @pool.size >= 80.MiB
  end

  def cleanup
    @pool.flush rescue nil
    @pool.close rescue nil
  end

  def read(offset, size, buf)
    puts "#{File.basename caller(0, 1)[0]}: offset=#{offset}, size=#{size}"
    @pool.pos = offset
    @pool.read(size, buf)
    buf.resize(size)
    nil
  end

  def write(offset, buf)
    puts "#{File.basename caller(0, 1)[0]}: offset=#{offset}, size=#{buf.bytesize}"
    @pool.pos = offset
    @pool.write(buf)
    nil
  end

  def delete(offset, size)
    puts "#{File.basename caller(0, 1)[0]}: offset=#{offset}, size=#{size}"
    nil
  end
end

Suzuna.join(MyUnit.new)
