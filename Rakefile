
require "rake/clean"

DOC = FileList["{README,LICENSE,CHANGELOG,Changelog}{,.ja}{,.txt,.rd,.rdoc,.md,.markdown}"] +
      FileList["ext/**/{README,LICENSE,CHANGELOG,Changelog}{,.ja}{,.txt,.rd,.rdoc,.md,.markdown}"]
#EXT = FileList["ext/**/*.{h,hh,c,cc,cpp,cxx}"] +
#      FileList["ext/externals/**/*"]
EXT = FileList["ext/**/*"]
BIN = FileList["bin/*"]
LIB = FileList["lib/**/*.rb"]
SPEC = FileList["spec/**/*"]
EXAMPLE = FileList["examples/**/*"]
RAKEFILE = [File.basename(__FILE__), "gemstub.rb"]
EXTRA = []

load "gemstub.rb"

EXTCONF = FileList["ext/extconf.rb"]
EXTCONF.reject! { |n| !File.file?(n) }
GEMSTUB.extensions += EXTCONF
GEMSTUB.executables += FileList["bin/*"].map { |n| File.basename n }

GEMFILE = "#{GEMSTUB.name}-#{GEMSTUB.version}.gem"
GEMSPEC = "#{GEMSTUB.name}.gemspec"

GEMSTUB.files += DOC + EXT + EXTCONF + BIN + LIB + SPEC + EXAMPLE + RAKEFILE + EXTRA
GEMSTUB.rdoc_options ||= %w(--charset UTF-8)
GEMSTUB.extra_rdoc_files += DOC + LIB + EXT.reject { |n| n.include?("/externals/") || !%w(.h .hh .c .cc .cpp .cxx).include?(File.extname(n)) }

CLEAN << GEMSPEC
CLOBBER << GEMFILE

task :default => :all

task :all => GEMFILE

task :rdoc => DOC + EXT + LIB do
  sh *(%w(rdoc) + GEMSTUB.rdoc_options + DOC + EXT + LIB)
end

file GEMFILE => DOC + EXT + EXTCONF + BIN + LIB + SPEC + EXAMPLE + RAKEFILE + [GEMSPEC] do
  sh "gem build #{GEMSPEC}"
end

file GEMSPEC => RAKEFILE do
  File.write(GEMSPEC, GEMSTUB.to_ruby, mode: "wb")
end


RUBYSET ||= nil

if RUBYSET && !RUBYSET.empty? && !EXTCONF.empty?
  RUBY_VERSIONS = RUBYSET.map do |ruby|
    ver = `#{ruby} --disable gem -rrbconfig -e "puts RbConfig::CONFIG['ruby_version']"`.chomp
    raise "failed ruby checking - ``#{ruby}''" unless $?.success?
    [ver, ruby]
  end
  SOFILES_SET = RUBY_VERSIONS.map { |(ver, ruby)| ["lib/#{ver}/#{GEMSTUB.name}.so", ruby] }
  SOFILES = SOFILES_SET.map { |(lib, ruby)| lib }
  platforms = RUBYSET.map { |ruby| `#{ruby} -rubygems -e "puts Gem::Platform.local.to_s"`.chomp }
  platforms.uniq!
  platforms.compact!
  unless platforms.size == 1
    raise "wrong platforms (#{RUBYSET.inspect} => #{platforms.inspect})"
  end

  GEMSTUB_NATIVE = GEMSTUB.dup
  GEMSTUB_NATIVE.files += SOFILES
  GEMSTUB_NATIVE.platform = platforms[0]
  GEMFILE_NATIVE = "#{GEMSTUB_NATIVE.name}-#{GEMSTUB_NATIVE.version}-#{GEMSTUB_NATIVE.platform}.gem"
  GEMSPEC_NATIVE = "#{GEMSTUB_NATIVE.name}-#{GEMSTUB_NATIVE.platform}.gemspec"

  task :all => [GEMFILE, :native]

  task :native => GEMFILE_NATIVE

  file GEMFILE_NATIVE => DOC + EXT + [EXTCONF] + BIN + LIB + SPEC + EXAMPLE + SOFILES + RAKEFILE + [GEMSPEC_NATIVE] do
    sh "gem build #{GEMSPEC_NATIVE}"
  end

  file GEMSPEC_NATIVE => __FILE__ do
    File.write(GEMSPEC_NATIVE, GEMSTUB_NATIVE.to_ruby, mode: "wb")
  end

  SOFILES_SET.each do |(soname, ruby)|
    sodir = File.dirname(soname)
    makefile = File.join(sodir, "Makefile")

    CLEAN << GEMSPEC_NATIVE << sodir
    CLOBBER << GEMFILE_NATIVE

    directory sodir

    file soname => [makefile] + EXT do
      cd sodir do
        sh "make"
      end
    end

    file makefile => [sodir] + [EXTCONF] do
      cd sodir do
        sh "#{ruby} ../../#{EXTCONF} \"--ruby=#{ruby}\""
      end
    end
  end
end
