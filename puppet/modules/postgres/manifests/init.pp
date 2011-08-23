class postgres {
    
    $locale = "en_GB.utf8"
    
    exec { "generate-locale":
        command =>"/usr/bin/locale-gen ${locale}",
        unless => "/usr/bin/locale -a | /bin/grep -Fx ${locale}",
    }
    
    exec { "update-locale":
        command => "/usr/sbin/update-locale LANG=${locale}",
        unless  => "/usr/bin/locale | /bin/grep -Fx 'LANG=${locale}'",
        require => Exec["generate-locale"],
    }
    
    exec { "kick-cluster":
        command     => "/usr/bin/pg_dropcluster --stop 8.4 main && /usr/bin/pg_createcluster --locale ${locale} --start 8.4 main",
        refreshonly => true,
        before      => File["/etc/postgresql/8.4/main/pg_hba.conf"],
    }
    
    package { "postgresql":
        /* TODO: look up plussignment operator, if we can use it */
        require => [Exec["apt-get-update"], Exec["update-locale"]],
        ensure  => installed,
        notify  => Exec["kick-cluster"],
    }
    
    package { "python-psycopg2":
        ensure => installed,
    }
    
    service { "postgresql":
        require => Package["postgresql"],
        ensure  => running,
    }

    file { "/etc/postgresql/8.4/main/pg_hba.conf":
        /* This would probably use augeas, were I not on a fort */
        require => Package["postgresql"],
        owner   => "postgres",
        group   => "postgres",
        mode    => "640",
        content => template("postgres/pg_hba.conf"),
        notify  => Service["postgresql"],
    }

    define postgres_user() {
        exec { "/usr/bin/createuser -U postgres -SDR ${name}":
            /* No super-user, no create DB, no create roles */
            require => Service["postgresql"],
            unless  => "/usr/bin/psql -U ${name} -l",
        }
    }

    define postgres_db() {
        exec { "createdb -U postgres ${name}":
            path    => "/usr/bin",
            require => Service["postgresql"],
            /* Shamelessly nicked from Artfinder: mwaahaahaa */
            unless => "test \$(psql -U postgres -tA -c \"SELECT count(*)=1 FROM pg_catalog.pg_database where datname='${name}';\") = t",
        }
    }
}