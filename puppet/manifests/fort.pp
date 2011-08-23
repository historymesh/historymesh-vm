$url = "http://ubuntu.fort/"
$dists = ["natty", "natty-updates", "natty-backports"]
$components = ["main", "restricted", "universe"]

/* Bit of a hack to tell whether we're running a Vagrant box */
$vagrant = $domain ? {
    "vagrantup.com" => true,
    default         => false,
}

file { "/etc/apt/sources.list.d/fort.list":

    ensure  => present,
    owner   => "root",
    group   => "root",
    content => template("apt/fort.list"),
    before  => Exec["apt-get-update"],
    notify  => Exec["apt-get-update"],
}

exec { "apt-get-update":
    command     => "/usr/bin/apt-get update",
    refreshonly => true,
}

if $vagrant {
    file { "/home/vagrant/.gemrc":
        ensure  => present,
        owner   => "vagrant",
        group   => "vagrant",
        content => template("rubygems/gemrc"),
    }
    
    file { "/home/vagrant/.bash_aliases":
        ensure  => present,
        owner   => "vagrant",
        group   => "vagrant",
        content => "alias st='git status'",
    }
}

$packages = ["postgresql", "python-psycopg2", "rubygems1.8", "git",
             "zlib1g-dev", "libreadline-dev", "libcurl4-openssl-dev"]

package { $packages:
    require => Exec["apt-get-update"],
    ensure  => present,
}

file { "/var/lib/gems/1.8":
    require => Package["rubygems1.8"],
    owner   => "root",
    group   => "admin",
    /* Allow anyone in the admin group to install gems */
    mode    => "0775",
}

$gem_source = "http://gems.fort"

define gem() {
    exec { "/usr/bin/gem install --source ${gem_source} ${name}":
        /* Don't bother if we already have a gem by the same name */
        unless  => "/usr/bin/gem list ${name} | /bin/grep .",
        require => Package["rubygems1.8"],
    }
}


gem { "bundler": }
