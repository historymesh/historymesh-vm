class project {
    
    @group { "admin":
        ensure => present,
    }
    
    define project() {
        /* A project with its own user, group and release directory */
        
        user { "${name}":
            home   => "/home/${name}",
            gid    => "${name}",
            ensure => present,
        }
        
        group { "${name}": ensure => present }
        realize Group["admin"]
        
        file { ["/home/${name}", "/home/${name}/releases"]:
            ensure  => directory,
            owner   => "${name}",
            group   => "admin",
            mode    => "775",
        }
    }
    
    define vagrant_dev($active=false, $links=[], $link_prefix="") {
        /* Vagrant development project */
        
        if $active {
            /* Symlink the current release to the dev version */
            file { "/home/${name}/releases/current":
                ensure => "/home/${name}/releases/dev",
                require => Project::Project[$name],
            }
        }
        
        file { "/home/${name}/releases/dev":
            ensure => "directory",
            owner  => "${name}",
            group  => "admin",
            mode   => "775",
            
            require => Project::Project[$name],
        }
        
        project::vagrant_link { $links:
            project => "${name}",
            prefix  => "${link_prefix}",
        }
    }
    
    define vagrant_link($project, $prefix="") {
        file { "vagrant_${project}_${name}":
            path   => "/home/${project}/releases/dev/${name}",
            ensure => $prefix ? {
                ""      => "/home/vagrant/${name}",
                default => "/home/vagrant/${prefix}/${name}"
            },
        }
    }
}
