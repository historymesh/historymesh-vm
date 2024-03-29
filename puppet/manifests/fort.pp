$url = "http://ubuntu.fort/"
$dists = ["natty", "natty-updates", "natty-backports"]
$components = ["main", "restricted", "universe"]

/* Bit of a hack to tell whether we're running a Vagrant box */
$vagrant = $domain ? {
    "vagrantup.com" => true,
    default         => false,
}

$onafort = false

if $onafort {
    file { "/etc/apt/sources.list.d/fort.list":
        ensure  => present,
        owner   => "root",
        group   => "root",
        content => template("apt/fort.list"),
        before  => Exec["apt-get-update"],
        notify  => Exec["apt-get-update"],
    }
}

exec { "apt-get-update":
    command => "/usr/bin/apt-get update",
    /* Don't bother running this if we have a recent package cache */
    unless  => "/usr/bin/find /var/cache/apt/ -name pkgcache.bin -mtime -7 | /bin/grep .",
}

Package {
    require => Exec["apt-get-update"],
}

include pip
include postgres
include project
include apache
include restpose

if $vagrant {
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
    
    pip::pip_config { "vagrant-pip-config":
        user  => "vagrant",
    }
}


$packages = ["git", "zlib1g-dev", "libreadline-dev", "libcurl4-openssl-dev",
             "python-imaging", "gcc", "python-dev"]

package { $packages:
    ensure  => present,
}

postgres::postgres_user { "antler": create_db => true }
postgres::postgres_db { "antler":
    owner => "antler",
}

project::project { "antler": }

if $vagrant {
    project::vagrant_dev { "antler":
        active      => true,
        links       => ["antler", "init_virtualenv.sh", "pipe_runner.conf"],
        link_prefix => "historymesh",
    }
    
    $dev_path = "/home/antler/releases/dev"

    exec { "init-antler-ve":
        command => "${dev_path}/init_virtualenv.sh antler",
        cwd     => "${dev_path}",
        timeout => 600, /* This takes a while */
        tries   => 2,
        require => [Pip::Pip_package["virtualenv"], Package["gcc"],
                    Package["python-dev"], Project::Vagrant_dev["antler"]],
        creates => "${dev_path}/antler_ve/.init_ok",
        /* This file is shared by the standard WSGI host and the piper one */
        before  => File["/etc/apache2/sites-enabled/antler"],
    }

    exec { "migrate-antler-db":
        command => "${dev_path}/antler_ve/bin/python ${dev_path}/antler/manage.py syncdb --migrate --noinput",
        cwd     => "${dev_path}",
        require => [Exec["init-antler-ve"], File["/home/antler/releases/dev"],
                    Postgres::Postgres_db["antler"]]
    }
   
    exec { "antler-reindex":
        command => "${dev_path}/antler_ve/bin/python ${dev_path}/antler/manage.py reindex",
        cwd     => "${dev_path}",
        require => [Exec["migrate-antler-db"], Service["restpose"]],
    }
    
    file { "${dev_path}/cgi-bin":
        ensure => directory,
        owner  => "antler",
        group  => "admin",
        mode   => "0755",
    }
    
    file { "${dev_path}/cgi-bin/piedpiper.py":
        ensure => file,
        owner  => "antler",
        group  => "admin",
        mode   => "0755",
        source => "puppet:///modules/piedpiper/piedpiper.py",
    }
    
    project::fixture { "antler-data":
        project => "antler",
        fixture => "live_data",
        mainapp => "core",
        require => Exec["migrate-antler-db"],
    }
}

include pip

pip::pip_package { "virtualenv": version => "1.6.4"}

$current_release_path = "/home/antler/releases/current"

include apache

if $vagrant {
    apache::piedpiper_host { "antler":
        host        => 'antler.dev',
        wsgi_path   => "${current_release_path}/antler/configs/development/antler.wsgi",
        cgi_path    => "${dev_path}/cgi-bin/",
        piped_paths => ["static/css/screen.css", "static/js/common.js"],
    }
}
else {
    apache::wsgi_host { "antler":
        host      => 'antler.dev',
        wsgi_path => "${current_release_path}/antler/configs/development/antler.wsgi",
    }
}


/* Norm's crazy CSS weirdness */

package { ["curl", "perl"]:
    ensure => installed,
    before => Exec["setup-cpanm"],
}

exec { "download-cpanm":
    require => Package["curl"],
    command => $onafort ? {
        true  => "/usr/bin/curl http://cpan.fort/cpanm >/tmp/cpanm",
        false => "/usr/bin/curl -L  http://cpanmin.us >/tmp/cpanm",
    },
    /* Check the download file exists _and is non-empty_.
     * Also don't bother downloading if cpanm is installed */
    unless => "/usr/bin/test -s /tmp/cpanm -o -s /usr/local/bin/cpanm",
}

exec { "setup-cpanm":
    require => [Exec["download-cpanm"], Package["perl"]],
    command => $onafort ? {
        true  => "/usr/bin/perl /tmp/cpanm --self-upgrade --mirror http://cpan.fort/ --mirror-only",
        false => "/usr/bin/perl /tmp/cpanm --self-upgrade",
    },
    creates => "/usr/local/bin/cpanm",
}

define cpan_module() {
    exec { "cpan-module-${name}":
        require => Exec["setup-cpanm"],
        command => $onafort ? {
            true  => "/usr/local/bin/cpanm -f --mirror http://cpan.fort/ --mirror-only ${name}",
            false => "/usr/local/bin/cpanm -f ${name}",
        },
        unless  => "/usr/bin/perl -e 'require ${name}'",
    }
}

$modules = ["CSS::Prepare", "JavaScript::Prepare"]

cpan_module { $modules: }
