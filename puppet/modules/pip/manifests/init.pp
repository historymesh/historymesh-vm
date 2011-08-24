class pip {
    
    $pypi = "http://pypi.fort/"
    
    package { "python-pip":
        ensure => installed,
    }
    
    define pip_package($version='') {
        exec { "pip-install-${name}":
            command => $version ? {
                ''      => "/usr/bin/pip install -i ${pip::pypi} ${name}",
                default => "/usr/bin/pip install -i ${pip::pypi} ${name}==${version}",
            },
            require => Package["python-pip"],
            unless  => "/usr/bin/pip freeze | /bin/grep '^${name}==${version}'",
        }
    }
}
