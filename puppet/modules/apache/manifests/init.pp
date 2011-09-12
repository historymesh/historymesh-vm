class apache {
    package { ["apache2", "apache2-mpm-worker", "libapache2-mod-wsgi"]:
        ensure => installed
    }
    
    service { "apache2":
        ensure => running,
    }
    
    define wsgi_host($host, $wsgi_path, $aliases=[]) {
        file { "/etc/apache2/sites-available/${name}":
            ensure  => present,
            owner   => root,
            group   => root,
            mode    => "644",
            content => template("apache/wsgi_host"),
            notify  => Service["apache2"],
            require => Package["apache2"],
        }
        file { "/etc/apache2/sites-enabled/${name}":
            ensure  => "/etc/apache2/sites-available/${name}",
            require => File["/etc/apache2/sites-available/${name}"],
            notify  => Service["apache2"],
        }
        
        host { "${host}":
            ensure => present,
            ip     => "127.0.0.1",
        }
        
        realize File["/etc/apache2/sites-enabled"]
    }
    
    define piedpiper_host($host, $wsgi_path, $cgi_path, $aliases=[], $piped_paths=[]) {
        file { "/etc/apache2/sites-available/${name}":
            ensure  => present,
            owner   => root,
            group   => root,
            mode    => "644",
            content => template("apache/piedpiper_host"),
            notify  => Service["apache2"],
            require => Package["apache2"],
        }
        file { "/etc/apache2/sites-enabled/${name}":
            ensure  => "/etc/apache2/sites-available/${name}",
            require => File["/etc/apache2/sites-available/${name}"],
            notify  => Service["apache2"],
        }
        
        host { "${host}":
            ensure => present,
            ip     => "127.0.0.1",
        }
        
        realize Apache::Module["rewrite"]
        realize File["/etc/apache2/sites-enabled"]
    }
    
    define module() {
        exec { "/usr/sbin/a2enmod ${name}":
            creates => "/etc/apache2/mods-enabled/${name}.load",
            require => Package["apache2"],
            notify  => Service["apache2"],
        }
    }
    
    @module { "rewrite": }
    
    @file { "/etc/apache2/sites-enabled":
        require => Package["apache2"],
        ensure  => directory,
        recurse => true,
        purge   => true,
        notify  => Service["apache2"],
    }
}
