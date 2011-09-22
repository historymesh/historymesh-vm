class pip {
    
    package { "python-pip":
        ensure => installed,
    }
    
    define pip_config($user) {
        
        $pypi = $onafort ? {
            true  => "http://pypi.fort/",
            false => "",
        }
        
        $homedir = $user ? {
            "root"  => "/root",
            default => "/home/${user}",
        }
        
        file { "${homedir}/.pip":
            ensure => directory,
            owner  => "${user}",
            group  => "${user}",
            mode   => "0755",
        }
        
        file { "${homedir}/.pip/pip.conf":
            ensure  => file,
            owner   => "${user}",
            group   => "${user}",
            mode    => "0644",
            content => template("pip/pip.conf"),
        }
    }
    
    pip::pip_config { "root-pip-config":
        user => "root",
    }
    
    define pip_package($version='') {
        exec { "pip-install-${name}":
            command => $version ? {
                ''      => "/usr/bin/pip install ${name}",
                default => "/usr/bin/pip install ${name}==${version}",
            },
            require => [Package["python-pip"], Pip::Pip_config["root-pip-config"]],
            unless  => "/usr/bin/pip freeze | /bin/grep '^${name}==${version}'",
        }
    }
}
