define upstart_service($ensure="running") {
    /* Workaround for versions of Puppet without support for Upstart */
    service { "${name}":
        ensure     => "${ensure}",
        start      => "/sbin/initctl start ${name}",
        stop       => "/sbin/initctl stop ${name}",
        hasrestart => true,
        restart    => "/sbin/initctl restart ${name}",
        /* initctl doesn't seem to bother with standard statuses */
        hasstatus  => true,
        status     => "/sbin/initctl status ${name} | /bin/grep 'start/running'",
    }
}

class restpose {

    upstart_service { "restpose":
      ensure => running,
      require => File["/etc/init/restpose.conf"],
    }
    
    file { "/etc/init/restpose.conf":
      ensure => present,
      owner => "root",
      group => "root",
      mode => "0644",
      source => "puppet:///modules/restpose/restpose.conf",
      require => [Exec["build-restpose"], File["/var/lib/restpose"], Package["daemontools"], User["restpose"]]
    }

    user { "restpose":
      home => "/var/lib/restpose",
      gid => "restpose",
      ensure => present
    }

    group { "restpose": ensure => present }

    file { "/var/lib/restpose":
      ensure => directory,
      owner => "restpose",
      group => "restpose",
      mode => "755",
    }

    package { "daemontools": }

    /* This is basically crazy, and builds restpose from a github-based
     * download in-situ. Packages are good things. */

    package { ["libxapian-dev", "uuid-dev", "libgcrypt11", "libgcrypt11-dev",
               "autoconf", "libtool", "texinfo"]:
      ensure => present
    }

    $restpose = "rboulton-restpose-117a097"

    exec { "prep-restpose":
       command => "/bin/rm -rf /tmp/${restpose}",
       cwd => "/tmp",
       before => Exec["fetch-restpose"],
       unless => "/usr/bin/test -f /usr/local/bin/restpose"
    }

    exec { "fetch-restpose":
       require => Package["curl"],
       command => "/usr/bin/curl -o ${restpose}.tar.gz https://nodeload.github.com/rboulton/restpose/tarball/r0.7.2",
       cwd => "/tmp",
       before => Exec["extract-restpose"],
       unless => "/usr/bin/test -f /usr/local/bin/restpose"
    }

    exec { "extract-restpose":
        command => "/bin/tar xzf ${restpose}.tar.gz",
        cwd => "/tmp",
        before => Exec["bootstrap-restpose"],
        unless => "/usr/bin/test -f /usr/local/bin/restpose"
    }

    file { "/tmp/${restpose}":
        require => Exec["extract-restpose"]
    }

    file { "/tmp/${restpose}/bootstrap": }

    exec { "bootstrap-restpose":
        require => [Exec["extract-restpose"], Package["autoconf", "libtool"], File["/tmp/${restpose}/bootstrap"]],
        command => "/tmp/${restpose}/bootstrap",
        cwd => "/tmp/${restpose}",
        creates => "/tmp/${restpose}/configure",
        before => Exec["configure-restpose"]
    }

    file { "/tmp/${restpose}/configure": }

    exec { "configure-restpose":
        require => [File["/tmp/${restpose}", "/tmp/${restpose}/configure"], Package["libxapian-dev", "uuid-dev", "libgcrypt11", "libgcrypt11-dev"]],
        command => "/tmp/${restpose}/configure --enable-static=yes",
        cwd => "/tmp/${restpose}",
        creates => "/tmp/${restpose}/Makefile",
        before => Exec["build-restpose"]
    }

    file { "/tmp/${restpose}/Makefile": }

    exec { "build-restpose":
        require => [File["/tmp/${restpose}", "/tmp/${restpose}/Makefile"], Package["texinfo"]],
        command => "/usr/bin/make install",
        cwd => "/tmp/${restpose}",
        creates => "/usr/local/bin/restpose",
    }
}
