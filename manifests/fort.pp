$url = "http://ubuntu.fort/"
$dists = ["natty", "natty-updates", "natty-backports"]
$components = ["main", "restricted"]

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

$packages = ["postgresql", "python-psycopg2"]

package { $packages:
    require => Exec["apt-get-update"],
    ensure  => present,
}
