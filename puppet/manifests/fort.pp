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


if $vagrant {
    if $onafort {
        file { "/home/vagrant/.gemrc":
            ensure  => present,
            owner   => "vagrant",
            group   => "vagrant",
            content => template("rubygems/gemrc"),
        }
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
    
    pip::pip_config { "vagrant-pip-config":
        user  => "vagrant",
    }
}


$packages = ["rubygems1.8", "git", "zlib1g-dev", "libreadline-dev",
             "libcurl4-openssl-dev", "python-imaging", "gcc", "python-dev"]

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
    exec { "install-gem-${name}":
        command => $onafort ? {
            true  => "/usr/bin/gem install --source ${gem_source} ${name}",
            false => "/usr/bin/gem install ${name}",
        },
        /* Don't bother if we already have a gem by the same name */
        unless  => "/usr/bin/gem list ${name} | /bin/grep .",
        require => Package["rubygems1.8"],
    }
}

gem { "bundler": }

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
        require => [Exec["init-antler-ve"], File["/home/antler/releases/dev"]]
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
    /* Check the download file exists _and is non-empty_ */
    unless => "/usr/bin/test -s /tmp/cpanm",
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

$modules = ["CSS::Prepare", "JavaScript::Prepare", "Capture::Tiny",
            "Config::Std", "Proc::Fork"]

cpan_module { $modules: }

$pipe_runner_url = $onafort ? {
    true  => "http://cpan.fort/pipe_runner",
    false => "https://raw.github.com/gist/912802/a8f3d25cc243cde1e4d752b87afe9ad7f772d5ef/pipe_runner",
}

exec { "install-pipe-runner":
    require => [Exec["cpan-module-CSS::Prepare"], Exec["cpan-module-JavaScript::Prepare"]],
    command => "/usr/bin/curl ${pipe_runner_url} > /usr/local/bin/pipe_runner",
    unless  => "/usr/bin/test -s /usr/local/bin/pipe_runner",
}

file { "/usr/local/bin/pipe_runner":
    require => Exec["install-pipe-runner"],
    ensure  => file,
    owner   => "root",
    group   => "root",
    mode    => "0755",
}


# restpose

package { ["libxapian-dev", "uuid-dev", "libgcrypt11", "libgcrypt11-dev", "autoconf", "libtool", "texinfo"]:
  ensure => present
}

$restpose = "r0.7.2"

exec { "prep-restpose":
   command => "/bin/rm -rf /tmp/${restpose}",
   cwd => "/tmp",
   before => Exec["fetch-restpose"]
}

exec { "fetch-restpose":
   require => Package["curl"],
   command => "/usr/bin/curl -o ${restpose}.tar.gz https://nodeload.github.com/rboulton/restpose/tarball/${restpose}",
   cwd => "/tmp",
   before => Exec["extract-restpose"]
}

exec { "extract-restpose":
    command => "/bin/tar xvf ${restpose}.tar.gz",
    cwd => "/tmp",
    before => Exec["bootstrap-restpose"],
}

file { "/tmp/${restpose}":
    ensure => link,
    target => "/tmp/rboulton-restpose-117a097"
}

file { "/tmp/${restpose}/bootstrap": }

exec { "bootstrap-restpose":
    require => [Exec["extract-restpose"], Package["autoconf", "libtool"], File["/tmp/${restpose}/bootstrap"]],
    command => "/tmp/${restpose}/bootstrap",
    cwd => "/tmp/${restpose}",
    creates => "/tmp/${restpose}/configure"
}

file { "/tmp/${restpose}/configure": }

exec { "configure-restpose":
    require => [File["/tmp/${restpose}/configure"], Package["libxapian-dev", "uuid-dev", "libgcrypt11", "libgcrypt11-dev"]],
    command => "/tmp/${restpose}/configure",
    cwd => "/tmp/${restpose}",
    creates => "/tmp/${restpose}/Makefile"
}

exec { "build-restpose":
    require => [Exec["configure-restpose"], Package["texinfo"]],
    command => "/usr/bin/make",
    cwd => "/tmp/${restpose}"
}
