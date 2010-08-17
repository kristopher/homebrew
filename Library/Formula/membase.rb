require 'formula'

class Membase < Formula
  url 'http://membase.org/downloads/membase_1.6.0beta2-18-g638fc06_src.tar.gz'
  homepage 'http://membase.org'
  md5 'b0b2a5d909cf3d2e20db07c4d12259a0'

  # build
  depends_on 'check'
  depends_on 'sqlite'
  depends_on 'glib'
  depends_on 'libevent'
  depends_on 'ncursesw'
  depends_on 'gnutls'
  depends_on 'libgpg-error'
  depends_on 'sprockets' => :ruby

  # runtime
  depends_on 'python'
  depends_on 'erlang'

  def caveats
    <<-EOS.undent
      If this is your first install, automatically load on login with:

        launchctl load -w #{prefix}/com.northscale.membase.plist

      Output will be logged to:

        #{log_file}

      To start membase manually:

        ns_server

      To start membase manually with access to the erlang shell:

        ns_server_shell

      Once running, the web UI is available here:

        http://127.0.0.1:8080/

      The python management scripts are available here:

        #{prefix}/ep-engine/management/
        #{prefix}/membase-cli
    EOS
  end

  def verify_dependencies
    if Formula.factory("moxi").installed? || Formula.factory("memcached").installed? || Formula.factory("libmemcached").installed?
      onoe "The membase forumla conflicts with some existing forumla"
      puts <<-EOS.undent
        Please remove them:

          brew remove moxi
          brew remove memcached
          brew remove libmemcached
      EOS
      exit 99
    end

    python = Formula.factory("python")
    unless python.installed?
      onoe "The \"membase\" brew is only meant to be used against a Homebrew-built Python."
      puts <<-EOS.undent
        Homebrew's "membase" formula is only meant to be installed against a Homebrew-
        built version of Python, but we couldn't find such a version.
      EOS
      exit 99
    end
  end

  def install

    verify_dependencies

    # Easier to replicate the makefile myself
    Dir.chdir 'memcached' do
      ohai 'Installing memcached'
      system './config/autorun.sh'
      system "./configure --prefix=#{prefix} --enable-isasl"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'bucket_engine' do
      ohai 'Installing bucket_engine'
      system "./configure --prefix=#{prefix} --with-memcached=../memcached"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'ep-engine' do
      ohai 'Installing ep-engine'
      system './config/autorun.sh'
      system "./configure --prefix=#{prefix} --with-memcached=../memcached"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'libmemcached' do
      ohai 'Installing libmemcached'
      system "./configure --prefix=#{prefix} --with-memcached=../memcached/memcached"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'libvbucket' do
      ohai 'Installing libvbucket'
      system './config/autorun.sh'
      system "./configure --prefix=#{prefix} --disable-shared"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'vbucketmigrator' do
      ohai 'Installing vbucketmigrator'
      system './config/autorun.sh'
      system "./configure --prefix=#{prefix} --with-memcached=../memcached --with-libvbucket-prefix=#{prefix}"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'libconflate' do
      ohai 'Installing libconflate'
      system "./configure --prefix=#{prefix} --without-shared --with-rest=yes --with-sqlite=no --with-bundled-libstrophe=no --with-check=no"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'moxi' do
      ohai 'Installing moxi'
      system './config/autorun.sh'
      system "./configure --prefix=#{prefix} --with-libconflate=have CFLAGS='-I../lib/include -I../lib/include/libconflate -I#{include} -I#{include}/libconflate' LDFLAGS='-L#{lib} -lconflate'"
      system 'make'
      system 'make install'
    end
    Dir.chdir 'ns_server' do
      ohai 'Installing ns_server'
      system 'make'
    end

    # install libs and bins hidden in odd places
    lib.install     Dir["**/*.so*"]
    lib.install     Dir["**/.libs/*"]

    # Install the python management libraries
    # FIXME: these should be installed to the proper python places
    (prefix+'ep-engine').install Dir['ep-engine/management']
    prefix.install Dir['membase-cli']

    # fixup the ns_server symlinks to point to things in #{prefix}
    %w(
    ns_server/bin/bucket_engine/bucket_engine.so
    ns_server/bin/ep_engine/ep.so
    ns_server/bin/memcached/default_engine.so
    ns_server/bin/memcached/stdin_term_handler.so
    ).each do |symlinked_so|
      rm symlinked_so rescue nil
      ln_s(lib+File.basename(symlinked_so), symlinked_so)
    end

    %w(
    ns_server/bin/moxi/moxi
    ns_server/bin/memcached/memcached
    ns_server/bin/port_adaptor/port_adaptor
    ns_server/bin/vbucketmigrator/vbucketmigrator
    ).each do |symlinked_bin|
      rm symlinked_bin rescue nil
      ln_s(bin+File.basename(symlinked_bin), symlinked_bin)
    end

    prefix.install  Dir["ns_server"]

    # shim scripts, because start.sh doesn't make sense in PATH
    (bin+'ns_server').write <<-EOS.undent
      #!/bin/bash
      export PATH="$PATH:#{bin}:#{HOMEBREW_PREFIX}/bin"
      #{prefix}/ns_server/start.sh $@
    EOS

    (bin+'ns_server_shell').write <<-EOS.undent
      #!/bin/bash
      export PATH="$PATH:#{bin}:#{HOMEBREW_PREFIX}/bin"
      #{prefix}/ns_server/start_shell.sh $@
    EOS

    system "chmod +x #{bin}/*"

    (var+'log/membase').mkpath
    touch log_file

    (prefix+'com.northscale.membase.plist').write startup_plist
  end

  def log_file
    var+'log/membase/ns_server.log'
  end

  def startup_plist; <<-EOPLIST.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>com.northscale.membase</string>
      <key>Program</key>
      <string>#{bin}/ns_server</string>
      <key>RunAtLoad</key>
      <true/>
      <key>UserName</key>
      <string>#{`whoami`.chomp}</string>
      <key>WorkingDirectory</key>
      <string>#{prefix}</string>
      <key>StandardErrorPath</key>
      <string>#{log_file}</string>
      <key>StandardOutPath</key>
      <string>#{log_file}</string>
    </dict>
    </plist>
    EOPLIST
  end
end