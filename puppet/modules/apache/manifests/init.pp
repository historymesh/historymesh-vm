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
            notify => Service["apache2"],
        }
        file { "/etc/apache2/sites-enabled/${name}":
            ensure => "/etc/apache2/sites-available/${name}",
            notify => Service["apache2"],
        }
        
        host { "${host}":
            ensure => present,
            ip     => "127.0.0.1",
        }
    }
}