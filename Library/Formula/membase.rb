require 'formula'

class Membase < Formula
  url 'http://c2512712.cdn.cloudfiles.rackspacecloud.com/membase-server-community_1.6.0.1_src.tar.gz'
  homepage 'http://membase.org'
  md5 '74c9f4ff4d91dc9b45dca9eabfb9e041'

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
    erlang = Formula.factory('erlang')
    if erlang.version != 'R13B04'
      puts %Q{Requires erlang version R13B04 using version #{erlang.version}}
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
    system 'make'
    # system "mv ./* #{prefix}"    
    prefix.install Dir['**']
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