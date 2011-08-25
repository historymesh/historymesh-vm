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

Package {
    require => Exec["apt-get-update"],
}

if $vagrant {
    file { "/home/vagrant/.gemrc":
        ensure  => present,
        owner   => "vagrant",
        group   => "vagrant",
        content => template("rubygems/gemrc"),
    }
    
    file { "/home/vagrant/kick":
        ensure  => file,
        owner   => "vagrant",
        group   => "vagrant",
        mode    => "0755",
        content => "sudo /etc/init.d/apache2 restart",
    }
    
    file { "/home/vagrant/.bash_aliases":
        ensure  => present,
        owner   => "vagrant",
        group   => "vagrant",
        content => "alias st='git status'",
    }
}

$packages = ["rubygems1.8", "git", "zlib1g-dev", "libreadline-dev",
             "libcurl4-openssl-dev", "python-imaging"]

package { $packages:
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

include postgres

postgres::postgres_user { "antler": create_db => true }
postgres::postgres_db { "antler":
    owner => "antler",
}

include project

project::project { "antler": }

if $vagrant {
    project::vagrant_dev { "antler":
        active      => true,
        links       => ["antler", "init_virtualenv.sh"],
        link_prefix => "fort6",
    }
    
    $dev_path = "/home/antler/releases/dev"
    
    exec { "init-antler-ve":
        command => "${dev_path}/init_virtualenv.sh antler",
        cwd     => "${dev_path}",
        require => [Pip::Pip_package["virtualenv"]],
        creates => "${dev_path}/antler_ve",
        before  => Apache::Wsgi_host["antler"],
    }
}

include pip

pip::pip_package { "virtualenv": version => "1.6.4"}

$current_release_path = "/home/antler/releases/current"

include apache

apache::wsgi_host { "antler":
    host      => 'antler.dev',
    wsgi_path => "${current_release_path}/antler/configs/development/antler.wsgi",
}
