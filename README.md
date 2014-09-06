# suzuna (スズナ)

The suzuna is a ruby library that provides an infrastructure for virtualized block devices.

"suzuna" is means "Turnip" in japanese.

----

(in Japanese)

suzuna は ruby 拡張ライブラリで、仮想ブロックデバイス基盤を提供します。

名称は春の七種の一つである『スズナ』から取りました。

----

* product name: suzuna (スズナ / 菘 / カブ / Turnip)
* author: dearblue &lt;<dearblue@users.sourceforge.jp>&gt;
* license: 2-clause BSD License (二条項 BSD ライセンス)
* software quarity: PROTOTYPE
* users: rubyist
* release number: 0.0.1
* memory usage: 1 MB +
* installed size: under 1 MB
* project page: &lt;http://sourceforge.jp/projects/rutsubo/&gt;
* support ruby: ruby-2.0+ &lt;http://www.ruby-lang.org/&gt;
* support platforms:
    * FreeBSD (GEOM Gate / ggate) (ggatel only)
* dependency libraries:
    * ruby - gogyou-0.2+ &lt;https://rubygems.org/gems/gogyou&gt;


## LIBRARY

``require "suzuna"``


## SYNOPSIS

``module Suzuna``

``module Suzuna::Template``

``Suzuna.join(unit_object)``


## DESCRIPTION

suzuna は ruby で GEOM Gate を用いて GEOM クラスを書くためのライブラリです。

``module Suzuna`` は、suzuna の名前空間として使われるモジュールです。

``module Suzuna::Template`` は、I/O 要求処理を担当するクラスに ``include`` することを想定したモジュールです (必ず必要なモジュールではありません)。このモジュールには、I/O 要求処理に必要となるインスタンスメソッドが予め定義してあります。ただし ``raise NotImplementedError`` を発生させるだけのメソッドがあるので、このようなメソッドは利用者側で実装する必要があります。このあたりは [EXAMPLE](#label-EXAMPLE) が参考になると思います。

``Suzuna.join(unit_object)`` は、I/O 要求処理オブジェクトを与えて実際に GEOM Gate オブジェクトを作成するためのメソッドです。***このメソッドはスレッドを停止させます。現在の実装では、このメソッドから返ってくる場面は例外が発生した時のみとなります。***


## EXAMPLE

以下は FreeBSD 上でローカルな GEOM Gate (ggate) を用いた、ruby による仮想ブロックデバイスプログラミングです。

``` ruby:ruby
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
```

これを管理者権限で実行すると `/dev/ggate0` が作成されて、`/dev/ada0` や `/dev/da0` などと同様の扱いをすることが出来ます。

停止させる場合は、`Ctrl+C` をするか、他の(擬似)端末から `$ sudo ggate -du0` と入力します。

環境によっては ``/usr/local/lib/ruby/gems/2.1/gems/suzuna-0.0.1-freebsd/lib/suzuna.rb:in `initialize': No such file or directory @ rb_sysopen - /dev/ggctl (Errno::ENOENT)`` などと例外が出るかもしれません。この場合はカーネルに `geom_gate.ko` を読み込ませてから試して下さい。

``` shell:shell
$ sudo kldload geom_gate
```


## DEMERIT

*   geom gate + ruby のため、実行性能はカーネルに置かれた geom オブジェクトよりもかなり劣ります。

    個人・研究用途としては十分かもしれませんが、大規模な用途には向かないでしょう。

*   geom gate ネットワークデーモンとしての機能は持っていません。

    ``ggated`` を組み合わせて利用できるかもしれません (試していません)。

*   現在の実装は、マルチスレッド化されていません。

    I/O 要求の処理は単体のスレッドのみで行われます。

## SEE ALSO

*   [geom(4)](http://www.freebsd.org/cgi/man.cgi?sektion=4&query=geom),
    [geom(8)](http://www.freebsd.org/cgi/man.cgi?sektion=8&query=geom),
    [ggatel(8)](http://www.freebsd.org/cgi/man.cgi?sektion=8&query=ggatel)
