require "gogyou"

module Suzuna
  Suzuna = self
  VERSION = Gem::Version.new "0.0.1"

  G_GATE_CTL_NAME       = "/dev/ggctl"
  G_GATE_TIMEOUT        = 0
  G_GATE_UNIT_AUTO      = -1
  G_GATE_PROVIDER_NAME  = "ggate"

  G_GATE_FLAG_READWRITE = 0x0000
  G_GATE_FLAG_READONLY  = 0x0001
  G_GATE_FLAG_WRITEONLY = 0x0002
  G_GATE_FLAG_DESTROY   = 0x1000
  G_GATE_USERFLAGS      = G_GATE_FLAG_READONLY | G_GATE_FLAG_WRITEONLY

  G_GATE_VERSION = 3

  BIO_READ = 0x01
  BIO_WRITE = 0x02
  BIO_DELETE = 0x04

  #
  # suzuna 固有の例外が include しているモジュールです。
  #
  # rescue で一括して受け取るために用意されています。
  #
  module Exceptions
  end

  class DestroyedGate < Errno::ENXIO
    include Exceptions
  end

  #
  # I/O 要求処理の基本機能のみを実装したモジュールです。
  #
  # クラスやモジュールに include することを想定しています。
  #
  # 必要なインスタンスメソッドは include したクラスで再定義して下さい。
  #
  module Template
    #
    # このメソッドはデバイスの大きさを取得するために呼ばれます。
    #
    # /dev 以下に geom gate オブジェクトとして作成される前に呼ばれます。
    #
    # 戻り値として 0以上で sectorsize の整数倍となる整数を返して下さい。
    #
    def mediasize
      raise NotImplementedError, "IMPLEMENT ME!  #mediasize -> integer"
    end

    #
    # このメソッドはデバイスの読み書き特性を取得するために呼ばれます。
    #
    # /dev 以下に geom gate オブジェクトとして作成される前に呼ばれます。
    #
    # 戻り値として G_GATE_FLAG_READWRITE、G_GATE_FLAG_READONLY、G_GATE_FLAG_WRITEONLY のいずれかを返して下さい。
    #
    def flags
      G_GATE_FLAG_READONLY
    end

    #
    # このメソッドはデバイスのセクタサイズ (読み書きの最小単位) を取得するために呼ばれます。
    #
    # /dev 以下に geom gate オブジェクトとして作成される前に呼ばれます。
    #
    # 戻り値として正の整数値を返して下さい。
    #
    def sectorsize
      512
    end

    #
    # このメソッドはデバイスのテキスト情報を取得するために呼ばれます。
    #
    # /dev 以下に geom gate オブジェクトとして作成される前に呼ばれます。
    #
    # 戻り値として nil か 2048 バイト未満の文字列を返して下さい。
    #
    def info
      "#{Suzuna}-#{VERSION} (powered by #{RUBY_ENGINE})"
    end

    #
    # このメソッドはデバイスの要求処理の最大待機時間を取得するために呼ばれます。
    #
    # /dev 以下に geom gate オブジェクトとして作成される前に呼ばれます。
    #
    # 戻り値として正の整数値を返して下さい。0 は無制限とみなされます。
    #
    def timeout
      60
    end

    #
    # このメソッドはデバイスのユニット番号を取得するために呼ばれます。
    #
    # /dev 以下に geom gate オブジェクトとして作成される前に呼ばれます。
    #
    # 戻り値として正の整数値か、G_GATE_UNIT_AUTO を返して下さい。
    #
    def unit
      G_GATE_UNIT_AUTO
    end

    #
    # このメソッドは geom gate オブジェクトが破棄されたあとに呼ばれます。
    #
    # 仮想デバイスの終了処理などを目的として用意されています。
    #
    # 戻り値は無視されます。
    #
    def cleanup
      nil
    end

    #
    # このメソッドは geom gate オブジェクトに対して読み込み要求があった時に呼ばれます。
    #
    # 文字列オブジェクトである buf に読み込んだデータを転写して下さい。
    #
    # 戻り値として、処理の成否である Errno::EXXX クラスかそのインスタンス、errno の整数値を返して下さい。
    # 正常な場合には、nil を返すことで Errno::NOERROR と認識されます。
    #
    def read(offset, size, buf)
      raise NotImplementedError, "IMPLEMENT ME!  #read(offset, size, buf) -> errno"
    end

    #
    # このメソッドは geom gate オブジェクトに対して書き込み要求があった時に呼ばれます。
    #
    # 文字列オブジェクトである buf を書き込む処理を行って下さい。
    #
    # 戻り値として、処理の成否である Errno::EXXX クラスかそのインスタンス、errno の整数値を返して下さい。
    # 正常な場合には、nil を返すことで Errno::NOERROR と認識されます。
    #
    def write(offset, buf)
      raise NotImplementedError, "IMPLEMENT ME!  #write(offset, buf) -> errno"
    end

    #
    # このメソッドは geom gate オブジェクトに対してセクタの削除(解放)要求があった時に呼ばれます。
    #
    # 戻り値として、処理の成否である Errno::EXXX クラスかそのインスタンス、errno の整数値を返して下さい。
    # 正常な場合には、nil を返すことで Errno::NOERROR と認識されます。
    #
    def delete(offset, size)
      raise NotImplementedError, "IMPLEMENT ME!  #delete(offset, size) -> errno"
    end
  end

  def self.join(unitobj)
    unit = IOCTL::Create.post(unitobj.mediasize, unitobj.flags,
                              sectorsize: unitobj.sectorsize, info: unitobj.info,
                              timeout: unitobj.timeout, unit: unitobj.unit)

    begin
      mainloop(unitobj, unit)
    ensure
      IOCTL::Destroy.post(unit, true) rescue nil unless $!.kind_of?(DestroyedGate)
      unitobj.cleanup
    end
  end

  def self.mainloop(unitobj, unit)
    ioc = IOCTL::IOReq.new
    ioc.start.version = G_GATE_VERSION
    ioc.start.unit = unit
    bufsize = unitobj.sectorsize
    buf = String.alloc(bufsize)
    ioc.start.data = buf.to_ptr

    while true
      while true
        ioc.start.data = buf.to_ptr
        ioc.start.length = buf.bytesize
        ioc.start.error = 0
        begin
          ioc.start.post
        rescue Errno::ENXIO
          raise DestroyedGate, "/dev/ggate#{unit}"
        end

        case ioc.start.error
        when Errno::NOERROR::Errno
          # nothing to do here
        when Errno::ECANCELED::Errno, Errno::ENXIO::Errno
          raise DestroyedGate, "/dev/ggate#{unit}"
        when Errno::ENOMEM::Errno
          buf.resize(bufsize = ioc.start.length)
          unless buf.bytesize == bufsize
            raise Errno::ENOMEM, <<-EOM.chomp
#{G_GATE_CTL_NAME} (require size = #{bufsize}, but allocated size = #{buf.bytesize})
            EOM
          end
          break
        else
          raise SystemCallError.new("#{G_GATE_CTL_NAME} (ioctl)", ioc.start.error)
        end

        catch(:break) do
          begin
            case ioc.start.cmd
            when BIO_READ
              if ioc.start.length > bufsize
                buf.resize(bufsize = ioc.start.length)
                unless buf.bytesize == bufsize
                  ioc.done.error = Errno::ENOMEM::Errno
                  throw :break
                end
              end
              ioc.done.error = err2code(unitobj.read(ioc.start.offset, ioc.start.length, buf))
              ioc.done.data = buf.to_ptr
            when BIO_DELETE
              ioc.done.error = err2code(unitobj.delete(ioc.start.offset, ioc.start.length))
            when BIO_WRITE
              buf.resize(ioc.start.length)
              ioc.done.error = err2code(unitobj.write(ioc.start.offset, buf))
              buf.resize(bufsize)
              ioc.done.data = buf.to_ptr
            else
              ioc.done.error = Errno::EOPNOTSUPP::Errno
            end
          rescue BasicObject
            ioc.done.error = Errno::EFAULT::Errno
            raise
          ensure
            #p err: SystemCallError.new(ioc.done.error)
            ioc.done.post
          end
        end
      end
    end

    raise Exception, "!!BUG!! - SHALL NOT REACHED HERE!"
  end

  def self.err2code(err)
    case err
    when nil
      Errno::NOERROR::Errno
    when Class
      err::Errno
    when Integer
      err.to_i
    else
      err.errno
    end
  end

  module IOCTL
    module IOC
      IOCPARM_SHIFT = 13
      IOCPARM_MASK = ~(~0 << IOCPARM_SHIFT)
      IOC_IN = 0x80000000
      IOC_OUT = 0x40000000
      IOC_INOUT = IOC_IN | IOC_OUT

      def _IOC(inout, group, num, len)
        inout.to_i | ((len.to_i & IOCPARM_MASK) << 16) | (group.to_i << 8) | num.to_i
      end

      def _IOWR(g, n, t)
        _IOC(IOC_INOUT, g.to_i, n.to_i, t.bytesize)
      end
    end

    NAME_MAX = 255

    G_GATE_INFOSIZE = 2048

    GG_MODIFY_MEDIASIZE     = 0x01
    GG_MODIFY_INFO          = 0x02
    GG_MODIFY_READPROV      = 0x04
    GG_MODIFY_READOFFSET    = 0x08

    @@devfd = File.open(G_GATE_CTL_NAME, File::RDWR)

    # :nodoc:
    def self.ioctl(req, data)
      @@devfd.ioctl(req, data)
    end

    module CommonModule
      def post
        IOCTL.ioctl(self.class::REQ, to_buffer)
      end
    end

    extend Gogyou

    typedef :uint64_t, :off_t

    Create = struct {
      uint   :version
      off_t  :mediasize
      uint   :sectorsize
      uint   :flags
      uint   :maxcount
      uint   :timeout
      char   :name, NAME_MAX
      char   :info, G_GATE_INFOSIZE
      char   :readprov, NAME_MAX
      off_t  :readoffset
      int    :unit
    }

    class Create
      include CommonModule
      extend IOC

      REQ = _IOWR("m".ord, 0, self)

      def self.post(mediasize, flags, sectorsize: 512, info: nil, timeout: G_GATE_TIMEOUT, unit: G_GATE_UNIT_AUTO)
        ioc = IOCTL::Create.new
        ioc.version = G_GATE_VERSION
        ioc.unit = unit ? unit : G_GATE_UNIT_AUTO
        ioc.mediasize = mediasize
        ioc.sectorsize = sectorsize
        ioc.timeout = timeout
        ioc.flags = flags
        ioc.maxcount = 0
        ioc.info = info if info
        ioc.post

        if unit == G_GATE_UNIT_AUTO
          puts "%s%u\n" % [G_GATE_PROVIDER_NAME, ioc.unit]
        end

        ioc.unit
      end
    end

    Modify = struct {
      uint      :version
      int       :unit
      uint32_t  :modify
      off_t     :mediasize
      char      :info, G_GATE_INFOSIZE
      char      :readprov, NAME_MAX
      off_t     :readoffset
    }

    class Modify
      include CommonModule
      extend IOC

      REQ = _IOWR("m".ord, 1, self)
    end

    Destroy = struct {
      uint   :version
      int    :unit
      int    :force
      char   :name, NAME_MAX
    }

    class Destroy
      include CommonModule
      extend IOC

      REQ = _IOWR("m".ord, 2, self)

      def self.post(unit, force = false)
        cmd = IOCTL::Destroy.new
        cmd.version = G_GATE_VERSION
        cmd.unit = unit
        cmd.force = force ? 1 : 0
        cmd.post
      end
    end

    Cancel = struct {
      uint       :version
      int        :unit
      uintptr_t  :seq
      char       :name, NAME_MAX
    }

    class Cancel
      include CommonModule
      extend IOC

      REQ = _IOWR("m".ord, 3, self)
    end

    CtlIO = struct {
      uint       :version
      int        :unit
      uintptr_t  :seq
      uint       :cmd
      off_t      :offset
      off_t      :length
      uintptr_t  :data    # void *gctl_data
      int        :error
    }

    class Start < CtlIO
      include CommonModule
      extend IOC

      REQ = _IOWR("m".ord, 4, self)
    end

    class Done < CtlIO
      include CommonModule
      extend IOC

      REQ = _IOWR("m".ord, 5, self)
    end

    IOReq = struct {
      union {
        Start :start
        Done :done
      }
    }
  end
end
